`timescale 1ns/1ps
module tb_ring_pixels;
 reg clk=0,rst=1,hs=1,vs=1,de=0,en=1;
 always #5 clk=~clk;
 reg [9:0] x=0;reg [8:0] y=0;
 reg [23:0] rgb=0;
 reg [4:0] strength=0;
 wire [6:0] bar;
 wire [4:0] height= strength==31 ? bar%29 : strength;
 wire ho,vo,dout;wire [9:0] xo;wire [23:0] out,bypass;
 audio_ring_overlay dut(clk,rst,hs,vs,de,en,x,y,rgb,height,bar,ho,vo,dout,xo,out);
 audio_ring_overlay #(.ENABLE(0)) disabled(clk,rst,hs,vs,de,en,x,y,rgb,height, , , , , ,bypass);
 reg oldhs=1,oldvs=1,oldde=0;reg [9:0] oldx=0;reg [23:0] oldrgb=0;
 integer file,mode,px,py;
 always @(posedge clk)begin
  #1;
  if(!rst)begin
   if({ho,vo,dout,xo,bypass}!=={oldhs,oldvs,oldde,oldx,oldrgb})$fatal(1,"two-cycle alignment x=%0d",x);
   if(dout && file) $fdisplay(file,"%06x",out);
  end
  oldhs=hs;oldvs=vs;oldde=de;oldx=x;oldrgb=rgb;
 end
 initial begin
  file=0;repeat(3)@(negedge clk);rst=0;
  for(mode=0;mode<4;mode=mode+1)begin
   strength=mode==0?0:mode==1?7:mode==2?28:31;
   file=$fopen($sformatf("ring_%0d.hex",mode),"w");
   for(py=0;py<480;py=py+1)begin
    for(px=0;px<640;px=px+1)begin
     @(negedge clk);de=1;x=px;y=py;rgb={px[7:0],py[7:0],8'h60};
    end
    @(negedge clk);de=0;hs=0;
    repeat(3)@(negedge clk);hs=1;
   end
   @(negedge clk);vs=0;repeat(4)@(negedge clk);vs=1;
   $fclose(file);file=0;
  end
  $display("PASS pixels: full frames, two-cycle RGB/HS/VS/DE/X alignment, disabled bypass");$finish;
 end
 initial begin #20000000;$fatal(1,"timeout");end
endmodule
