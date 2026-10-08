`timescale 1ns/1ps
// Compare the production-disabled S3 interface against the accepted S2 parser
// on identical 640x480 raw-sector scan/load inputs. BMP 2.11 S3 adds one
// completion clock; RGB is observable only while its write enable is asserted.
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
reg previous_done=0;
reg [3:0] previous_state_code=0;
always @(posedge app.clk) begin
 #1;
 if(!app.rst) begin
  cycles=cycles+1;
  if(app.dut.load_done !== previous_done) $fatal(1,"decoder completion latency");
  if(app.dut.ready !== reference_parser.ready && !reference_parser.load_done) $fatal(1,"ready mismatch");
  if(app.dut.state_code !== (app.dut.load_done ? previous_state_code : reference_parser.state_code)) $fatal(1,"state code mismatch");
  if({app.dut.scan_done,app.dut.scan_error,app.dut.scan_found_valid,
      app.dut.scan_found_sector,app.dut.scan_found_total,app.dut.load_error,
      app.dut.bmp_error,app.dut.write_req,app.dut.sd_sec_read,
      app.dut.sd_sec_read_addr,app.dut.bmp_data_wr_en} !==
     {reference_parser.scan_done,reference_parser.scan_error,reference_parser.scan_found_valid,
      reference_parser.scan_found_sector,reference_parser.scan_found_total,reference_parser.load_error,
      reference_parser.bmp_error,reference_parser.write_req,reference_parser.sd_sec_read,
      reference_parser.sd_sec_read_addr,reference_parser.bmp_data_wr_en})
   $fatal(1,"S2/S3 observable parser outputs differ at cycle %0d",cycles);
  if(app.dut.bmp_data_wr_en && app.dut.bmp_data !== reference_parser.bmp_data) $fatal(1,"RGB mismatch");
  if(app.dut.load_done)$display("PASS S2/S3 cycle comparison: %0d clocks, full 640x480 load",cycles);
 end
 previous_done=app.rst ? 0 : reference_parser.load_done;
 previous_state_code=reference_parser.state_code;
end
endmodule
