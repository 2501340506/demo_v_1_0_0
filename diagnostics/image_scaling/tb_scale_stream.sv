`timescale 1ns/1ps
module tb_scale_stream;
 reg clk=0,rst=1,start=0,fv=0,fe=0,ready=0;
 always #5 clk=~clk;
 reg [31:0] size,offset;reg [7:0] byte_in;
 wire permit,pv,done;wire [23:0] rgb;wire [2:0] error;
 bmp_scale_stream dut(clk,rst,start,size,fv,byte_in,offset,fe,8'd0,permit,pv,ready,rgb,done,error);
 integer w,h,stride,total,dw,dh,l,t,count,xx,yy,sx,sy,cycles=0,done_count;
 reg [7:0] header[0:53];reg [23:0] expected;reg checking=0;
 function [23:0] pattern(input integer x,y);pattern={8'(x*7+y),8'(y*3+x/7),8'(x^y)};endfunction
 function [7:0] source(input integer n);
  integer x,y,c;reg [23:0] p;
  begin
   if(n<54)source=header[n];
   else begin x=((n-54)%stride)/3;y=h-1-(n-54)/stride;c=((n-54)%stride)%3;
    p=pattern(x,y);source=x>=w?8'hee:(p>>(c*8));end
  end
 endfunction
 task put32(input integer at,v);begin for(integer k=0;k<4;k=k+1)header[at+k]=v>>(k*8);end endtask
 always @(negedge clk)begin cycles=cycles+1;ready=cycles%31<20;end
 always @(posedge clk) if(!rst)begin
  if(done)begin done_count=done_count+1;if(count!=307200)$fatal(1,"early done");end
  if(checking && pv && ready)begin
   xx=count%640;yy=479-count/640;expected=0;
   if(xx>=l && xx<l+dw && yy>=t && yy<t+dh)begin sx=(xx-l)*w/dw;sy=(yy-t)*h/dh;expected=pattern(sx,sy);end
   if(rgb!==expected)$fatal(1,"stream %0dx%0d pixel %0d got %h expected %h",w,h,count,rgb,expected);
   count=count+1;
  end
 end
 task run_image(input integer width,height);
 begin
  @(negedge clk);rst=1;checking=0;fv=0;fe=0;repeat(3)@(negedge clk);rst=0;
  w=width;h=height;stride=(w*3+3)&~3;total=54+stride*h;size=total;count=0;done_count=0;
  for(integer k=0;k<54;k=k+1)header[k]=0;
  header[0]="B";header[1]="M";put32(2,total);put32(10,54);put32(14,40);put32(18,w);put32(22,h);header[26]=1;header[28]=24;
  if(w*480>=h*640)begin dw=640;dh=h*640/w;end else begin dw=w*480/h;dh=480;end
  l=(640-dw)/2;t=(480-dh)/2;
  checking=1;start=1;@(negedge clk);start=0;
  for(integer i=0;i<total;i=i+1)begin
   if(i%512==0)begin fv=0;while(!permit)@(negedge clk);end
   fv=1;offset=i;byte_in=source(i);@(negedge clk);
  end
  fv=0;fe=1;@(negedge clk);fe=0;
  wait(done_count==1);repeat(5)@(negedge clk);
  if(count!=307200 || error!=0 || done_count!=1)$fatal(1,"stream completion");
  checking=0;$display("PASS byte stream %0dx%0d padded bytes=%0d exact pixels=%0d",w,h,total,count);
 end endtask
 initial begin
  run_image(160,120);run_image(640,480);run_image(801,601);run_image(1920,1080);run_image(1080,1920);
  $display("PASS byte stream suite");$finish;
 end
 initial begin #1000000000;$fatal(1,"watchdog");end
endmodule
