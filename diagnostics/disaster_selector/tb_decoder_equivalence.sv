`timescale 1ns/1ps
module decoder_compare #(parameter FLOW=0,RANGE=0)(
 input clk,rst,start,v,finish,drain,input [7:0] b,upstream,input [31:0] offset,size,
 output ready
);
 wire [126:0] actual,expected;
 wire ar,er;
 assign ready=ar;
 bmp24_decoder #(.EXPECTED_WIDTH(320),.EXPECTED_HEIGHT(240),.ALLOW_32(1),.RANGE_DIMENSIONS(RANGE),.FLOW_CONTROL(FLOW)) dut(
 .clk(clk),.rst(rst),.expected_width(16'd320),.expected_height(16'd240),
 .file_start(start),.file_size(size),.file_valid(v),.file_byte(b),.file_byte_offset(offset),.file_end(finish),.upstream_error(upstream),
 .header_accepted(actual[0]),.pixel_valid(actual[1]),.pixel_rgb(actual[25:2]),.pixel_x(actual[41:26]),.pixel_y(actual[57:42]),
 .frame_commit(actual[58]),.bmp_done(actual[59]),.bmp_error(actual[62:60]),.pixel_ready(drain),.file_ready(ar),
 .image_width(actual[78:63]),.image_height(actual[94:79]),.pixel_rgba(actual[126:95]));
 bmp24_decoder_reference #(.EXPECTED_WIDTH(320),.EXPECTED_HEIGHT(240),.ALLOW_32(1),.RANGE_DIMENSIONS(RANGE),.FLOW_CONTROL(FLOW)) ref_dut(
 .clk(clk),.rst(rst),.expected_width(16'd320),.expected_height(16'd240),
 .file_start(start),.file_size(size),.file_valid(v),.file_byte(b),.file_byte_offset(offset),.file_end(finish),.upstream_error(upstream),
 .header_accepted(expected[0]),.pixel_valid(expected[1]),.pixel_rgb(expected[25:2]),.pixel_x(expected[41:26]),.pixel_y(expected[57:42]),
 .frame_commit(expected[58]),.bmp_done(expected[59]),.bmp_error(expected[62:60]),.pixel_ready(drain),.file_ready(er),
 .image_width(expected[78:63]),.image_height(expected[94:79]),.pixel_rgba(expected[126:95]));
 always @(negedge clk)if(!rst && ({actual,ar} !== {expected,er}))$fatal(1,"decoder mismatch FLOW=%d RANGE=%d offset=%d size=%h actual=%h expected=%h",FLOW,RANGE,offset,size,{actual,ar},{expected,er});
endmodule
module tb_decoder_equivalence;
 reg clk=0,rst=1,start=0,v=0,finish=0;
 always #5 clk=~clk;
 reg [7:0] b=0,upstream=0;
 reg [31:0] offset=0,size=0;
 reg stalls=0;
 integer cycle=0,pixels_seen=0,commits_free=0,commits_flow=0;
 always @(posedge clk)cycle<=cycle+1;
 wire drain=!stalls || cycle%11<7;
 wire [3:0] ready;
 decoder_compare #(.FLOW(0),.RANGE(0)) a(clk,rst,start,v,finish,drain,b,upstream,offset,size,ready[0]);
 decoder_compare #(.FLOW(1),.RANGE(0)) c(clk,rst,start,v,finish,drain,b,upstream,offset,size,ready[1]);
 decoder_compare #(.FLOW(0),.RANGE(1)) d(clk,rst,start,v,finish,drain,b,upstream,offset,size,ready[2]);
 decoder_compare #(.FLOW(1),.RANGE(1)) e(clk,rst,start,v,finish,drain,b,upstream,offset,size,ready[3]);
 always @(posedge clk)begin
  if(rst)begin pixels_seen<=0;commits_free<=0;commits_flow<=0;end
  else begin
   if(d.dut.pixel_valid)pixels_seen<=pixels_seen+1;
   if(d.dut.frame_commit)commits_free<=commits_free+1;
   if(e.dut.frame_commit)commits_flow<=commits_flow+1;
  end
 end
 reg [7:0] bytes[0:71];
 integer i,j,seed=19451;
 reg [31:0] w,h,pix,flen;
 reg [15:0] bits;
 task word32(input integer loc,input [31:0] value);begin
  bytes[loc]=value[7:0];bytes[loc+1]=value[15:8];bytes[loc+2]=value[23:16];bytes[loc+3]=value[31:24];
 end endtask
 task payload_image(input integer width,height,bpp);
  integer n,stride;
  begin
   @(negedge clk);rst=1;v=0;start=0;finish=0;upstream=0;
   repeat(3)@(negedge clk);rst=0;
   for(n=0;n<72;n=n+1)bytes[n]=0;
   stride=(width*(bpp/8)+3)&~3;size=54+stride*height;
   bytes[0]="B";bytes[1]="M";bytes[26]=1;bytes[28]=bpp;
   word32(2,size);word32(10,54);word32(14,40);word32(18,width);word32(22,height);
   start=1;@(negedge clk);start=0;
   for(n=0;n<size;n=n+1)begin
    v=0;while(ready!=15)@(negedge clk);
    v=1;offset=n;b=n<54?bytes[n]:(n*37+11);
    @(negedge clk);v=0;
    if(n%17==0)repeat(2)@(negedge clk);
   end
   finish=1;@(negedge clk);finish=0;
   repeat(20)@(negedge clk);
   if(pixels_seen!=width*height || commits_free!=1 || commits_flow!=1 || d.dut.bmp_error || e.dut.bmp_error)
    $fatal(1,"complete rows width=%d height=%d bpp=%d pixels=%d commits=%d/%d errors=%d/%d",width,height,bpp,pixels_seen,commits_free,commits_flow,d.dut.bmp_error,e.dut.bmp_error);
  end
 endtask
 initial begin
  for(j=0;j<4000;j=j+1)begin
   @(negedge clk);rst=1;v=0;start=0;finish=0;upstream=0;
   repeat(3)@(negedge clk);rst=0;
   for(i=0;i<72;i=i+1)bytes[i]=0;
   w=320;h=240;pix=54;bits=j[0]?24:32;
   case(j%8)
    1:begin w=1080;h=1920;end
    2:begin w=1920;h=1080;end
    3:pix=32'hfffffff0;
    4:pix=65536-54;
    5:begin w=1;h=1;end
    6:w=0;
    default:;
   endcase
   flen=pix+((w*(bits==32?4:3)+3)&32'hfffffffc)*h;
   case(j%7)
    0:size=flen;1:size=flen-1;2:size=flen+1;3:size={flen[31:16]+16'd1,flen[15:0]};
    4:size=32'hffffffff;5:size=0;default:size=$random(seed);
   endcase
   bytes[0]="B";bytes[1]="M";bytes[26]=1;bytes[28]=bits;
   word32(2,flen);word32(10,pix);word32(14,40);word32(18,w);word32(22,h);
   if(j%23==0)bytes[0]=0;
   start=1;@(negedge clk);start=0;
   for(i=0;i<72;i=i+1)begin
    while(ready!=15)@(negedge clk);
    v=1;offset=i;b=bytes[i];@(negedge clk);
    if(j%3==0)begin v=0;repeat(2)@(negedge clk);end
   end
   v=0;finish=1;@(negedge clk);finish=0;
   repeat(10)@(negedge clk);
  end
  stalls=1;
  for(j=24;j<=32;j=j+8)begin
   payload_image(1,3,j);payload_image(3,3,j);payload_image(7,3,j);payload_image(1920,3,j);
  end
  $display("PASS decoder equivalence 4000 headers x 4 configurations plus 8 complete 24/32bpp row-boundary images with stalls, independent directory sizes and exact acceptance/error/pixel timing");$finish;
 end
 initial begin #100000000;$fatal(1,"watchdog");end
endmodule
