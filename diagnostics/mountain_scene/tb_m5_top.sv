`timescale 1ns/1ps
// Inject only scan-result metadata and the physical SD sector bytes. The
// production loader, sector service, BRAM write wiring, CDC and HDMI input run.
module tb_m5_top;
 reg clk=0,pix=0,rst=1;always #5 clk=~clk;always #20 pix=~pix;
 reg hs=1,vs=1,de=0;reg [9:0] x=0;reg [1:0] stage=0,speed=0;reg warn=0;
 reg [7:0] fm[0:4095],tm[0:4095];integer fbytes,tbytes;
 reg rv=0,re=0;reg [7:0] rb=0;integer sector=0,pos=0,requests=0;bit serving=0;
 top dut(.clk(clk),.rst_n(!rst),.key1(1'b1),.key2(1'b1),.key4(1'b1),.sw1(1'b0),.sw2(1'b0),.sd_miso(1'b1),.uart_rx(1'b1));
 always @(negedge clk)begin
  rv=0;re=0;
  if(rst)serving=0;
  else if(!serving && dut.sd_card_bmp_m0.sd_sec_read)begin sector=dut.sd_card_bmp_m0.sd_sec_read_addr;pos=0;serving=1;requests++;end
  else if(serving)begin
   if(pos<512)begin
    rv=1;
    if(sector==1)rb=8'(((pos/4+1)>>((pos%4)*8))&255);
    else if(sector>=100 && sector<108)rb=fm[(sector-100)*512+pos];
    else if(sector>=118 && sector<126)rb=tm[(sector-118)*512+pos];
    else $fatal(1,"unexpected LBA %d",sector);
    pos++;
   end else begin re=1;serving=0;end
  end
 end
 reg [36:0] pipe[0:2];integer checks=0,white=0;
 always @(posedge pix)if(!rst)begin
  pipe[2]=pipe[1];pipe[1]=pipe[0];pipe[0]={dut.ring_hs,dut.ring_vs,dut.ring_de,dut.ring_x,dut.band_rgb};
  #1;
  if(checks>3 && {dut.final_hs,dut.final_vs,dut.final_de,dut.final_x}!==pipe[2][36:24])$fatal(1,"final HDMI timing bundle");
  checks++;
  if(dut.final_de && dut.g_scene_text.overlay.y==70 && dut.final_rgb==24'hffffff)white++;
 end
 task frame;
  begin
   @(negedge pix);vs=0;de=0;repeat(20)@(negedge pix);vs=1;
   for(integer yy=0;yy<105;yy++)begin
    for(integer xx=0;xx<650;xx++)begin @(negedge pix);de=xx<640;x=xx;end
    @(negedge pix);de=0;
   end
   repeat(20)@(negedge pix);
  end
 endtask
 initial begin
  $readmemh("font.hex",fm);$readmemh("text.hex",tm);
  if(!$value$plusargs("F_BYTES=%d",fbytes) || !$value$plusargs("T_BYTES=%d",tbytes))$fatal(1,"sizes");
  force dut.video_clk=pix;force dut.sd_card_clk=clk;
  force dut.rst_video=rst;force dut.rst_sd=rst;force dut.rst_panel=rst;
  force dut.hs=hs;force dut.vs=vs;force dut.de=de;force dut.video_x=x;
  force dut.vout_rgba_raw={24'h123456,8'hff};force dut.display_valid=1;
  force dut.pixel_descriptor=0;force dut.transition_level=16;force dut.transition_wipe=0;
  force dut.scenario_state_src={1'b1,2'd0,stage,8'd0};
  force dut.scenario_meta_src={1'b1,warn,speed,1'b0};force dut.audio_image=stage;
  force dut.sd_card_bmp_m0.scan_request=0;force dut.sd_card_bmp_m0.scan_result_ready=0;
  force dut.sd_card_bmp_m0.font_found=1;force dut.sd_card_bmp_m0.text_found=1;
  force dut.sd_card_bmp_m0.font_cluster=2;force dut.sd_card_bmp_m0.text_cluster=20;
  force dut.sd_card_bmp_m0.font_size=fbytes;force dut.sd_card_bmp_m0.text_size=tbytes;
  force dut.sd_card_bmp_m0.audio_spc=1;force dut.sd_card_bmp_m0.audio_fat_lba=1;
  force dut.sd_card_bmp_m0.audio_data_lba=100;force dut.sd_card_bmp_m0.audio_max_cluster=100;
  force dut.sd_card_bmp_m0.sd_sec_read_data=rb;force dut.sd_card_bmp_m0.sd_sec_read_data_valid=rv;
  force dut.sd_card_bmp_m0.sd_sec_read_end=re;force dut.sd_card_bmp_m0.sd_sec_read_failed=0;
  repeat(10)@(negedge clk);rst=0;
  force dut.sd_card_bmp_m0.scan_state=3;force dut.sd_card_bmp_m0.scan_done=1;
  @(negedge clk);release dut.sd_card_bmp_m0.scan_state;
  repeat(2)@(negedge clk);release dut.sd_card_bmp_m0.scan_done;
  wait(dut.sd_card_bmp_m0.scan_result_valid);
  if(!dut.font_valid_src || !dut.text_valid_src || requests<2 || dut.sd_card_bmp_m0.audio_session)$fatal(1,"resource/audio ordering");
  frame();frame();
  if(!dut.scene_text_active || !dut.font_available || white==0)$fatal(1,"top loaded font not visible");
  for(integer s=0;s<4;s++)begin
   stage=s;speed=s%3;warn=s==3;frame();frame();
   if(dut.scene_stage!=stage || dut.scene_meta_pixel[15:14]!=speed || dut.scene_meta_pixel[16]!=warn ||
      dut.scene_panel[3:0]!={1'b1,warn,stage})$fatal(1,"top state/speed/panel CDC");
  end
  $display("PASS M5 production top: SD sector service -> loader -> BRAM -> resource CDC -> visible text, %0d final HDMI bundle checks, %0d sector requests, four stages/speeds/warning/panel",checks,requests);$finish;
 end
 initial begin #100000000;$fatal(1,"top watchdog");end
endmodule
