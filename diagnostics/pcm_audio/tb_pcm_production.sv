`timescale 1ns/1ps
module tb_pcm_production;
 reg clk=0,pix=0,rst=1;
 always #5 clk=~clk;
 always #20 pix=~pix;
 reg key4=1,key1=1,key2=1;
 wire req,cancel,done,commit,bvalid,bactive,bready;
 wire signed [15:0] bl,br;
 reg finish=0;
 wire [1:0] image;
 wire image_valid,display_valid;
 sd_card_bmp #(.CLK_FREQ_HZ(1000),.LOAD_TIMEOUT_MS(5000),.AUDIO_ENABLE(1)) app(
 .clk(clk),.rst(rst),.sdram_ready(1'b1),.key1(key1),.key2(key2),.key4(key4),.mode(2'd0),
 .state_code(),.sd_debug(),.diagnostics(),.combo_event_count(),.combo_debug_active(),.auto_play_indicator(),.osd_error_code(),
 .bmp_width(16'd1),.bmp_height(16'd1),.display_valid(display_valid),.committed_image(image),.committed_valid(image_valid),.committed_ready(1'b1),
 .write_cancel_req(cancel),.write_cancel_ack(cancel),.source_frame_done(done),.source_frame_error(),
 .frame_error_toggle(1'b0),.frame_memory_error(3'd0),.reader_error(3'd0),.reader_underflow(1'b0),
 .write_finish_toggle(finish),.display_commit_ack(commit),.display_commit_request(commit),
 .transition_pix_clk(pix),.transition_pix_rst(rst),.transition_frame_start(1'b0),.transition_commit_done(1'b0),
 .write_buf_idx(),.disp_buf_idx(),.transition_active(),.transition_level(),.transition_wipe(),
 .write_req(req),.write_req_ack(req),.write_en(),.write_data(),.SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1),
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
 wire tap,seqerr;wire signed [15:0] tapl,tapr;
 media_hdmi_audio_bridge bridge(.pixel_clk(pix),.pixel_rst_n(!rst),.video_hsync(hs),.video_vsync(vs),.video_de(de),.video_x(x),.video_rgb(24'd0),
 .select_media(1'b1),.test_valid(1'b0),.test_ready(),.test_left(16'd0),.test_right(16'd0),
 .media_valid(mix_valid),.media_ready(mix_ready),.media_left(ml),.media_right(mr),
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

 integer received=0,total=0,checked=0,fallback=0,mode=1;reg was_active=0;
 reg signed [15:0] expected;
 always @(posedge pix)if(!rst)begin
  if(seqerr || tone.overflow)$fatal(1,"HDMI sequence/tone overflow");
  if(!bactive)begin received=0;was_active=0;end
  else if(!was_active)was_active=1;
  if(tap && bvalid && bready)begin
   expected=mode==2 ? -10000 : ((received%601)*62-20000)/2;
   if(mode && (tapl!==expected || tapr!==expected))$fatal(1,"PCM %0d got %0d expected %0d",received,tapl,expected);
   received++;total++;if(mode)checked++;
  end else if(tap && !bactive)fallback++;
  if(app.g_audio.u_player.underflow_count || app.g_audio.u_player.output_overrun)$fatal(1,"under/overrun");
 end
 task rescan;
 begin key2=0;repeat(2030)@(negedge clk);key2=1;wait(app.scan_busy);wait(!app.scan_busy);repeat(30)@(negedge clk);end endtask
 integer prev_count;
 initial begin
  setup(1,1,1202);repeat(5)@(negedge clk);rst=0;
  wait(received>=5300);if(app.image_count!=4)$fatal(1,"images changed by audio scan");
  // Physical audio transaction must drain before rescan resets the card.
  wait(app.a_busy && raw_valid);rescan();wait(received>=700);
  inject=1;wait(app.g_audio.u_stream.error_code!=0);mode=0;wait(!bactive);
  prev_count=fallback;wait(fallback>prev_count+100);
  inject=0;rescan();mode=1;wait(received>=700);
  // Missing BGM keeps baseline tone and image loading.
  disk[1536]=0;rescan();prev_count=fallback;wait(fallback>prev_count+100);
  if(bactive || app.image_count!=4)$fatal(1,"missing audio fallback");
  // Audio-only card, then a two-byte loop using unchanged production prefill.
  setup(0,1,1202);rescan();wait(received>=700);
  if(app.image_count!=0)$fatal(1,"audio-only unexpected image");
  mode=0;word32(1536+28,2);rescan();mode=2;wait(received>=700);
  // A fresh audio-only boot must start without any image commit or tone.
  mode=0;rst=1;repeat(5)@(negedge clk);setup(0,1,1202);mode=1;rst=0;
  wait(!bactive);wait(bactive);wait(received>=700);if(display_valid || app.image_count!=0)$fatal(1,"audio-only fresh boot");
  $display("PASS production PCM: %0d exact comparisons / %0d samples through HDMI bridge; 4 images, fragmented loop, in-flight rescan, error fallback/retry, missing BGM, audio-only fresh boot, short loop",checked,total);
  $finish;
 end
 initial begin #500000000;$fatal(1,"production watchdog scan=%d audio=%d received=%d",app.scan_state,app.g_audio.u_stream.state,received);end
endmodule
