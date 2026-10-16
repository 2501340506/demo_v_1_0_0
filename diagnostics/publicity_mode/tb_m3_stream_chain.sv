`timescale 1ns/1ps
module tb_m3_stream_chain;
 reg clk=0; always #5 clk=~clk;
 reg rst_n=0,file_start=0;
 reg [31:0] limit=0,bytes=0,link=0;
 wire busy,done,valid,req;
 wire [7:0] value,error;
 wire [31:0] offset,lba;
 reg sector_busy=0,sector_valid=0,sector_done=0;
 reg [7:0] sector_byte=0;
 reg [8:0] sector_index=0;
 fat32_file_streamer #(.MAX_VISITED_CLUSTERS(2)) dut(
 .clk(clk),.rst_n(rst_n),.file_start(file_start),.data_permit(1'b1),
 .first_cluster(32'd2),.file_size(bytes),.sectors_per_cluster(8'd1),
 .fat_start_lba(32'd100),.data_start_lba(32'd200),.max_cluster(limit),
 .file_busy(busy),.file_done(done),.file_valid(valid),.file_byte(value),
 .file_byte_offset(offset),.fs_error(error),.sector_req(req),.sector_lba(lba),
 .sector_busy(sector_busy),.sector_valid(sector_valid),.sector_byte(sector_byte),
 .sector_byte_index(sector_index),.sector_done(sector_done),.sector_error(8'd0));
 integer seen=0,data_requests=0,fat_requests=0,checks=0;
 reg [31:0] first_data=0,second_data=0;
 always @(negedge clk) if(rst_n && valid)begin
  if(offset!==seen || value!==seen[7:0])$fatal(1,"byte/offset mismatch %d %h %h",seen,offset,value);
  seen=seen+1;
 end
 // Real request/response sequence, including last valid byte with done.
 initial forever begin
  @(posedge clk);#1;
  if(rst_n && req)begin
   sector_busy=1;
   if(lba==100 || (data_requests==1 && fat_requests==0))begin
    fat_requests=fat_requests+1;
    if(lba!==100)$fatal(1,"unexpected FAT LBA %h",lba);
    for(integer j=0;j<512;j=j+1)begin
     @(negedge clk);#1;sector_valid=1;sector_index=j;
     sector_byte=(j>=8 && j<12) ? (link >> (8*(j-8))) :
                 ((j>=12 && j<16) ? (link >> (8*(j-12))) : 0);
    end
   end else begin
    data_requests=data_requests+1;
    if(data_requests==1)first_data=lba;else second_data=lba;
    for(integer j=0;j<512;j=j+1)begin
     @(negedge clk);#1;sector_valid=1;sector_index=j;sector_byte=j;
    end
   end
   sector_done=1;
   @(negedge clk);#1;sector_valid=0;sector_done=0;sector_busy=0;
  end
 end
 task check_chain(input [31:0] next_value,max_value,size,input [7:0] expected_error,input integer expected_bytes);
 integer cycles;
 begin
  @(negedge clk);#2;rst_n=0;file_start=0;
  repeat(3)@(negedge clk);
  #2;limit=max_value;link=next_value;bytes=size;seen=0;
  data_requests=0;fat_requests=0;first_data=0;second_data=0;
  rst_n=1;file_start=1;
  @(negedge clk);#2;file_start=0;bytes=0;
  cycles=0;
  while(!done && cycles<5000)begin @(negedge clk);#2;cycles=cycles+1;end
  if(!done || error!==expected_error || seen!=expected_bytes || first_data!==200)
   $fatal(1,"chain=%h max=%h error=%h expected=%h bytes=%d expected=%d",next_value,max_value,error,expected_error,seen,expected_bytes);
  if(expected_bytes>512 && second_data!==200+((next_value & 32'h0fffffff)-2))
   $fatal(1,"second cluster request mismatch %h",second_data);
  checks=checks+1;
 end endtask
 initial begin
  check_chain(0,32'hfffffff,513,8'h24,512);
  check_chain(1,32'hfffffff,513,8'h24,512);
  check_chain(2,32'hfffffff,513,8'h23,512);
  check_chain(3,3,513,0,513);
  check_chain(4,3,513,8'h24,512);
  check_chain(32'hffff,32'hffff,513,0,513);
  check_chain(32'h10000,32'hffff,513,8'h24,512);
  check_chain(32'hffff,32'h10000,513,0,513);
  check_chain(32'h10000,32'h10000,513,0,513);
  check_chain(32'h10001,32'h10000,513,8'h24,512);
  check_chain(32'h20000,32'h1ffff,513,8'h24,512);
  check_chain(32'h1ffff,32'h20000,513,0,513);
  check_chain(32'hffffff7,32'hffffff7,513,0,513);
  check_chain(32'hffffff7,32'hffffff6,513,8'h24,512);
  check_chain(32'hffffff8,3,513,8'h25,512);
  check_chain(32'hffffffff,3,513,8'h25,512);
  check_chain(32'hf0010000,32'h10000,513,0,513);
  check_chain(32'hf0010001,32'h10000,513,8'h24,512);
  check_chain(3,3,1025,8'h26,1024);
  check_chain(32'hffffff8,3,512,0,512);
  $display("PASS M3 streamer chain: %0d real-sector range/EOC/self/count/nibble/EOF cases and exact bytes",checks);
  $finish;
 end
 initial begin #2000000;$fatal(1,"watchdog");end
endmodule
