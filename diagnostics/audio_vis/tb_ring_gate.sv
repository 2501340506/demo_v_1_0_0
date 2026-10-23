`timescale 1ns/1ps
module tb_ring_gate;
 reg clk=0,rst=1;always #20 clk=~clk;
 reg [9:0] x=520;reg [8:0] y=310;reg [4:0] height=0;
 wire [6:0] a,b;wire ah,av,ad,bh,bv,bd;wire [9:0] ax,bx;wire [23:0] ar,br;
 audio_ring_overlay gate(.clk(clk),.rst(rst),.hs(1'b1),.vs(1'b1),.de(1'b1),.enable(1'b1),
 .pixel_x(x),.pixel_y(y),.rgb_in(24'h123456),.bar_height(height),.bar_index(a),
 .hs_out(ah),.vs_out(av),.de_out(ad),.x_out(ax),.rgb_out(ar),.wash_level(2'd2));
 ring_overlay_reference refdut(clk,rst,1'b1,1'b1,1'b1,1'b1,x,y,24'h123456,height,b,bh,bv,bd,bx,br);
 integer px,py,h,n=0;
 initial begin
  #2000;@(negedge clk);rst=0;repeat(4)@(negedge clk);
  for(h=0;h<3;h++)begin
   height=h==0?0:h==1?14:28;
   for(py=215;py<=405;py++)for(px=425;px<=615;px++)begin
    @(negedge clk);x=px;y=py;
    @(posedge clk);#10;
    if({a,ah,av,ad,ax,ar}!=={b,bh,bv,bd,bx,br})$fatal(1,"gate ROM/pixel mismatch x=%d y=%d got=%h expected=%h",x,y,ar,br);
    n++;
   end
  end
  $display("PASS synthesized ring ROM and pipeline: %0d pixels at heights 0/14/28",n);$finish;
 end
endmodule
