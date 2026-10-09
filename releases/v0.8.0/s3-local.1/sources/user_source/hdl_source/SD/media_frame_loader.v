`timescale 1ns/1ps
// Source-domain frame validation plus the proven 64-word memory write engine.
// Data remains {RGB,8'h00}; frame_fifo_write owns BMP vertical address flipping.
module media_frame_loader #(
    parameter ADDR_BITS=21, BURST_SIZE=64,
    parameter WRITE_V_FLIP=1, FRAME_WIDTH=640, FRAME_HEIGHT=480,
    parameter STALL_CYCLES=65535
)(
    input rst, mem_clk, write_clk, write_rst,
    input Sdr_init_done, Sdr_init_ref_vld, Sdr_busy, App_rd_busy,
    output O_wr_busy,
    output App_wr_en, output [ADDR_BITS-1:0] App_wr_addr,
    output [31:0] App_wr_din, output [3:0] App_wr_dm,
    input write_req, output write_req_ack,
    input write_cancel_req, output write_cancel_ack,
    input [ADDR_BITS-1:0] write_addr_0, write_addr_1, write_addr_2, write_addr_3,
    input [1:0] write_addr_index, input [ADDR_BITS-1:0] write_len,
    input write_en, input [31:0] write_data,
    input source_done, source_error,
    output reg write_finish,
    // Memory-domain error is held with a toggle; source decode failure already
    // has its own report and is not emitted a second time here.
    output reg error_toggle, output reg [2:0] memory_error
);
    wire fifo_clear, fifo_empty, fifo_full, core_finish, core_cancel_ack;
    wire [8:0] fifo_words;
    reg internal_cancel;
    reg [ADDR_BITS:0] received;
    reg source_complete, source_failed, complete_pending;
    reg [2:0] source_fault;
    wire pixel_accept = write_en && !fifo_full && source_fault==0 && !source_failed;
    assign App_wr_dm=4'b0000;
    assign write_cancel_ack=core_cancel_ack && write_cancel_req;

    // The request is held until the memory engine has reset the FIFO. The
    // decoder cannot emit pixels until that acknowledgement returns.
    always @(posedge write_clk or posedge write_rst) begin
        if(write_rst) begin
            received<=0; source_complete<=0; source_failed<=0; source_fault<=0; complete_pending<=0;
        end else if(write_req) begin
            received<=0; source_complete<=0; source_failed<=0; source_fault<=0; complete_pending<=0;
        end else begin
            // Validate one cycle after EOF, including a coincident final pixel
            // without a parser-valid -> add -> compare path at 100 MHz.
            complete_pending<=source_done;
            if(source_error) source_failed<=1;
            if(write_en && !source_failed && source_fault==0) begin
                if(fifo_full) source_fault<=3'd1;
                else if(received >= {1'b0,write_len}) source_fault<=3'd2;
                else received<=received+1'b1;
            end
            if(complete_pending) begin
                if(received == {1'b0,write_len}) source_complete<=1;
                else source_fault<=3'd2;
            end
        end
    end

    wfifo_32_32_512 write_buf(
        .clkr(mem_clk),.clkw(write_clk),.rst(fifo_clear || rst || write_rst),
        .we(pixel_accept),.re(App_wr_en),.di(write_data),.dout(App_wr_din),
        .empty_flag(fifo_empty),.full_flag(fifo_full),.wrusedw(),.rdusedw(fifo_words)
    );
    frame_fifo_write #(.ADDR_BITS(ADDR_BITS),.BURST_BITS(9),.BURST_SIZE(BURST_SIZE),
        .WRITE_V_FLIP(WRITE_V_FLIP),.FRAME_WIDTH(FRAME_WIDTH),.FRAME_HEIGHT(FRAME_HEIGHT)) writer(
        .rst(rst),.mem_clk(mem_clk),.Sdr_init_done(Sdr_init_done),
        .Sdr_init_ref_vld(Sdr_init_ref_vld),.Sdr_busy(Sdr_busy),
        .App_rd_busy(App_rd_busy),.O_wr_busy(O_wr_busy),
        .App_wr_en(App_wr_en),.App_wr_addr(App_wr_addr),
        .write_req(write_req && !internal_cancel && !core_cancel_ack),.write_req_ack(write_req_ack),
        .write_cancel_req(write_cancel_req || internal_cancel),.write_cancel_ack(core_cancel_ack),
        .write_finish(core_finish),.write_addr_0(write_addr_0),.write_addr_1(write_addr_1),
        .write_addr_2(write_addr_2),.write_addr_3(write_addr_3),.write_addr_index(write_addr_index),
        .write_len(write_len),.fifo_aclr(fifo_clear),.rdusedw({1'b0,fifo_words})
    );

    reg [1:0] complete_sync, failed_sync, cancel_sync;
    reg [2:0] fault_sync0, fault_sync1;
    reg active, written;
    reg [3:0] drain_cycles;
    localparam STALL_BITS=$clog2(STALL_CYCLES+1);
    reg [STALL_BITS-1:0] stalled;
    always @(posedge mem_clk or posedge rst) begin
        if(rst) begin
            complete_sync<=0; failed_sync<=0; cancel_sync<=0;
            fault_sync0<=0; fault_sync1<=0;
            active<=0; written<=0; internal_cancel<=0;
            drain_cycles<=0; stalled<=0;
            write_finish<=0; error_toggle<=0; memory_error<=0;
        end else begin
            complete_sync<={complete_sync[0],source_complete};
            failed_sync<={failed_sync[0],source_failed};
            cancel_sync<={cancel_sync[0],write_cancel_req};
            fault_sync0<=source_fault; fault_sync1<=fault_sync0;
            write_finish<=0;
            if(App_wr_en) drain_cycles<=0;
            else if(drain_cycles!=10) drain_cycles<=drain_cycles+1'b1;
            if(internal_cancel && core_cancel_ack) internal_cancel<=0;
            if(write_req_ack) begin
                active<=1; written<=0; stalled<=0; memory_error<=0;
            end else if(cancel_sync[1]) begin
                active<=0; written<=0; stalled<=0;
            end else if(active) begin
                if(core_finish) written<=1;
                if(failed_sync[1] || fault_sync1!=0) begin
                    active<=0; written<=0; internal_cancel<=1; stalled<=0;
                    if(fault_sync1!=0) begin
                        memory_error<=fault_sync1; error_toggle<=~error_toggle;
                    end
                end else if(written && complete_sync[1] && fifo_empty &&
                            !Sdr_busy && !Sdr_init_ref_vld && drain_cycles==10) begin
                    write_finish<=1; active<=0; stalled<=0;
                end else if(App_wr_en) stalled<=0;
                else if(complete_sync[1] || fifo_words>=BURST_SIZE) begin
                    if(stalled==STALL_CYCLES-1) begin
                        active<=0; internal_cancel<=1; memory_error<=3'd3;
                        error_toggle<=~error_toggle; stalled<=0;
                    end else stalled<=stalled+1'b1;
                end else stalled<=0;
            end
        end
    end
endmodule
