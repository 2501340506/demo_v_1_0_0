`timescale 1ns/1ps
module tb_cn_font;
 reg [7:0] c; reg [3:0] row; wire [15:0] pixels;
 integer i,r,seen;
 osd_font_cn_16x16 dut(.character(c),.row(row),.pixels(pixels));
 initial begin
  for(i=0;i<13;i=i+1) begin
   c=8'h80+i; seen=0;
   for(r=0;r<16;r=r+1) begin row=r; #1; if(pixels!=0) seen=seen+1; end
   if(seen==0) $fatal(1,"empty CN glyph %h",c);
  end
  c=8'h7f; row=0; #1; if(pixels!==0)$fatal(1,"unknown glyph not transparent");
  $display("PASS CN font: thirteen 16x16 glyph IDs 80..8c and unknown transparency");
  $finish;
 end
endmodule
