 `define D top_dut.sd_card_bmp_m0
 `define P top_dut.sd_card_bmp_m0.g_audio.u_player
 `define H top_dut.u_media_hdmi_audio_bridge.u_symbol_core
 function [15:0] voice_value(input integer p,input integer n);
  voice_value=16'h9100+p*400+n*14;
 endfunction
 integer i,j,at,b0,d0,sessions=0,source_samples=0,expected_n=0,packet_samples=0;
 reg [15:0] last_id=0;reg signed [15:0] expected_source;
 reg [15:0] ql[0:65535],qr[0:65535];integer qw=0,rp=0,k;
 reg [15:0] vl[0:65535],vr[0:65535];integer vw=0,vp=0;
 reg signed [33:0] prod_l,prod_r;
 integer emitted_tail[0:3];integer current_voice_page=-1;
 reg [1:0] previous_page=0;integer auto_pages=0;
 always @(posedge pix)if(!rst)begin
  if(top_dut.mixed_valid && top_dut.mixed_ready)begin
   prod_l=$signed(top_dut.mixed_left)*$signed({1'b0,top_dut.u_master_volume.next_gain});
   prod_r=$signed(top_dut.mixed_right)*$signed({1'b0,top_dut.u_master_volume.next_gain});
   vl[vw%65536]=prod_l>>>16;vr[vw%65536]=prod_r>>>16;vw++;
  end
  if(top_dut.volume_valid && top_dut.volume_ready)begin
   if(vp>=vw || top_dut.volume_left!==vl[vp%65536] || top_dut.volume_right!==vr[vp%65536])$fatal(1,"M4 master output sample %0d",vp);
   vp++;
  end
  if(`D.bgm_valid && `D.bgm_ready && `P.single_latched && `P.source_tag[`P.rp])begin
   if(`D.scan_application!=1)$fatal(1,"old VOI started in target resource set %d",`D.scan_application);
   if(last_id!=`P.identity_latched)begin last_id=`P.identity_latched;expected_n=0;sessions++;$display("M4 VOI session=%h number=%0d page=%0d",last_id,sessions,last_id[9:8]);end
   expected_source=$signed(voice_value(last_id[9:8],expected_n))>>>1;
   if(`D.bgm_left!==expected_source || `D.bgm_right!==expected_source || expected_n>=256)$fatal(1,"M4 top source id=%h n=%d",last_id,expected_n);
   expected_n++;source_samples++;
   if(expected_n==256)emitted_tail[last_id[9:8]]=qw+2;
  end
  if(top_dut.ring_tap_valid)begin
   ql[qw%65536]=top_dut.ring_tap_left;qr[qw%65536]=top_dut.ring_tap_right;qw++;
  end
  // At the LAST transmitted data-island character, compare all four stereo
  // samples in that packet against accepted PCM; do not mistake tap for wire.
  if(`H.mode==3 && `H.packet_pixel_index==31 && `H.active_header[7:0]==2)begin
   for(k=0;k<4;k++)begin
    if(rp>=qw || `H.active_body[k*56+8+:16]!==ql[rp%65536] || `H.active_body[k*56+32+:16]!==qr[rp%65536])$fatal(1,"M4 HDMI payload sample %d",rp);
    rp++;packet_samples++;
   end
  end
 end
 // AUTO is accepted in the SD control clock. Sampling this one-cycle event
 // on pix can miss it because the two clocks are asynchronous.
 always @(posedge clk)if(!rst)begin
  if(`D.public_offer && !`D.scene_request && !`D.preview_offer &&
     (`D.image_count!=4 || `D.cache_target!==(`D.img_idx+2'd1)))
   $fatal(1,"publicity AUTO target changed count=%d target=%d current=%d",`D.image_count,`D.cache_target,`D.img_idx);
  if(`D.public_accept)begin
   if(expected_n!=256 || rp<emitted_tail[`D.img_idx])$fatal(1,"AUTO cut HDMI tail page=%d sent=%d tail=%d",`D.img_idx,rp,emitted_tail[`D.img_idx]);
   auto_pages++;
   $display("M4 AUTO accepted page=%0d number=%0d",`D.img_idx,auto_pages);
  end
 end
 task voice_finished;
 begin wait(`D.public_voice_status==3);wait(rp>=emitted_tail[`D.img_idx]);cycles(100);
 if(expected_n!=256 || `D.g_audio.u_stream.loop_count!=0)$fatal(1,"M4 top voice incomplete/looped");end endtask
 initial begin
  for(i=0;i<4;i++)begin bank_good[i]=0;bank_count[i]=0;bank_id[i]=0;emitted_tail[i]=0;end
  setup();
  for(i=0;i<4;i++)begin
   entry(1792+i*32,{"VOI",8'("1"+i),"    PCM"},20+i,512);
   for(j=0;j<256;j++)begin at=(20+i)*512+j*2;disk[at]=voice_value(i,j);disk[at+1]=voice_value(i,j)>>8;end
  end
  cycles(10);rst=0;settled(1);voice_finished();wait(`D.cache_valid==15);b0=boots;d0=dirs;
  next_page();page(1);voice_finished();next_page();page(2);voice_finished();next_page();page(3);voice_finished();
  short4();wait(`D.img_idx==0);page(0);voice_finished();short4();
  toggle_app();settled(2);prev_page();wait(`D.g_scenario.warn_mode);wait(!`D.scene_fade);
  toggle_app();settled(1);page(0);voice_finished();
  if(boots!=b0 || dirs!=d0 || sessions<6 || auto_pages!=1 || source_samples!=sessions*256 || packet_samples<source_samples)$fatal(1,"M4 top coverage boots=%0d/%0d dirs=%0d/%0d sessions=%0d auto=%0d source=%0d packet=%0d",boots,b0,dirs,d0,sessions,auto_pages,source_samples,packet_samples);
  $display("PASS M4 production top: %0d exact VOI source samples / %0d sessions, %0d scaled PCM and %0d HDMI payload samples; four pages, AUTO after transmitted tail, scene warning and return; real 307200-pixel scaler",source_samples,sessions,vp,packet_samples);$finish;
 end
 always @(negedge clk)if(source_done)$display("M4 top full source t=%0t page=%d app=%d pixels=%0d",$time,`D.load_idx,app,pixels);
 initial begin #(64'd3000000000);$fatal(1,"M4 top watchdog app=%d busy=%b voice=%d sessions=%d",app,busy,`D.public_voice_status,sessions);end
 initial forever begin #10000000;
  $display("M4 top progress t=%0t app=%0d busy=%0b voice=%0d sessions=%0d source=%0d auto=%0d",$time,app,busy,`D.public_voice_status,sessions,source_samples,auto_pages);
 end
endmodule
