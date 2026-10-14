`timescale 1ns/1ps
module tb_scaler;
 reg clk=0,rst=1,start=0,iv=0,oready=0;
 always #5 clk=~clk;
 reg [15:0] w,h,ix,iy;reg [31:0] rgb;
 wire ir,ov,done;wire [31:0] out_rgb;
 image_scale_nearest dut(clk,rst,start,w,h,iv,ir,rgb,ix,iy,ov,oready,out_rgb,done);
 integer count,dw,dh,l,t,xx,yy,srcx,srcy,cases=0,cycles=0;
 reg checking=0;reg [31:0] expected;
 function [31:0] pattern(input integer x,y);
  pattern={8'(x*7+y),8'(y*3+x/7),8'(x^y),8'(x*13+y*19)};
 endfunction
 always @(negedge clk) begin cycles=cycles+1;oready=(cycles%19<13);end
 always @(posedge clk) if(!rst && checking && ov && oready) begin
  xx=count%640; yy=479-count/640;
  expected=32'h000000FF;
  if(xx>=l && xx<l+dw && yy>=t && yy<t+dh) begin
   srcx=(xx-l)*w/dw;srcy=(yy-t)*h/dh;expected=pattern(srcx,srcy);
  end
  if(out_rgb!==expected) $fatal(1,"pixel %0dx%0d at %0d,%0d got %h expected %h",w,h,xx,yy,out_rgb,expected);
  count=count+1;
 end
 task run_image(input integer width,height);
  integer a,b;
  begin
   @(negedge clk);rst=1;iv=0;checking=0;repeat(3)@(negedge clk);rst=0;
   w=width;h=height;count=0;
   if(width*480>=height*640)begin dw=640;dh=height*640/width;end
   else begin dh=480;dw=width*480/height;end
   if(dw==0)dw=1;if(dh==0)dh=1;l=(640-dw)/2;t=(480-dh)/2;
   checking=1;start=1;@(negedge clk);start=0;
   for(b=height-1;b>=0;b=b-1) for(a=0;a<width;a=a+1) begin
    iv=1;ix=a;iy=b;rgb=pattern(a,b);
    @(posedge clk);while(!ir)@(posedge clk);
    @(negedge clk);
   end
   iv=0;
   wait(count==307200);@(negedge clk);checking=0;cases=cases+1;
   $display("PASS scaler %0dx%0d 307200 exact pixels",width,height);
  end
 endtask
 initial begin
  run_image(160,120);run_image(320,240);run_image(640,480);run_image(800,600);
  run_image(1024,768);run_image(1920,1080);run_image(1080,1920);
  run_image(317,239);run_image(801,601);
  // Cancel while replaying a magnified row, then reuse the same instance.
  @(negedge clk);rst=1;repeat(3)@(negedge clk);rst=0;
  w=2;h=2;start=1;@(negedge clk);start=0;
  ix=0;iy=1;rgb=1;iv=1;@(posedge clk);while(!ir)@(posedge clk);@(negedge clk);
  ix=1;@(posedge clk);while(!ir)@(posedge clk);@(negedge clk);iv=0;
  wait(ov);run_image(321,241);
  $display("PASS scaler suite: %0d images plus cancellation",cases);$finish;
 end
 initial begin #500000000;$fatal(1,"watchdog");end
endmodule
