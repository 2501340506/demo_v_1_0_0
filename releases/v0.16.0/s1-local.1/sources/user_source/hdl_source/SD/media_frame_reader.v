`timescale 1ns/1ps
// Separate read path with the existing non-show-ahead FIFO/output latency.
module media_frame_reader #(
    parameter ADDR_BITS=21, BURST_SIZE=64, PREVIEW_ENABLE=0
)(
    input rst, mem_clk, read_clk, read_rst,
    input Sdr_init_done, Sdr_init_ref_vld, Sdr_busy, App_wr_busy,
    output O_rd_busy, output App_rd_en, output [ADDR_BITS-1:0] App_rd_addr,
    output refill_priority,
    input Sdr_rd_en, input [31:0] Sdr_rd_dout,
    input read_req, output read_req_ack, output read_finish,
    input display_commit_request, output display_commit_ack,
    input preview_request,input [17:0] preview_descriptor,output preview_ack,
    output reg [17:0] pixel_descriptor,
    input [ADDR_BITS-1:0] read_addr_0, read_addr_1, read_addr_2, read_addr_3,
    input [1:0] read_addr_index, input [ADDR_BITS-1:0] read_len,
    input read_en, input display_valid, output [31:0] read_data,
    output reg underflow, output reg [2:0] reader_error
);
    wire fifo_clear, fifo_empty, fifo_full;
    wire [17:0] frame_descriptor;
    reg [17:0] pixel_descriptor_meta;
    // The memory snapshot changes only during FIFO reload in vertical blank.
    // Both stages settle well before the first active pixel of that frame.
    always @(posedge read_clk or posedge read_rst) begin
      if(read_rst)begin pixel_descriptor_meta<=0;pixel_descriptor<=0;end
      else begin pixel_descriptor_meta<=frame_descriptor;pixel_descriptor<=pixel_descriptor_meta;end
    end
    wire [8:0] fifo_words;
    wire [31:0] fifo_data;
    reg [1:0] display_sync;
    reg sample_good, frame_bad;
    assign read_data=sample_good ? fifo_data : 32'd0;
    // Once a displayed frame loses a pixel, black the remainder rather than
    // shift later pixels into the wrong columns. The next frame clears it.
    always @(posedge read_clk or posedge read_rst) begin
        if(read_rst) display_sync<=0;
        else display_sync<={display_sync[0],display_valid};
    end
    always @(posedge read_clk or posedge read_rst) begin
        if(read_rst) begin sample_good<=0; frame_bad<=0; underflow<=0; end
        else if(fifo_clear) begin sample_good<=0; frame_bad<=0; underflow<=0; end
        else begin
            sample_good<=read_en && !fifo_empty && !frame_bad;
            if(read_en && display_sync[1] && fifo_empty) begin
                underflow<=1; frame_bad<=1;
            end
        end
    end
    rfifo_32_32_512 read_buf(
        .clkr(read_clk),.clkw(mem_clk),.rst(fifo_clear || rst || read_rst),
        .we(Sdr_rd_en && !fifo_full && !fifo_clear),.re(read_en && !fifo_empty && !frame_bad),
        .di(Sdr_rd_dout),.dout(fifo_data),.empty_flag(fifo_empty),.full_flag(fifo_full),
        .wrusedw(fifo_words),.rdusedw()
    );
    frame_fifo_read #(.PREVIEW_ENABLE(PREVIEW_ENABLE),.ADDR_BITS(ADDR_BITS),.BURST_BITS(9),.BURST_SIZE(BURST_SIZE)) reader(
        .rst(rst),.mem_clk(mem_clk),.Sdr_init_done(Sdr_init_done),
        .Sdr_init_ref_vld(Sdr_init_ref_vld),.Sdr_busy(Sdr_busy),.Sdr_rd_en(Sdr_rd_en),
        .App_wr_busy(App_wr_busy),.O_rd_busy(O_rd_busy),.App_rd_en(App_rd_en),.App_rd_addr(App_rd_addr),
        .read_req(read_req),.read_req_ack(read_req_ack),.read_finish(read_finish),
        .preview_request(preview_request),.preview_descriptor(preview_descriptor),.preview_ack(preview_ack),.frame_descriptor(frame_descriptor),
        .display_commit_request(display_commit_request),.display_commit_ack(display_commit_ack),.refill_priority(refill_priority),
        .read_addr_0(read_addr_0),.read_addr_1(read_addr_1),.read_addr_2(read_addr_2),.read_addr_3(read_addr_3),
        .read_addr_index(read_addr_index),.read_len(read_len),
        .fifo_aclr(fifo_clear),.wrusedw({1'b0,fifo_words})
    );
    reg [ADDR_BITS:0] returned;
    always @(posedge mem_clk or posedge rst) begin
        if(rst) begin returned<=0; reader_error<=0; end
        else if(fifo_clear) begin returned<=0; reader_error<=0; end
        else begin
            if(Sdr_rd_en) begin
                returned<=returned+1'b1;
                if(fifo_full) reader_error<=3'd1;
            end
            // read_len is static, so it equals the length latched at the last clear.
            if(read_finish && returned!={1'b0,read_len}) reader_error<=3'd2;
        end
    end
endmodule
