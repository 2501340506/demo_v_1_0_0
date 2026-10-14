`timescale 1ns/1ps
module tb_rgba_decoder;
 reg clk=0,rst=1,start=0,fv=0,fe=0,ready=0;
 always #5 clk=~clk;
 reg [15:0] w=5,h=3;
 reg [31:0] size,off;
 reg [7:0] data;
 wire fr,pv,done,commit;wire [31:0] rgba;wire [23:0] rgb;
 wire [15:0] x,y;wire [2:0] error;
 bmp24_decoder #(.RUNTIME_DIMENSIONS(1),.FLOW_CONTROL(1)) dut(
  .clk(clk),.rst(rst),.expected_width(w),.expected_height(h),.file_start(start),.file_size(size),
  .file_valid(fv),.file_byte(data),.file_byte_offset(off),.file_end(fe),.upstream_error(8'd0),
  .header_accepted(),.pixel_valid(pv),.pixel_rgb(rgb),.pixel_rgba(rgba),.pixel_x(x),.pixel_y(y),
  .frame_commit(commit),.bmp_done(done),.bmp_error(error),.pixel_ready(ready),.file_ready(fr),
  .image_width(),.image_height());
 integer depth,stride,total,count,ends,commits,cycles=0,tail_hold=0;
 reg [7:0] hdr[0:53];reg [31:0] held;reg [15:0] held_x,held_y;reg stalled=0;
 function [31:0] pattern(input integer a,b);
  pattern={8'(a*31+b),8'(b*57+a),8'(a^b),8'(a*43+b*71)};
 endfunction
 task put32(input integer at,v);for(integer k=0;k<4;k=k+1)hdr[at+k]=v>>(8*k);endtask
 function [7:0] source(input integer n);
  integer a,b,c;reg [31:0] p;
  begin
   if(n<54)source=hdr[n];
   else begin
    a=((n-54)%stride)/(depth/8);b=h-1-(n-54)/stride;c=((n-54)%stride)%(depth/8);
    p=pattern(a,b);
    case(c)0:source=p[15:8];1:source=p[23:16];2:source=p[31:24];3:source=p[7:0];endcase
    if(a>=w)source=8'hEE;
   end
  end
 endfunction
 always @(negedge clk)begin
  cycles=cycles+1;
  if(tail_hold>0)begin ready=0;tail_hold=tail_hold-1;end
  else ready=(cycles%17<9);
 end
 always @(posedge clk)if(!rst)begin
  if(stalled && (!pv || rgba!==held || x!==held_x || y!==held_y))$fatal(1,"stalled pixel changed");
  stalled=pv&&!ready;held=rgba;held_x=x;held_y=y;
  if(pv && ready)begin
   if(x!=count%w || y!=h-1-count/w)$fatal(1,"coordinate %0d",count);
   if(rgb!==pattern(x,y)>>8 || rgba!=={rgb,(depth==32?8'(x*43+y*71):8'hFF)})$fatal(1,"RGBA %0d got %h",count,rgba);
   count=count+1;
  end
  if(done)begin if(count!=w*h)$fatal(1,"done before drain");ends=ends+1;end
  if(commit)commits=commits+1;
 end
 task run_case(input integer width,bits,cut,compression);
  begin
   @(negedge clk);rst=1;fv=0;fe=0;stalled=0;repeat(3)@(negedge clk);rst=0;
   w=width;depth=bits;stride=(w*(bits/8)+3)&~3;total=54+stride*h;size=total;count=0;ends=0;commits=0;
   for(integer k=0;k<54;k=k+1)hdr[k]=0;
   hdr[0]="B";hdr[1]="M";put32(2,total);put32(10,54);put32(14,40);put32(18,w);put32(22,h);hdr[26]=1;hdr[28]=bits;put32(30,compression);
   start=1;@(negedge clk);start=0;
   for(integer n=0;n<total-cut;n=n+1)begin
    fv=1;off=n;data=source(n);
    // Pulse file_end after accepting the last byte, while its pixel is stalled.
    @(posedge clk);while(!fr)@(posedge clk);
    if(n==total-cut-1)begin
     @(negedge clk);fv=0;fe=1;tail_hold=25;
     @(negedge clk);fe=0;
    end else @(negedge clk);
   end
   fv=0;repeat(60)@(negedge clk);
   if(compression)begin if(error!=1 || count || ends || commits)$fatal(1,"compression accepted");end
   else if(cut)begin if(error!=3 || ends || commits)$fatal(1,"missing alpha accepted");end
   else if(error || count!=w*h || ends!=1 || commits!=1)$fatal(1,"completion bits=%0d count=%0d ends=%0d error=%0d",bits,count,ends,error);
   $display("PASS RGBA decoder width=%0d depth=%0d cut=%0d compression=%0d",w,depth,cut,compression);
  end
 endtask
 initial begin
  for(integer k=1;k<=5;k=k+1)begin run_case(k,24,0,0);run_case(k,32,0,0);end
  run_case(5,32,1,0);run_case(5,32,0,3);run_case(5,32,0,0);
  $display("PASS RGBA decoder suite: padding, alpha, stalls, final drain, rejection/recovery");$finish;
 end
 initial begin #1000000;$fatal(1,"watchdog");end
endmodule
