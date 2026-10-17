`timescale 1ns/1ps
// Production top wiring test. Inject decoded pixels/audio at the existing
// reader/source boundaries; storage and physical IO are covered separately.
module tb_scenario_top;
 reg clk=0,pix=0,rst=1;always #5 clk=~clk;always #20 pix=~pix;
 reg hs=1,vs=1,de=0;reg [9:0] x=0;reg [23:0] input_rgb=24'h4080c0;
 reg [7:0] b=128,c=128;reg [3:0] volume=10;reg [1:0] mode=0,selection=0;
 reg [4:0] fade=16;reg wipe=0,valid_picture=1;reg [17:0] descriptor=0;
 reg wav_active=1;reg signed [15:0] wav_left=12000,wav_right=-16000;
 wire [5:0] seg_sel;wire [7:0] seg_data;
 top dut(.clk(clk),.rst_n(!rst),.key1(1'b1),.key2(1'b1),.key4(1'b1),.sw1(1'b0),.sw2(1'b0),
 .sd_miso(1'b1),.uart_rx(1'b1),.seg_sel(seg_sel),.seg_data(seg_data));
 reg [12:0] scene_bundle=0;
 reg [7:0] input_t=255;reg [1:0] image_id=0;reg [23:0] scene_rgb;
 function [23:0] hazard(input [23:0] p,input integer a,s,tm,bf,bs,en,thumb);
  reg [23:0] color,fc,result;integer k,z;
  begin
   case(s)
    1:begin color=24'h603010;fc=24'hffe000;end
    2:begin color=24'h0060e0;fc=24'hffffff;end
    3:begin color=24'h00c040;fc=24'h00ff00;end
    default:begin color=0;fc=0;end
   endcase
   result=p;
   if(en && !thumb)begin
    if(s!=0 && a<240 && a<=tm)begin
     if(tm-a<6 && bf)result=fc;
     else begin
      k=(s==2 && tm-a>=6)?1:3;
      for(z=0;z<3;z++)result[z*8+:8]=(p[z*8+:8]+k*color[z*8+:8])/(k+1);
     end
    end else if(a==250 && bs)result=24'h00ff00;
   end
   hazard=result;
  end
 endfunction
 localparam ADJUST_DELAY=14;
 reg [23:0] expected[0:ADJUST_DELAY-1];reg [9:0] xs[0:ADJUST_DELAY-1];reg [2:0] syncs[0:ADJUST_DELAY-1];
 integer count=0,checks=0,audio_checks=0;integer t,v;
 function [7:0] channel(input integer p,input integer bv,input integer cv);
  integer a,z;begin a=(p*bv)>>7;if(a>255)a=255;z=(((a-128)*cv)>>>7)+128;channel=z<0?0:z>255?255:z;end
 endfunction
 always @(posedge pix)if(!rst)begin
  for(integer i=ADJUST_DELAY-1;i>0;i--)begin expected[i]=expected[i-1];xs[i]=xs[i-1];syncs[i]=syncs[i-1];end
  scene_rgb=hazard(input_rgb,input_t,dut.scene_stage,dut.scene_time,dut.scene_fast,dut.scene_slow,dut.scene_enable && de,descriptor[17]);
  expected[0]=valid_picture && de?{channel(scene_rgb[23:16],dut.brightness_frame,dut.contrast_frame),
   channel(scene_rgb[15:8],dut.brightness_frame,dut.contrast_frame),channel(scene_rgb[7:0],dut.brightness_frame,dut.contrast_frame)}:0;
  xs[0]=x;syncs[0]={hs,vs,de};count++;
  #1;
  if(count>=ADJUST_DELAY)begin
   if(dut.adjusted_rgb!==expected[ADJUST_DELAY-1] || dut.adjust_x!==xs[ADJUST_DELAY-1] || {dut.adjust_hs,dut.adjust_vs,dut.adjust_de}!==syncs[ADJUST_DELAY-1])$fatal(1,"top pixel/timing alignment");
   if(dut.adjust_preview && dut.adjust_de)begin
    if(dut.thumb_border && dut.preview_rgb!==24'hffff00)$fatal(1,"adjusted focus border");
    if(!dut.thumb_border && !dut.thumb_valid && dut.preview_rgb!==0)$fatal(1,"empty preview");
   end
   checks++;
  end
 end
 reg signed [15:0] audio_l[$],audio_r[$];reg signed [15:0] expected_l,expected_r;
 always @(posedge pix)if(!rst && volume==10)begin
  if(dut.volume_valid && dut.volume_ready)begin
   if(audio_l.size()==0)$fatal(1,"extra top sample");expected_l=audio_l.pop_front();expected_r=audio_r.pop_front();
   if(dut.volume_left!==expected_l || dut.volume_right!==expected_r)$fatal(1,"top unity audio routing");
   audio_checks++;
  end
  if(dut.mixed_valid && dut.mixed_ready)begin audio_l.push_back(dut.mixed_left);audio_r.push_back(dut.mixed_right);end
 end
 task frame(input integer lines);
  begin
   @(negedge pix);vs=0;de=0;repeat(12)@(negedge pix);vs=1;
   for(integer y=0;y<lines;y++)begin
    for(integer px=0;px<800;px++)begin
     @(negedge pix);de=px<640;x=px;hs=!(px>=656 && px<752);input_rgb={8'(px),8'(y*7),8'(255-px)};
    end
   end
   repeat(20)@(negedge pix);
  end
 endtask
 initial begin
  force dut.video_clk=pix;force dut.sd_card_clk=clk;force dut.rst_video=rst;force dut.rst_sd=rst;
  force dut.hs=hs;force dut.vs=vs;force dut.de=de;force dut.video_x=x;force dut.vout_rgba_raw={input_rgb,input_t};
  force dut.display_valid=valid_picture;force dut.pixel_descriptor=descriptor;force dut.transition_level=fade;force dut.transition_wipe=wipe;
  force dut.scenario_state_src=scene_bundle;force dut.scenario_fade_src=1'b0;
  force dut.audio_enable=1'b1;force dut.audio_image=image_id;
  force dut.brightness_src=b;force dut.contrast_src=c;force dut.volume_src=volume;force dut.selected_src=selection;force dut.switch_mode=mode;
  force dut.bgm_active=wav_active;force dut.bgm_valid=1'b1;force dut.bgm_left=wav_left;force dut.bgm_right=wav_right;
  force dut.pcm_valid=1'b1;force dut.pcm_left=16'sd3000;force dut.pcm_right=-16'sd4000;
  repeat(10)@(negedge pix);rst=0;
  frame(60);
  for(integer s=0;s<4;s++)begin
   image_id=2'(s);scene_bundle={1'b1,2'(s),2'(s),8'd239};
   for(integer f=0;f<8;f++)begin input_t=f==0?250:f==1?255:f==2?240:8'(f-3);frame(3);end
  end
  image_id=3;input_t=250;
  b=192;c=224;mode=1;repeat(20)@(negedge pix);frame(60);
  fade=0;repeat(8)@(negedge pix);if(dut.transition_rgb!==0)$fatal(1,"fade black");
  fade=16;wipe=1;x=500;fade=8;de=1;repeat(8)@(negedge pix);if(dut.transition_rgb!==0)$fatal(1,"wipe black");
  de=0;wipe=0;fade=16;descriptor={1'b1,2'd0,3'd4,4'b1111,8'd0};mode=3;frame(60);
  descriptor=0;input_t=255;valid_picture=0;c=0;repeat(20)@(negedge pix);frame(60);
  valid_picture=1;b=128;c=128;wav_active=0;frame(60);
  volume=0;repeat(20)@(negedge pix);frame(120);
  if(dut.u_master_volume.gain!==0 || dut.volume_left!==0 || dut.volume_right!==0)$fatal(1,"top mute gain=%0d accepted=%0d",dut.u_master_volume.gain,audio_checks);
  if(checks<100000 || audio_checks==0)$fatal(1,"missing observations");
  $display("PASS M4 production top injected pixels=%0d audio=%0d default/adjust/preview/black/mute",checks,audio_checks);$finish;
 end
 initial begin #100000000;$fatal(1,"M3 top watchdog");end
endmodule
