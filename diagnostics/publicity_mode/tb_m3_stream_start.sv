`timescale 1ns/1ps
module tb_m3_stream_start;
 reg clk=0; always #5 clk=~clk;
 reg rst_n=0,file_start=0;
 reg [31:0] first_cluster,file_size,max_cluster;
 reg [7:0] sectors_per_cluster;
 wire file_busy,file_done,sector_req;
 wire [7:0] fs_error;
 wire [31:0] sector_lba;
 fat32_file_streamer dut(
 .clk(clk),.rst_n(rst_n),.file_start(file_start),.data_permit(1'b1),
 .first_cluster(first_cluster),.file_size(file_size),.sectors_per_cluster(sectors_per_cluster),
 .fat_start_lba(32'd100),.data_start_lba(32'd200),.max_cluster(max_cluster),
 .file_busy(file_busy),.file_done(file_done),.file_valid(),.file_byte(),.file_byte_offset(),
 .fs_error(fs_error),.sector_req(sector_req),.sector_lba(sector_lba),
 .sector_busy(1'b0),.sector_valid(1'b0),.sector_byte(8'd0),.sector_byte_index(9'd0),
 .sector_done(1'b0),.sector_error(8'd0));
 integer checks=0;
 task check_start(input [31:0] first,limit,size,input [7:0] spc,input integer outcome);
 integer n; reg observed;
 begin
  @(negedge clk);rst_n=0;file_start=0;
  first_cluster=first;max_cluster=limit;file_size=size;sectors_per_cluster=spc;
  repeat(3) @(negedge clk);
  rst_n=1;file_start=1;
  @(negedge clk);file_start=0;
  // Accepted metadata must survive a caller changing its next file selection.
  first_cluster=0;file_size=0;
  observed=0;
  for(n=0;n<24;n=n+1)begin
   @(negedge clk);
   if(sector_req)begin
    if(outcome!=0 || sector_lba!==200+((first-2)*spc))
     $fatal(1,"unexpected request first=%h limit=%h lba=%h",first,limit,sector_lba);
    observed=1;
   end
   if(file_done)begin
    if(outcome==0 || fs_error!==(outcome==1?8'h24:8'h00))
     $fatal(1,"unexpected completion first=%h limit=%h error=%h",first,limit,fs_error);
    observed=1;
   end
  end
  if(!observed)$fatal(1,"start stalled first=%h limit=%h",first,limit);
  checks=checks+1;
 end endtask
 initial begin
  check_start(0,32'hffffffff,16,1,1);
  check_start(1,32'hffffffff,16,1,1);
  check_start(2,2,16,1,0);
  check_start(3,2,16,1,1);
  check_start(32'hffff,32'hffff,16,1,0);
  check_start(32'h10000,32'hffff,16,1,1);
  check_start(32'hffff,32'h10000,16,1,0);
  check_start(32'h10000,32'h10000,16,1,0);
  check_start(32'h10001,32'h10000,16,1,1);
  check_start(32'h20000,32'h1ffff,16,1,1);
  check_start(32'h1ffff,32'h20000,16,1,0);
  check_start(32'hffffffff,32'hffffffff,16,1,0);
  check_start(32'hffffffff,32'hfffffffe,16,1,1);
  check_start(32'h80000000,32'h7fffffff,16,1,1);
  check_start(32'h7fffffff,32'h80000000,16,1,0);
  check_start(2,100,16,0,1);
  check_start(2,100,16,3,1);
  check_start(3,100,16,128,0);
  check_start(0,0,0,0,2);
  check_start(32'hffffffff,2,0,1,2);
  $display("PASS M3 streamer start: %0d request/error/empty boundary cases and accepted metadata",checks);
  $finish;
 end
 initial begin #100000;$fatal(1,"watchdog");end
endmodule
