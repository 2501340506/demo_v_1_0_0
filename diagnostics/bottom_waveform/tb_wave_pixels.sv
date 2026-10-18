`timescale 1ns/1ps
module tb_wave_pixels;
 reg clk=0,rst=1,hs=1,vs=1,de=0,en=1;
 always #5 clk=~clk;
 reg [9:0] x=0;reg [8:0] y=0;reg [23:0] rgb=0;
 integer mode=0;
 wire [6:0] bar;
 wire [4:0] height=mode==0?0:mode==1?1:mode==2?14:mode==3?28:mode==4?31:bar%29;
 wire ho,vo,dout;wire [9:0] xo;wire [23:0] out,bypass;
 audio_ring_overlay dut(clk,rst,hs,vs,de,en,x,y,rgb,height,bar,ho,vo,dout,xo,out);
 audio_ring_overlay #(.ENABLE(0)) disabled(clk,rst,hs,vs,de,en,x,y,rgb,height, , , , , ,bypass);
 reg [23:0] expected=0,oldrgb=0;
 reg oldhs=1,oldvs=1,oldde=0;reg [9:0] oldx=0;
 integer h,checks=0,painted=0,columns=0;reg [79:0] seen=0;
 always @(posedge clk)begin
  #1;
  if(!rst)begin
   if({ho,vo,dout,xo,bypass}!=={oldhs,oldvs,oldde,oldx,oldrgb})$fatal(1,"two-clock video alignment");
   if(out!==expected)$fatal(1,"pixel x=%d y=%d mode=%d got=%h expected=%h",oldx,y,mode,out,expected);
   checks++;
   if(out!=oldrgb)painted++;
  end
  oldhs=hs;oldvs=vs;oldde=de;oldx=x;oldrgb=rgb;
  h=mode==0?0:mode==1?1:mode==2?14:mode==3?28:mode==4?28:(x/8)%29;
  expected=rgb;
  if(en && de && x<640 && y>=452 && y<480 && (x%8)>=2 && (x%8)<5 && 480-y<=h)begin
   expected=24'hb45ac8;seen[x/8]=1;
  end
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
  if(seen!={80{1'b1}} || painted<10000)$fatal(1,"coverage");
  $display("PASS waveform pixels: %d comparisons; 80 columns; zero/low/mid/max/overflow/history/disabled; text safe; two-clock timing",checks);$finish;
 end
 initial begin #30000000;$fatal(1,"timeout");end
endmodule
