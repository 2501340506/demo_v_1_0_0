`timescale 1ns/1ps
// Replay production application requests from the full-frame regression into
// the real encrypted SDRAM controller. Data still uses the ideal memory in app;
// this probe checks command service only, not the physical SDRAM data path.
module tb_external_refresh_trace;
    tb_full_frame_evidence app();
    reg rst=1;
    defparam app.frame.BURST_SIZE=64;
    wire done,refbusy,busy,shifted,sc,ras,cas,we;
    wire [1:0] ba; wire [10:0] addr; wire [3:0] dm; tri [31:0] dq;
    assign #12 shifted=app.mem_clk;
    sdram controller(.Clk(app.mem_clk),.Clk_sft(shifted),.Rst(rst),
        .Sdr_init_done(done),.Sdr_init_ref_vld(refbusy),.Sdr_busy(busy),
        .App_wr_en(app.wr_en),.App_wr_addr(app.wr_addr),.App_wr_dm(4'b0),.App_wr_din(app.wr_data),
        .App_rd_en(app.rd_en),.App_rd_addr(app.rd_addr),.Sdr_rd_en(),.Sdr_rd_dout(),
        .SDRAM_CLK(sc),.SDR_CKE(),.SDR_RAS(ras),.SDR_CAS(cas),.SDR_WE(we),.SDR_BA(ba),.SDR_ADDR(addr),.SDR_DM(dm),.SDR_DQ(dq));
    integer cycles=0,last_ref=0,refs=0,max_gap=0,min_gap=999999,violations=0,writes=0,reads=0;
    initial begin
        force app.frame.Sdr_busy=busy;
        force app.frame.Sdr_init_ref_vld=refbusy;
    end
    always @(posedge sc) begin
        cycles=cycles+1;
        if(done && {ras,cas,we}===3'b001) begin
            if(refs>0) begin
                if(cycles-last_ref>max_gap)max_gap=cycles-last_ref;
                if(cycles-last_ref<min_gap)min_gap=cycles-last_ref;
                if(cycles-last_ref>1250 || cycles-last_ref<3)begin
                    violations=violations+1;
                    if(violations<=10)$display("VIOLATION full_frame_refresh_gap_cycles=%0d",cycles-last_ref);
                end
            end
            refs=refs+1;last_ref=cycles;
        end
    end
    always @(posedge app.mem_clk) begin
        if(app.wr_en)writes=writes+1;
        if(app.rd_en)reads=reads+1;
    end
    initial begin
        force app.rst=1'b1;
        #200;rst=0;wait(done);@(negedge app.clk);release app.rst;app.rst=0;
    end
    final begin
        $display("RESULT production_schedule refs=%0d min_gap=%0d max_gap=%0d violations=%0d writes=%0d reads=%0d",refs,min_gap,max_gap,violations,writes,reads);
        if(refs<60000 || max_gap>1250 || min_gap<3 || app.commits<12)
            $error("production refresh schedule incomplete or failed");
    end
    initial begin #(64'd3000000000);$fatal(1,"trace timeout");end
endmodule



