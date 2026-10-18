`timescale 1ns/1ps
// Real production video pipeline, paired against AUDIO_VIS_ENABLE=0.
// SD/memory are held reset; PCM and assets have separate direct tests.
module tb_wave_top;
 reg clk=0,pix=0,rst=1; always #20 pix=~pix;
 reg hs=1,vs=1,de=0,valid=1,audio=1;
 reg [9:0] x=0; reg [8:0] y=0; reg [5:0] identity=1;
 reg [31:0] rgba=32'h45678900,desc=0;
 top #(.OSD_ENABLE(0)) dut(.clk(clk),.rst_n(!rst),.key1(1'b1),.key2(1'b1),.key4(1'b1),
 .sw1(1'b0),.sw2(1'b0),.sw3(1'b0),.sd_miso(1'b1),.uart_rx(1'b1));
 top #(.OSD_ENABLE(0),.AUDIO_VIS_ENABLE(0)) ref_dut(.clk(clk),.rst_n(!rst),.key1(1'b1),.key2(1'b1),.key4(1'b1),
 .sw1(1'b0),.sw2(1'b0),.sw3(1'b0),.sd_miso(1'b1),.uart_rx(1'b1));
 `define DRIVE(D) \
 force D.video_clk=pix; force D.sd_card_clk=clk; \
 force D.rst_video=rst; force D.rst_sd=1; force D.rst_mem=1; force D.rst_panel=1; \
 force D.hs=hs; force D.vs=vs; force D.de=de; force D.video_x=x; force D.ring_y=y; \
 force D.vout_rgba_raw=rgba; force D.pixel_descriptor=desc; \
 force D.display_valid=valid; force D.audio_enable=audio; force D.pixel_identity=identity; \
 force D.scene_enable=0; force D.brightness_frame=128; force D.contrast_frame=128; \
 force D.transition_level=16; force D.transition_wipe=0;
 initial begin
  `DRIVE(dut)
  `DRIVE(ref_dut)
  force dut.ring_bar_height=28;
 end
 reg paint[0:18],check[0:18]; reg [12:0] timing[0:18];
 integer i,checked=0,painted=0,case_id=0;
 always @(posedge pix)begin
  for(i=18;i>0;i--)begin paint[i]=paint[i-1];check[i]=check[i-1];timing[i]=timing[i-1];end
  paint[0]=de && valid && audio && identity==1 && !desc[17] && !desc[24] && y>=452 && y<480 && x<640 && x%8>=2 && x%8<5;
  timing[0]={hs,vs,de,x};check[0]=!rst;
  #1;
  if(check[18])begin
   if({dut.final_hs,dut.final_vs,dut.final_de,dut.final_x}!==timing[18])$fatal(1,"top latency case %d",case_id);
   if(dut.final_rgb !== (paint[18]?24'hb45ac8:ref_dut.final_rgb))
    $fatal(1,"top pixel case=%d x=%d got=%h ref=%h paint=%b",case_id,dut.final_x,dut.final_rgb,ref_dut.final_rgb,paint[18]);
   if(dut.final_de)begin checked++;if(paint[18])painted++;end
  end
 end
 integer f,xx,yy;
 initial begin
  for(i=0;i<=18;i++)check[i]=0;
  repeat(10)@(negedge pix);rst=0;
  for(f=0;f<8;f++)begin
   case_id=f;identity=1;audio=1;valid=1;desc=0;
   case(f)
    1:identity=2; 2:identity=0; 3:desc=32'd1<<17;
    4:desc=(32'd1<<24)|(15<<18); 5:valid=0; 6:audio=0; 7:identity=3;
   endcase
   vs=0;repeat(30)@(negedge pix);vs=1;
   for(yy=0;yy<480;yy++)begin
    y=yy;de=1;
    for(xx=0;xx<640;xx++)begin x=xx;rgba={8'(40+f),8'(yy),8'(xx),8'd0};@(negedge pix);end
    de=0;hs=0;repeat(4)@(negedge pix);hs=1;repeat(26)@(negedge pix);
   end
   repeat(30)@(negedge pix);
  end
  if(checked!=2457600 || painted!=6720)$fatal(1,"counts checked=%d painted=%d",checked,painted);
  $display("PASS wave top: 2457600 pixels; publicity/scene/legacy/preview/menu/invalid/no-audio/other; full width 80 bars; final RGB and 18-clock timing");$finish;
 end
 initial begin #200000000;$fatal(1,"top watchdog");end
endmodule
