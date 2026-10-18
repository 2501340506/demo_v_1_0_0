`timescale 1ns/1ps
// Production 18-clock path with real byte-written TEXT BRAM and glyph ROM.
// SD/SDRAM are isolated, so this is not a physical-card/board test.
module tb_narration_top;
 reg clk=0,pix=0,rst=1;always #20 pix=~pix;
 reg hs=1,vs=1,de=0,valid=1,audio=1,wen=0;
 reg [9:0] x=0;reg [8:0] y=0;reg [5:0] identity=1;
 reg [1:0] page=0;reg [31:0] desc=0;reg [11:0] wa;reg [7:0] wd;
 reg [15:0] words[0:620];reg [20:0] font[0:5795];
 top dut(.clk(clk),.rst_n(!rst),.key1(1'b1),.key2(1'b1),.key4(1'b1),
 .sw1(1'b0),.sw2(1'b0),.sw3(1'b0),.sd_miso(1'b1),.uart_rx(1'b1));
 top #(.OSD_ENABLE(0)) ref_dut(.clk(clk),.rst_n(!rst),.key1(1'b1),.key2(1'b1),.key4(1'b1),
 .sw1(1'b0),.sw2(1'b0),.sw3(1'b0),.sd_miso(1'b1),.uart_rx(1'b1));
 `define DRIVE(D) \
 force D.video_clk=pix;force D.sd_card_clk=pix; \
 force D.rst_video=rst;force D.rst_sd=1;force D.rst_mem=1;force D.rst_panel=1; \
 force D.hs=hs;force D.vs=vs;force D.de=de;force D.video_x=x;force D.ring_y=y; \
 force D.vout_rgba_raw=32'h45678900;force D.pixel_descriptor=desc; \
 force D.display_valid=valid;force D.audio_enable=audio;force D.pixel_identity=identity; \
 force D.audio_image=page;force D.audio_update=0;force D.scene_enable=0; \
 force D.brightness_frame=128;force D.contrast_frame=128; \
 force D.transition_level=16;force D.transition_wipe=0;force D.ring_bar_height=28; \
 force D.bin_wr_en=wen;force D.bin_wr_text=1;force D.bin_wr_addr=wa;force D.bin_wr_data=wd; \
 force D.resources_pixel=24'h2004da;force D.app_status_pixel=24'h002000;
 integer phase=0;
 initial begin
  `DRIVE(dut)
  `DRIVE(ref_dut)
  force dut.g_scene_text.g_narration.overlay.phase=phase;
 end
 reg caption[0:18],hit[0:18],check[0:18];reg [12:0] timing[0:18];
 integer i,tx,code,checked=0,captioned=0,ink=0,case_id=0;
 always @(posedge pix)begin
  for(i=18;i>0;i--)begin caption[i]=caption[i-1];hit[i]=hit[i-1];check[i]=check[i-1];timing[i]=timing[i-1];end
  caption[0]=de && identity==1 && !desc[17] && !desc[24] && y>=420 && y<444;
  tx=x+phase/256-632;hit[0]=0;
  if(caption[0] && y>=422 && y<443 && x>=8 && x<632 && tx>=0 && tx<words[3+page*5]*21)begin
   code=words[words[2+page*5]/2+tx/21];hit[0]=(font[code*21+y-422] & (21'h100000>>(tx%21)))!=0;
  end
  check[0]=!rst && de && y>=400;timing[0]={hs,vs,de,x};
  #1;
  if(check[18])begin
   if({dut.final_hs,dut.final_vs,dut.final_de,dut.final_x}!==timing[18])$fatal(1,"top caption latency case=%d",case_id);
   if(dut.final_rgb!==(hit[18]?24'h000000:ref_dut.final_rgb))
    $fatal(1,"top caption case=%d x=%d got=%h ref=%h band=%b hit=%b",case_id,dut.final_x,dut.final_rgb,ref_dut.final_rgb,caption[18],hit[18]);
   checked++;if(caption[18])captioned++;if(hit[18])ink++;
  end
 end
 initial begin
  $readmemh("text_words.hex",words);$readmemh("font_rows.hex",font);
  for(i=0;i<=18;i++)check[i]=0;
  repeat(10)@(negedge pix);
  for(integer b=0;b<1242;b++)begin wa=b;wd=b%2?words[b/2][15:8]:words[b/2][7:0];wen=1;@(negedge pix);end
  wen=0;rst=0;repeat(2500)@(negedge pix);
  for(integer f=0;f<8;f++)begin
   case_id=f;identity=1;desc=0;page=f%4;phase=(624+f*21)*256;
   case(f)
    4:identity=2;5:identity=0;6:desc=32'd1<<17;7:desc=(32'd1<<24)|(15<<18);
   endcase
   vs=0;repeat(2500)@(negedge pix);vs=1;
   for(integer yy=0;yy<480;yy++)begin
    y=yy;de=1;
    for(integer xx=0;xx<640;xx++)begin x=xx;@(negedge pix);end
    de=0;hs=0;repeat(4)@(negedge pix);hs=1;repeat(26)@(negedge pix);
   end
   repeat(30)@(negedge pix);
  end
  if(checked!=409600 || captioned!=61440 || ink<1000)$fatal(1,"top coverage counts %d %d %d",checked,captioned,ink);
  $display("PASS narration top: 409600 final pixels, black Song 21px/transparent background/no band, four PS1 pages/real TEXT BRAM/ROM, scene/legacy/preview/menu bypass, wave unchanged and 18-clock timing");$finish;
 end
 initial begin #200000000;$fatal(1,"top caption watchdog");end
endmodule
