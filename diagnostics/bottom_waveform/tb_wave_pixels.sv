`timescale 1ns/1ps
module tb_wave_pixels;
 reg clk=0,rst=1,hs=1,vs=1,de=0,en=1;
 always #5 clk=~clk;
 reg [9:0] x=0;reg [8:0] y=0;reg [23:0] rgb=0;
 integer mode=0;
 wire [6:0] bar;
 function integer level(input integer m,input integer index);
  level=m==0?0:m==1?1:m==2?14:m==3?28:m==4?31:index%29;
 endfunction
 wire [4:0] height=level(mode,bar);
 wire ho,vo,dout;wire [9:0] xo;wire [23:0] out,bypass;
 audio_ring_overlay dut(clk,rst,hs,vs,de,en,x,y,rgb,height,bar,ho,vo,dout,xo,out);
 audio_ring_overlay #(.ENABLE(0)) disabled(clk,rst,hs,vs,de,en,x,y,rgb,height, , , , , ,bypass);
 // Independent model of the v0.26 geometry: mirrored 40-entry history,
 // cos^2 envelope, rounded caps, minimum dot and blue bottom wash.
 function [7:0] wash(input integer c,input integer b,input integer k);
  wash=c-(c*k)/16+(b*k)/16;
 endfunction
 function [23:0] model(input integer px,input integer py,input [23:0] c,input integer m,input reg on);
  integer slot,index,e,w,h,half,row,col,k;
  begin
   model=c;
   if(on && px<640 && py>=448 && py<480)begin
    slot=px/8;index=slot<40?slot:79-slot;e=slot<40?39-slot:slot-40;
    w=$rtoi(2.0+14.0*$cos(3.14159265358979*e/80.0)**2+0.5);
    h=level(m,index);if(h>28)h=28;
    half=(h*w)/32+1;
    row=py<464?463-py:py-464;col=px%8;k=4+(py-448)/4+(py-448)/8;
    if(row<half && (row==half-1 ? col>=3 && col<5 : col>=2 && col<6))model=24'hffffff;
    else model={wash(c[23:16],8'h3c,k),wash(c[15:8],8'h82,k),wash(c[7:0],8'hf0,k)};
   end
  end
 endfunction
 reg [23:0] expected=0,oldrgb=0;
 reg oldhs=1,oldvs=1,oldde=0;reg [9:0] oldx=0;
 integer checks=0,white=0,dots=0;reg [79:0] seen=0;
 always @(posedge clk)begin
  #1;
  if(!rst)begin
   if({ho,vo,dout,xo,bypass}!=={oldhs,oldvs,oldde,oldx,oldrgb})$fatal(1,"two-clock video alignment");
   if(out!==expected)$fatal(1,"pixel x=%0d y=%0d mode=%0d got=%h expected=%h",oldx,y,mode,out,expected);
   checks++;
   if(out==24'hffffff && oldrgb!=24'hffffff)white++;
  end
  oldhs=hs;oldvs=vs;oldde=de;oldx=x;oldrgb=rgb;
  expected=model(x,y,rgb,mode,en && de);
  if(expected==24'hffffff)seen[x/8]=1;
  if(mode==0 && expected==24'hffffff)dots++;
 end
 integer px,py,k;
 initial begin
  repeat(3)@(negedge clk);rst=0;
  for(k=0;k<7;k++)begin
   mode=k<6?k:3;en=k!=6;
   for(py=0;py<480;py++)begin
    for(px=0;px<640;px++)begin
     @(negedge clk);de=1;x=px;y=py;rgb={px[7:0],py[7:0],8'h60};
    end
    @(negedge clk);de=0;hs=0;repeat(3)@(negedge clk);hs=1;
   end
   @(negedge clk);vs=0;repeat(4)@(negedge clk);vs=1;
  end
  repeat(4)@(negedge clk);
  // Silence leaves one 2x2 dot per slot; every slot must ink.
  if(seen!={80{1'b1}} || dots!=80*4 || white<10000)$fatal(1,"coverage dots=%0d white=%0d",dots,white);
  $display("PASS waveform pixels: %0d comparisons; 80 mirrored slots; silence dots, envelope, caps, wash; zero/low/mid/max/overflow/history/disabled; two-clock timing",checks);$finish;
 end
 initial begin #30000000;$fatal(1,"timeout");end
endmodule
