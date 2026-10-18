`timescale 1ns/1ps
// Production top: menu bypass, all final RGB and timing signals. Card and memory
// are held reset here; their real transactions are exercised by other suites.
module tb_selector_pixels;
 parameter CASE_ID=0;
 // The video pipeline runs from pix. Other domains stay reset/unclocked;
 // avoid spending millions of events in an unused PLL/HDMI serializer.
 reg clk=0,pix=0,rst=1;always #20 pix=~pix;
 reg hs=1,vs=1,de=0;reg [9:0] x=0;reg [8:0] y=0;
 reg [31:0] rgba=0,desc=0;
 top dut(.clk(clk),.rst_n(!rst),.key1(1'b1),.key2(1'b1),.key4(1'b1),
  .sw1(1'b0),.sw2(1'b0),.sw3(1'b0),.sd_miso(1'b1),.uart_rx(1'b1));
 initial begin
  force dut.video_clk=pix;force dut.sd_card_clk=clk;
  force dut.rst_video=rst;force dut.rst_sd=1;force dut.rst_mem=1;force dut.rst_panel=1;
  force dut.hs=hs;force dut.vs=vs;force dut.de=de;force dut.video_x=x;force dut.ring_y=y;
  force dut.vout_rgba_raw=rgba;force dut.pixel_descriptor=desc;
  force dut.display_valid=0;force dut.pixel_identity=6'd2;force dut.pixel_kind=8'h41;
  force dut.scene_enable=1;force dut.scene_stage=3;force dut.scene_time=200;
  force dut.scene_fast=1;force dut.scene_slow=1;
  force dut.brightness_frame=8'd64;force dut.contrast_frame=8'd192;
 end
 reg [23:0] reference[0:1535999];
 reg [23:0] expected[0:18];reg [12:0] timing[0:18];reg checking[0:18];
 integer frame=0,checked=0,i,tile,fd;
 always @(posedge pix)begin
  for(i=18;i>0;i--)begin expected[i]=expected[i-1];timing[i]=timing[i-1];checking[i]=checking[i-1];end
  expected[0]=de?reference[frame*307200+y*640+x]:24'd0;
  timing[0]={hs,vs,de,x};checking[0]=!rst;
  #1;
  if(checking[18])begin
   if({dut.final_hs,dut.final_vs,dut.final_de,dut.final_x}!==timing[18])$fatal(1,"menu final timing");
   if(dut.final_rgb!==expected[18])$fatal(1,"menu RGB frame=%d n=%d got=%h expected=%h",frame,checked,dut.final_rgb,expected[18]);
   if(dut.final_de)begin
    if(checked<307200)$fwrite(fd,"%c%c%c",dut.final_rgb[23:16],dut.final_rgb[15:8],dut.final_rgb[7:0]);
    checked++;
   end
  end
 end
 integer f,xx,yy;
 initial begin
  $readmemh("menu_reference.hex",reference);
  for(i=0;i<=18;i++)checking[i]=0;
  fd=$fopen("menu_actual.ppm","wb");$fwrite(fd,"P6\n640 480\n255\n");
  repeat(10)@(negedge pix);rst=0;
  for(f=0;f<5;f++)begin
   frame=f;desc=(32'd1<<24)|((f%4)<<22)|((f<4?15:9)<<18);vs=0;
   repeat(30)@(negedge pix);vs=1;
   for(yy=0;yy<480;yy++)begin
    y=yy;de=1;
    for(xx=0;xx<640;xx++)begin
     x=xx;tile=(yy/240)*2+xx/320;rgba={8'(40+tile*48),8'(yy%240),8'(xx%320),8'(xx%239)};
     @(negedge pix);
    end
    de=0;hs=0;repeat(40)@(negedge pix);hs=1;repeat(120)@(negedge pix);
   end
   repeat(30)@(negedge pix);
  end
  $fclose(fd);
  if(checked!=1536000)$fatal(1,"pixel count %d",checked);
  $display("PASS selector pixels %d: all focus/gray/glyph/raw color/full top RGB/18-clock timing",checked);$finish;
 end
 initial begin #100000000;$fatal(1,"pixels watchdog");end
endmodule
