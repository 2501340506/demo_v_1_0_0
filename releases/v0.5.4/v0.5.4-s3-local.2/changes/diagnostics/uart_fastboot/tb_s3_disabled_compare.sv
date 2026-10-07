`timescale 1ns/1ps
// Compare the production-disabled S3 interface against the accepted S2 parser
// on identical 640x480 raw-sector scan/load inputs, every control clock.
module tb_s3_disabled_compare;
tb_bmp_baseline app();
bmp_read_s2 reference_parser(
 .clk(app.clk),.rst(app.rst),.ready(),.scan_start(app.scan_start),
 .scan_start_sector(32'd0),.scan_max_sector(32'd7203),.scan_target_count(3'd4),
 .scan_done(),.scan_error(),.scan_found_valid(),.scan_found_sector(),.scan_found_total(),
 .load_start(app.load_start),.load_sector(32'd1801),.load_done(),.load_error(),.bmp_error(),
 .sd_init_done(!app.rst),.state_code(),.bmp_width(16'd640),.bmp_height(16'd480),
 .write_req(),.write_req_ack(app.ack),.sd_sec_read(),.sd_sec_read_addr(),
 .sd_sec_read_data(app.data),.sd_sec_read_data_valid(app.dv),.sd_sec_read_end(app.ending),
 .sd_sec_read_failed(1'b0),.bmp_data_wr_en(),.bmp_data());
integer cycles=0;
always @(posedge app.clk) begin
 #1;
 if(!app.rst) begin
  cycles=cycles+1;
  if({app.dut.ready,app.dut.scan_done,app.dut.scan_error,app.dut.scan_found_valid,
      app.dut.scan_found_sector,app.dut.scan_found_total,app.dut.load_done,app.dut.load_error,
      app.dut.bmp_error,app.dut.state_code,app.dut.write_req,app.dut.sd_sec_read,
      app.dut.sd_sec_read_addr,app.dut.bmp_data_wr_en,app.dut.bmp_data} !==
     {reference_parser.ready,reference_parser.scan_done,reference_parser.scan_error,reference_parser.scan_found_valid,
      reference_parser.scan_found_sector,reference_parser.scan_found_total,reference_parser.load_done,reference_parser.load_error,
      reference_parser.bmp_error,reference_parser.state_code,reference_parser.write_req,reference_parser.sd_sec_read,
      reference_parser.sd_sec_read_addr,reference_parser.bmp_data_wr_en,reference_parser.bmp_data})
   $fatal(1,"S2/S3 observable parser outputs differ at cycle %0d",cycles);
  if(app.dut.load_done)$display("PASS S2/S3 cycle comparison: %0d clocks, full 640x480 load",cycles);
 end
end
endmodule
