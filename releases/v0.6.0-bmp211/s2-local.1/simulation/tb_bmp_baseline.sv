`timescale 1ns/1ps
module tb_bmp_baseline;
    reg clk=0; always #5 clk=~clk;
    reg rst=1, scan_start=0, load_start=0;
    wire ready, scan_done, found, req, ack, sd_req, dv, ending, we;
    wire [31:0] sector, addr;
    wire [2:0] total;
    wire [7:0] data;
    wire [23:0] rgb;
    wire load_done, load_error;
    wire [2:0] bmp_error;
    integer done_count=0;
    reg [2:0] ack_pipe=0;
    always @(posedge clk) ack_pipe <= rst ? 0 : {ack_pipe[1:0],req};
    assign ack=ack_pipe[2];
    bmp_read dut(.clk(clk),.rst(rst),.ready(ready),.scan_start(scan_start),
        `ifndef STABILITY_S2
      .scan_pause_request(1'b0),.scan_resume(1'b0),.scan_paused(),.scan_resume_sector(),
`endif
      .scan_start_sector(32'd0),.scan_max_sector(32'd7203),.scan_target_count(3'd4),
        .scan_error(),
        .scan_done(scan_done),.scan_found_valid(found),.scan_found_sector(sector),.scan_found_total(total),
        .load_start(load_start),.load_sector(32'd1801),.sd_init_done(!rst),.state_code(),
        .load_done(load_done),.load_error(load_error),.bmp_error(bmp_error),
        .bmp_width(16'd640),.bmp_height(16'd480),.write_req(req),.write_req_ack(ack),
        .sd_sec_read(sd_req),.sd_sec_read_addr(addr),.sd_sec_read_data(data),
        .sd_sec_read_data_valid(dv),.sd_sec_read_failed(1'b0),.sd_sec_read_end(ending),.bmp_data_wr_en(we),.bmp_data(rgb));wire [0:0] ref_ready;
wire [0:0] ref_scan_done;
wire [0:0] ref_scan_found_valid;
wire [31:0] ref_scan_found_sector;
wire [2:0] ref_scan_found_total;
wire [0:0] ref_load_done;
wire [0:0] ref_load_error;
wire [2:0] ref_bmp_error;
wire [0:0] ref_write_req;
wire [0:0] ref_sd_sec_read;
wire [31:0] ref_sd_sec_read_addr;
wire [0:0] ref_bmp_data_wr_en;
wire [23:0] ref_bmp_data;
bmp_read #(.USE_DECODER(0)) reference(.clk(clk),.rst(rst),.ready(ref_ready),.scan_start(scan_start),
        `ifndef STABILITY_S2
      .scan_pause_request(1'b0),.scan_resume(1'b0),.scan_paused(),.scan_resume_sector(),
`endif
      .scan_start_sector(32'd0),.scan_max_sector(32'd7203),.scan_target_count(3'd4),
        .scan_error(),
        .scan_done(ref_scan_done),.scan_found_valid(ref_scan_found_valid),.scan_found_sector(ref_scan_found_sector),.scan_found_total(ref_scan_found_total),
        .load_start(load_start),.load_sector(32'd1801),.sd_init_done(!rst),.state_code(),
        .load_done(ref_load_done),.load_error(ref_load_error),.bmp_error(ref_bmp_error),
        .bmp_width(16'd640),.bmp_height(16'd480),.write_req(ref_write_req),.write_req_ack(ack),
        .sd_sec_read(ref_sd_sec_read),.sd_sec_read_addr(ref_sd_sec_read_addr),.sd_sec_read_data(data),
        .sd_sec_read_data_valid(dv),.sd_sec_read_failed(1'b0),.sd_sec_read_end(ending),.bmp_data_wr_en(ref_bmp_data_wr_en),.bmp_data(ref_bmp_data));
always @(negedge clk) if(!rst) begin
if(ref_ready !== ready) $fatal(1,"A/B ready");
if(ref_scan_done !== scan_done) $fatal(1,"A/B scan_done");
if(ref_scan_found_valid !== found) $fatal(1,"A/B scan_found_valid");
if(ref_scan_found_sector !== sector) $fatal(1,"A/B scan_found_sector");
if(ref_scan_found_total !== total) $fatal(1,"A/B scan_found_total");
if(ref_load_done !== load_done) $fatal(1,"A/B load_done");
if(ref_load_error !== load_error) $fatal(1,"A/B load_error");
if(ref_bmp_error !== bmp_error) $fatal(1,"A/B bmp_error");
if(ref_write_req !== req) $fatal(1,"A/B write_req");
if(ref_sd_sec_read !== sd_req) $fatal(1,"A/B sd_sec_read");
if(ref_sd_sec_read_addr !== addr) $fatal(1,"A/B sd_sec_read_addr");
if(ref_bmp_data_wr_en !== we) $fatal(1,"A/B bmp_data_wr_en");
if(dut.bmp_data_wr_en && ref_bmp_data !== rgb) $fatal(1,"A/B RGB");
end

    sim_bmp_sectors card(.clk(clk),.rst(rst),.request(sd_req),.address(addr),
        .bad_headers(4'd0),.data(data),.valid(dv),.sector_end(ending),.busy());
    integer found_count=0, pixels=0;
    reg [7:0] r,g,b;
    always @(posedge clk) if(!rst) begin
        if(load_done) done_count=done_count+1;
        if(load_error || bmp_error!=0) $fatal(1,"normal image reported error");
        if(found) begin
            if(sector !== found_count*1801) $fatal(1,"wrong scan sector %0d",sector);
            found_count=found_count+1;
        end
        if(we) begin
            b=pixels+1; g=pixels/640+8'h35; r=pixels%640+8'h91;
            if(rgb !== {r,g,b}) $fatal(1,"RGB mismatch pixel %0d",pixels);
            pixels=pixels+1;
        end
    end
    initial begin
        repeat(5) @(negedge clk); rst=0;
        @(negedge clk); scan_start=1;
        @(negedge clk); scan_start=0;
        wait(scan_done); repeat(2) @(negedge clk);
        if(found_count!=4 || total!=4) $fatal(1,"scan count");
        load_start=1; @(negedge clk); load_start=0;
        wait(!ready); wait(ready); repeat(3) @(negedge clk);
        if(pixels!=307200) $fatal(1,"pixel count %0d",pixels);
        if(done_count!=1) $fatal(1,"expected one explicit load success");
        $display("PASS full-size raw-sector scan and 307200 independently checked RGB pixels");
        $finish;
    end
    initial begin #30000000; $fatal(1,"baseline watchdog"); end
endmodule
