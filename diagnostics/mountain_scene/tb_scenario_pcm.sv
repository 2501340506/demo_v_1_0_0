`timescale 1ns/1ps
module tb_scenario_pcm #(parameter PREVIEW_TEST=0);
 reg clk=0,pix=0,rst=1;
 always #5 clk=~clk;
 always #20 pix=~pix;
 reg key4=1,key1=1,key2=1;
 wire muted,scene_fade;wire [12:0] scene_state;
 wire req,cancel,done,commit,bvalid,bactive,bready;
 reg frame_tick=0,commit_ack=0,commit_old=0;integer frame_count=0;
 wire commit_pulse=commit_ack!=commit_old;
 always @(posedge pix)begin
  if(rst)begin frame_tick<=0;frame_count<=0;commit_ack<=0;commit_old<=0;end
  else begin
   frame_tick<=frame_count==399;frame_count<=frame_count==399?0:frame_count+1;
   commit_ack<=commit;commit_old<=commit_ack;
  end
 end
 reg [1:0] app_mode=0;
 reg preview_ack=0,hold_preview_ack=0;
 wire preview_request;
 wire [17:0] preview_descriptor;
 always @(posedge pix)if(rst)preview_ack<=0;
 else if(!hold_preview_ack)preview_ack<=preview_request;
 wire signed [15:0] bl,br;
 reg finish=0;
 wire [1:0] image;
 wire image_valid,display_valid;
 sd_card_bmp #(.CLK_FREQ_HZ(1000),.LOAD_TIMEOUT_MS(5000),.AUDIO_ENABLE(1),.PREVIEW_ENABLE(1),.SCENE_ENABLE(1),.TRANSITION_ENABLE(1)) app(
 .scenario_muted(muted),.scenario_fade(scene_fade),.scenario_state(scene_state),
 .clk(clk),.rst(rst),.sdram_ready(1'b1),.key1(key1),.key2(key2),.key4(key4),.mode(app_mode),
 .preview_ack(preview_ack),.preview_request(preview_request),.preview_descriptor(preview_descriptor),
 .adjust_select(),.adjust_restore(),.adjust_increase(),.adjust_decrease(),
 .state_code(),.sd_debug(),.diagnostics(),.combo_event_count(),.combo_debug_active(),.auto_play_indicator(),.osd_error_code(),
 .bmp_width(16'd1),.bmp_height(16'd1),.display_valid(display_valid),.committed_image(image),.committed_valid(image_valid),.committed_ready(1'b1),
 .write_cancel_req(cancel),.write_cancel_ack(cancel),.source_frame_done(done),.source_frame_error(),
 .frame_error_toggle(1'b0),.frame_memory_error(3'd0),.reader_error(3'd0),.reader_underflow(1'b0),
 .write_finish_toggle(finish),.display_commit_ack(commit_ack),.display_commit_request(commit),
 .transition_pix_clk(pix),.transition_pix_rst(rst),.transition_frame_start(frame_tick),.transition_commit_done(commit_pulse),
 .write_buf_idx(),.disp_buf_idx(),.transition_active(),.transition_level(),.transition_wipe(),
 .write_req(req),.write_req_ack(req),.write_ready(1'b1),.write_en(),.write_data(),.SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1),
 .bgm_valid(bvalid),.bgm_active(bactive),.bgm_ready(bready),.bgm_left(bl),.bgm_right(br));
 always @(posedge clk)if(rst)finish<=0;else if(done)finish<=~finish;

 wire tone_valid,tone_ready,mix_valid,mix_ready;
 wire signed [15:0] tl,tr,ml,mr;
 pcm_media_tone tone(.clk(pix),.rst_n(!rst),.enable(display_valid),.media_id(image),.media_update(image_valid),.volume(8'd128),
 .sample_valid(tone_valid),.sample_ready(tone_ready),.sample_left(tl),.sample_right(tr),.blip_active(),.overflow());
 audio_source_mux mux(.clk(pix),.rst_n(!rst),.wav_valid(bvalid),.wav_ready(bready),.wav_left(bl),.wav_right(br),.wav_active(bactive),
 .arp_valid(tone_valid),.arp_ready(tone_ready),.arp_left(tl),.arp_right(tr),.out_valid(mix_valid),.out_ready(mix_ready),.out_left(ml),.out_right(mr));
 wire hs,vs,de;wire [9:0] x;
 video_timing_data timing(.video_clk(pix),.rst(rst),.read_req(),.read_req_ack(1'b1),.hs(hs),.vs(vs),.de(de),.video_x(x));
 wire vvalid,vready;wire signed [15:0] vl,vr;
 pcm_master_volume volume(.clk(pix),.rst(rst),.volume_level(4'd10),.fade_mute(scene_fade),.muted(muted),
  .in_valid(mix_valid),.in_ready(mix_ready),.in_left(ml),.in_right(mr),
  .out_valid(vvalid),.out_ready(vready),.out_left(vl),.out_right(vr));
 wire tap,seqerr;wire signed [15:0] tapl,tapr;
 wire [8:0] ring_y;wire ring_frame;wire [6:0] ring_index;wire [4:0] ring_height;
 wire ring_hs,ring_vs,ring_de;wire [9:0] ring_x;wire [23:0] ring_rgb;
 osd_pixel_position ring_position(pix,rst,vs,de,ring_y,ring_frame, );
 audio_ring_levels ring_levels(pix,rst,ring_frame,tap,tapl,tapr,ring_index,ring_height);
 audio_ring_overlay ring(pix,rst,hs,vs,de,display_valid,x,ring_y,24'd0,ring_height,ring_index,ring_hs,ring_vs,ring_de,ring_x,ring_rgb);
 media_hdmi_audio_bridge bridge(.pixel_clk(pix),.pixel_rst_n(!rst),.video_hsync(ring_hs),.video_vsync(ring_vs),.video_de(ring_de),.video_x(ring_x),.video_rgb(ring_rgb),
 .select_media(1'b1),.test_valid(1'b0),.test_ready(),.test_left(16'd0),.test_right(16'd0),
 .media_valid(vvalid),.media_ready(vready),.media_left(vl),.media_right(vr),
 .channel0_symbol(),.channel1_symbol(),.channel2_symbol(),.sequence_error(seqerr),.pcm_tap_valid(tap),.pcm_tap_left(tapl),.pcm_tap_right(tapr));

 reg [7:0] disk[0:8191];
 reg raw_valid=0,raw_end=0,raw_fail=0;reg [7:0] raw_byte=0;
 wire initialized=!app.sd_local_rst;
 initial begin
  force app.sd_init_done=initialized;force app.sd_init_failed=1'b0;
  force app.sd_sec_read_data=raw_byte;force app.sd_sec_read_data_valid=raw_valid;
  force app.sd_sec_read_end=raw_end;force app.sd_sec_read_failed=raw_fail;
 end
 reg inject=0;integer pos=0,saved=0,gap=0,reads=0;reg serving=0,released=1;
 always @(negedge clk)begin
  raw_valid=0;raw_end=0;raw_fail=0;
  if(rst)begin serving=0;released=1;end
  else if(serving)begin
   if(app.sd_local_rst)$fatal(1,"reset cut physical sector short");
   if(gap)gap--;
   else if(inject && saved==10 && pos==16)begin raw_fail=1;serving=0;end
   else if(pos<512)begin raw_valid=1;raw_byte=disk[saved*512+pos];pos++;gap=7;end
   else begin raw_end=1;serving=0;end
  end else begin
   if(!app.sd_sec_read)released=1;
   if(app.sd_sec_read && released)begin
    if(app.sd_sec_read_addr>15)$fatal(1,"invalid disk LBA");
    saved=app.sd_sec_read_addr;pos=0;serving=1;released=0;reads++;
   end
  end
 end
 task word32(input integer at,input reg [31:0] v);
 begin for(integer j=0;j<4;j++)disk[at+j]=v>>(8*j);end endtask
 task entry(input integer at,input reg [87:0] name,input integer cluster,input integer size);
 begin
  for(integer j=0;j<11;j++)disk[at+j]=name[(10-j)*8+:8];
  disk[at+11]=32;disk[at+26]=cluster;word32(at+28,size);
 end endtask

 task add_sounds;
 reg [15:0] value;integer lba,off;
 begin
  entry(1568,"SND1    PCM",12,1202);entry(1600,"SND2    PCM",8,2);
  entry(1632,"SND4    PCM",9,2);
  word32(560,14);word32(568,13);word32(564,32'h0fffffff);
  word32(544,32'h0fffffff);word32(548,32'h0fffffff);
  disk[4096]=8'h10;disk[4097]=8'h27; // +10000
  disk[4608]=8'hf0;disk[4609]=8'hd8; // -10000
  for(integer j=0;j<1202;j++)begin
   lba=j<512?12:(j<1024?14:13);off=j%512;value=(j/2)*20-18000;
   disk[lba*512+off]=j%2?value[15:8]:value[7:0];
  end
 end endtask
 integer received=0,total=0,sessions=0;reg was_active=0;
 reg [31:0] session_cluster=0,selected_q=0;
 reg signed [15:0] expected;
 always @(posedge pix)if(!rst)begin
  if(seqerr || tone.overflow)$fatal(1,"HDMI sequence/tone overflow");
  if(!bactive)begin received=0;was_active=0;end
  else if(!was_active)begin
   was_active=1;session_cluster=app.selected_audio_cluster;sessions++;
  end
  if(bvalid && bready)begin
   case(session_cluster)
    10:expected=-10000+(received%601)*31;
    12:expected=-9000+(received%601)*10;
    8:expected=5000;
    9:expected=-5000;
    default:$fatal(1,"unexpected audio selection %0d",session_cluster);
   endcase
   if(bl!==expected || br!==expected)$fatal(1,"PCM session=%0d cluster=%0d sample=%0d got=%0d expected=%0d",sessions,session_cluster,received,bl,expected);
   received++;total++;
  end
  if(app.g_audio.u_player.underflow_count || app.g_audio.u_player.output_overrun)$fatal(1,"under/overrun");
 end
 always @(posedge clk)if(!rst)begin
  if(app.selected_audio_cluster!=selected_q && selected_q!=0 && app.audio_session)
   if(!muted || !app.audio_stopped)$fatal(1,"selection changed before mute/drain");
  selected_q<=app.selected_audio_cluster;
  if(app.scan_accept && (app.audio_run || !app.audio_stopped || app.a_busy))$fatal(1,"rescan before physical/audio drain");
 end
 task short_key(input integer n);
 begin
  if(n==1)key1=0;else if(n==2)key2=0;else key4=0;
  repeat(35)@(negedge clk);key1=1;key2=1;key4=1;repeat(35)@(negedge clk);
 end endtask
 task toggle_scene;
 begin key4=0;repeat(1030)@(negedge clk);key4=1;repeat(35)@(negedge clk);end endtask
 task stable_stage(input integer stage,input integer cluster);
 begin
  wait(app.g_scenario.control.state==1 && app.g_scenario.control.stage==stage && !scene_fade);
  if(app.selected_audio_cluster!=cluster || image!=stage)$fatal(1,"stage/image/audio mismatch");
  wait(volume.gain==65536);wait(received>=5000);
  $display("PASS stage %0d cluster %0d fresh PCM and complete fade-in; t=%0d",stage,cluster,app.g_scenario.control.t_now);
 end endtask
 task rescan;
 begin key2=0;repeat(2030)@(negedge clk);key2=1;wait(app.scan_busy);wait(!app.scan_busy);repeat(35)@(negedge clk);end endtask
 initial begin
  setup(1,1,1202);add_sounds();repeat(5)@(negedge clk);rst=0;
  wait(display_valid && received>=500);if(app.snd_valid!=4'b1011)$fatal(1,"scanner slots");
  toggle_scene();stable_stage(0,12);
  short_key(4);wait(app.g_scenario.control.speed==1);
  short_key(4);wait(app.g_scenario.control.speed==2);
  short_key(2);stable_stage(1,8);
  short_key(2);stable_stage(2,10); // SND3 absent -> BGM
  short_key(2);stable_stage(3,9);
  short_key(2);stable_stage(0,12);
  short_key(1);stable_stage(3,9);
  if(!app.g_scenario.control.warn_mode || app.g_scenario.control.t_now!=239)$fatal(1,"warning state");
  toggle_scene();wait(app.g_scenario.control.state==0);wait(received>=500);
  if(app.selected_audio_cluster!=10)$fatal(1,"exit must restore BGM");
  toggle_scene();stable_stage(0,12);
  // Abort while the scene owns the control path: rescan must not deadlock.
  rescan();wait(app.g_scenario.control.state==0);wait(display_valid && received>=500);
  if(app.scene_mode || scene_fade)$fatal(1,"scene rescan did not exit");
  // No SND and no BGM: scene clock falls back to frames.
  disk[1536]=0;rescan();wait(app.first_image_committed);wait(!bactive);
  toggle_scene();wait(app.g_scenario.control.state==1);
  wait(app.g_scenario.control.t_now>=4);
  if(app.scene_audio_running || app.selected_audio_found)$fatal(1,"missing audio fallback");
  short_key(2);wait(app.g_scenario.control.state==1 && app.g_scenario.control.stage==1);
  wait(app.g_scenario.control.t_now>=4);toggle_scene();wait(app.g_scenario.control.state==0);
  $display("PASS M4 actual PCM: %0d exact samples, %0d sessions, four stages/wrap/warning/speed, SND3 fallback, muted selection, rescan and no-audio frame clock",total,sessions);
  $finish;
 end
 initial begin #3000000000.0;$fatal(1,"scenario watchdog fsm=%0d audio=%0d cluster=%0d received=%0d scan=%0d",app.g_scenario.control.state,app.g_audio.u_stream.state,app.selected_audio_cluster,received,app.scan_state);end
 task setup(input bit pictures,input bit audio,input integer bytes);
 reg [15:0] value;integer lba,off;
 begin
  for(integer j=0;j<8192;j++)disk[j]=0;
  disk[12]=2;disk[13]=1;disk[14]=1;disk[16]=1;
  word32(32,101);word32(36,1);word32(44,2);disk[510]=8'h55;disk[511]=8'haa;
  word32(520,3);word32(524,32'h0fffffff);
  word32(552,15);word32(572,11);word32(556,32'h0fffffff);
  for(integer j=0;j<16;j++)disk[1024+j*32]=8'he5;
  if(pictures)for(integer j=0;j<4;j++)begin
   entry(1024+j*32,{"PIC",8'(49+j),"    BMP"},4+j,58);
   lba=(4+j)*512;disk[lba]="B";disk[lba+1]="M";word32(lba+2,58);disk[lba+10]=54;disk[lba+14]=40;
   disk[lba+18]=1;disk[lba+22]=1;disk[lba+26]=1;disk[lba+28]=24;disk[lba+54]=20+j;
  end
  if(audio)entry(1536,"BGM     PCM",10,bytes);
  for(integer j=0;j<1536;j++)begin
   lba=j<512?10:(j<1024?15:11);off=j%512;value=(j/2)*62-20000;
   disk[lba*512+off]=j%2?value[15:8]:value[7:0];
  end
 end endtask
endmodule
