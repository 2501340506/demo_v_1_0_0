`timescale 1ns/1ps
// Real production controller, FAT32 scanner/reader, decoder, scaler and cache.
// Only physical SD transport and the external memory handshakes are modeled.
module tb_m4_mode #(parameter CARD_CASE=0); localparam SCALE=0,AUDIO=1;
 reg clk=0;always #5 clk=~clk;
 reg pix=0;always #7 pix=~pix;
 reg rst=1,k1=1,k2=1,k4=1;reg [1:0] mode=0;
 wire [1:0] app,wb,db;wire busy,error,wr,we,source_done,cancel,display_req;
 wire [5:0] identity;wire [31:0] data;wire [4:0] level;
 reg ack=0,finish=0,cancel_ack=0,display_ack=0,frame=0,commit=0,preview_ack=0;
 wire preview_req;wire [17:0] preview_desc;
 reg raw_valid=0,raw_end=0,raw_fail=0;reg [7:0] raw_byte=0;
 wire raw_req=dut.sd_sec_read;wire [31:0] raw_lba=dut.sd_sec_read_addr;
 reg [7:0] disk[0:16383];integer pos=0,base=0,reads=0,boots=0,dirs=0;
 integer fail_lba=-1;reg persistent_fail=0;reg serving=0,released=1;
 integer pixels=0,finish_delay=0,cancel_delay=0,late_cycles=0,commits=0;
 reg writing=0;reg [1:0] writing_bank;reg [5:0] bank_id[0:3];
 integer bank_count[0:3];reg bank_good[0:3];integer expected_cluster;
 integer frame_div=0;reg visible=0;reg [1:0] visible_bank=0;
 integer expected_pixels=SCALE?307200:4;
 reg hold_background=0;integer canceled_writes=0,late_finishes=0;
 sd_card_bmp #(.CLK_FREQ_HZ(1000),.LOAD_TIMEOUT_MS(10000),.PUBLICITY_ENABLE(1),
 .SCENE_ENABLE(1),.AUDIO_ENABLE(AUDIO),.PREVIEW_ENABLE(1),.TRANSITION_ENABLE(1),.USE_FRAME_RESULT(1),.SCALE_ENABLE(SCALE)) dut(
 .clk(clk),.rst(rst),.sdram_ready(1'b1),.key1(k1),.key2(k2),.key4(k4),.mode(mode),
 .bgm_ready(1'b1),.scenario_muted(1'b1),.application_mode(app),.application_busy(busy),.application_error(error),.display_identity(identity),
 .bgm_valid(),.bgm_active(),.bgm_left(),.bgm_right(),.scenario_fade(),.scenario_state(),.scenario_meta(),
 .font_valid(),.text_valid(),.font_count(),.text_bytes(),.bin_wr_en(),.bin_wr_text(),.bin_wr_addr(),.bin_wr_data(),
 .adjust_decrease(),.adjust_increase(),.adjust_restore(),.adjust_select(),.state_code(),.sd_debug(),.diagnostics(),
 .combo_event_count(),.combo_debug_active(),.auto_play_indicator(),.osd_error_code(),
 .bmp_width(16'd2),.bmp_height(16'd2),.display_valid(),.committed_image(),.committed_valid(),.committed_ready(1'b1),
 .write_cancel_req(cancel),.write_cancel_ack(cancel_ack),.source_frame_done(source_done),.source_frame_error(),
 .frame_error_toggle(1'b0),.frame_memory_error(3'd0),.reader_error(3'd0),.reader_underflow(1'b0),
 .write_finish_toggle(finish),.display_commit_ack(display_ack),.preview_ack(preview_ack),.preview_request(preview_req),.preview_descriptor(preview_desc),
 .transition_pix_clk(pix),.transition_pix_rst(rst),.transition_frame_start(frame),.transition_commit_done(commit),
 .display_commit_request(display_req),.write_buf_idx(wb),.disp_buf_idx(db),.transition_active(),.transition_level(level),.transition_wipe(),
 .write_req(wr),.write_req_ack(ack),.write_ready(1'b1),.write_en(we),.write_data(data),.SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1));
 initial begin
 force dut.sd_init_done=1;force dut.sd_init_failed=0;
 force dut.sd_sec_read_data_valid=raw_valid;force dut.sd_sec_read_data=raw_byte;
 force dut.sd_sec_read_end=raw_end;force dut.sd_sec_read_failed=raw_fail;
 end
 always @(negedge clk)begin
 raw_valid=0;raw_end=0;raw_fail=0;
 if(rst || dut.parser_rst)begin serving=0;released=1;end
 else if(!serving)begin
 if(!raw_req)released=1;
 if(raw_req && released)begin
 if(raw_lba>31)$fatal(1,"unexpected LBA %d",raw_lba);
 reads++;if(raw_lba==0)boots++;if(raw_lba==2 || raw_lba==3)dirs++;
 base=raw_lba*512;pos=0;serving=1;released=0;end
 end else if(base/512==fail_lba && pos==8)begin raw_fail=1;serving=0;if(!persistent_fail)fail_lba=-1;end
 else if(pos<512)begin raw_valid=1;raw_byte=disk[base+pos];pos++;
 if(pos==512)begin raw_end=1;serving=0;end end
 end
 // Delayed completion and cancellation model the asynchronous memory adapter.
 always @(negedge clk)begin
 if(rst)begin ack=0;finish=0;cancel_ack=0;writing=0;finish_delay=0;cancel_delay=0;end
 else begin
 if(cancel)begin
 if(cancel_delay==0)begin cancel_delay=17;late_cycles++;end
 if(cancel_delay>1)begin
 cancel_delay--;
 if(cancel_delay==9 && writing && CARD_CASE==8)begin
  finish=~finish;late_finishes++; // old memory completion during drain
 end
 end
 else begin
 if(writing)canceled_writes++;
 cancel_ack=1;ack=0;writing=0;finish_delay=0;hold_background=0;
 end
 end else begin cancel_ack=0;cancel_delay=0;end
 if(wr && !ack && !cancel && !writing)begin
 ack=1;writing=1;writing_bank=wb;pixels=0;bank_good[wb]=0;
 bank_id[wb]={dut.resource_version,dut.scan_application};
 expected_cluster=(dut.scan_application==1?16:8)+dut.load_idx;
 if(0 && dut.load_idx>=1 && dut.scan_application!=1)expected_cluster++;
 end
 if(we)begin
 if(!writing || cancel || wb!=writing_bank)$fatal(1,"write ownership");
 if(visible && wb==visible_bank)$fatal(1,"overwrote displayed bank");
 if(!SCALE && data!=={8'(pixels%2),8'(pixels/2),8'(expected_cluster),8'hff})$fatal(1,"resource pixel mismatch got=%h expected cluster=%d page=%d",data,expected_cluster,dut.load_idx);
 if(SCALE)begin
  if(pixels%640<80 || pixels%640>=560)begin
   if(data!==32'h000000ff)$fatal(1,"scaled letterbox pixel");
  end else if(data!=={8'((pixels%640-80)/240),8'(pixels/640/240),8'(expected_cluster),8'hff})$fatal(1,"scaled content pixel %d got=%h cluster=%d",pixels,data,expected_cluster);
 end
 pixels++;
 end
 if(source_done && writing)begin
 if(pixels!=expected_pixels)$fatal(1,"partial frame pixels=%d expected=%d",pixels,expected_pixels);
 bank_count[wb]=pixels;bank_good[wb]=1;finish_delay=13;
 end
 if(finish_delay>0 && !(hold_background && dut.load_idx!=0))begin
 finish_delay--;
 if(finish_delay==0)begin ack=0;writing=0;finish=~finish;end
 end
 end
 end
 always @(negedge pix)begin
 frame=0;commit=0;
 if(rst)begin frame_div=0;display_ack=0;preview_ack=0;visible=0;end
 else begin
 frame_div++;
 if(frame_div==100)begin
 frame_div=0;frame=1;preview_ack=preview_req;
 if(display_req!=display_ack)begin
 if(!bank_good[db] || bank_count[db]!=expected_pixels || bank_id[db]!==identity)$fatal(1,"stale/partial bank commit bank=%d identity=%h stored=%h",db,identity,bank_id[db]);
 if(busy && level!=0)$fatal(1,"application committed outside black");
 visible=1;visible_bank=db;display_ack=display_req;commit=1;commits++;
 end
 end
 end
 end
 task w32(input integer at,input reg [31:0] v);
 begin disk[at]=v;disk[at+1]=v>>8;disk[at+2]=v>>16;disk[at+3]=v>>24;end endtask
 task entry(input integer at,input reg [87:0] name,input integer c,input integer z);
 integer j;begin for(j=0;j<11;j++)disk[at+j]=name[(10-j)*8+:8];disk[at+11]=32;disk[at+26]=c;w32(at+28,z);end endtask
 task setup;
 integer j,k,at;begin
 for(j=0;j<16384;j++)disk[j]=0;
 disk[12]=2;disk[13]=1;disk[14]=1;disk[16]=1;w32(32,101);w32(36,1);w32(44,2);disk[510]=8'h55;disk[511]=8'haa;
 w32(520,3);w32(524,32'h0fffffff);
 for(j=0;j<16;j++)disk[1024+j*32]=8'he5;
 for(j=0;j<4;j++)begin
 entry(1024+j*32,{"PIC",8'("1"+j),"    BMP"},8+j,70);
 entry(1536+j*32,{"EDU",8'("1"+j),"    BMP"},16+j,70);
 entry(1664+j*32,{"SND",8'("1"+j),"    PCM"},24+j,512);
 for(k=0;k<512;k++)disk[(24+j)*512+k]=k%2?8'h12:8'h34;
 end
 for(k=0;k<8;k++)begin
 j=(k<4)?8+k:12+k;at=j*512;
 disk[at]="B";disk[at+1]="M";w32(at+2,70);w32(at+10,54);w32(at+14,40);w32(at+18,2);w32(at+22,2);disk[at+26]=1;disk[at+28]=24;
 for(j=0;j<4;j++)begin disk[at+54+(j/2)*8+(j%2)*3]=at/512;disk[at+55+(j/2)*8+(j%2)*3]=j/2;disk[at+56+(j/2)*8+(j%2)*3]=j%2;end
 end
 // M4 card variants are installed after setup().
 if(0)disk[1536]=0;
 if(0)disk[1056]=8'he5;
 if(0)disk[1568]=8'he5;
 if(0)disk[1056]=8'he5;
 if(0)disk[19*512]=0;
 if(0)disk[1024]=0;
 end endtask
 task cycles(input integer n);repeat(n)@(negedge clk);endtask
 task short4;begin k4=0;cycles(60);k4=1;cycles(60);end endtask
 task toggle_app;begin k4=0;cycles(1100);k4=1;cycles(60);end endtask
 task next_page;begin k2=0;cycles(60);k2=1;cycles(60);end endtask
 task prev_page;begin k1=0;cycles(60);k1=1;cycles(60);end endtask
 task settled(input integer wanted);begin
 wait(!busy);cycles(150);
 if(app!=wanted || error || level!=16)$fatal(1,"settle app=%d wanted=%d error=%b level=%d",app,wanted,error,level);
 end endtask
 task page(input integer wanted);begin wait(dut.img_idx==wanted && !dut.foreground_busy && !dut.transition_busy);cycles(150);end endtask

 function [15:0] voice_value(input integer p,input integer n);voice_value=16'h9100+p*400+n*14;endfunction
 always @(posedge clk)if(!rst && dut.audio_run && dut.selected_publicity!=(dut.scan_application==1))
  $fatal(1,"audio started before target resource selection");
 integer b0,d0,i,j,at,sessions=0,checked=0,expected_n=0;reg [15:0] last_id=0;reg [15:0] expected_sample;
 always @(posedge pix)if(!rst && dut.bgm_valid && dut.bgm_ready && dut.g_audio.u_player.single_latched && dut.g_audio.u_player.source_tag[dut.g_audio.u_player.rp])begin
  if(dut.scan_application!=1)$fatal(1,"old VOI started in target resource set %d",dut.scan_application);
  if(last_id!=dut.g_audio.u_player.identity_latched)begin last_id=dut.g_audio.u_player.identity_latched;expected_n=0;sessions++;end
  expected_sample=$signed(voice_value(last_id[9:8],expected_n))>>>1;
  if(dut.bgm_left!==expected_sample || dut.bgm_right!==expected_sample)$fatal(1,"M4 page/session PCM id=%h sample=%d got=%h expected=%h",last_id,expected_n,dut.bgm_left,expected_sample);
  expected_n++;checked++;
 end
 task voice_finished;
 begin wait(dut.public_voice_status==3);cycles(100);
 if(expected_n!=256 || dut.g_audio.u_stream.loop_count!=0)$fatal(1,"page voice truncated/looped");end endtask
 initial begin
  for(i=0;i<4;i++)begin bank_good[i]=0;bank_count[i]=0;bank_id[i]=0;end
  setup();
  for(i=0;i<4;i++)begin
   entry(1792+i*32,{"VOI",8'("1"+i),"    PCM"},20+i,512);
   for(j=0;j<256;j++)begin at=(20+i)*512+j*2;disk[at]=voice_value(i,j);disk[at+1]=voice_value(i,j)>>8;end
  end
  if(CARD_CASE==1)disk[1792+32]=8'he5;
  if(CARD_CASE==2)w32(1792+32+28,3);
  if(CARD_CASE==3)begin fail_lba=21;persistent_fail=1;end
  cycles(10);rst=0;settled(1);voice_finished();wait(dut.cache_valid==15);b0=boots;d0=dirs;
  next_page();page(1);
  if(CARD_CASE!=0)begin
   wait(dut.public_voice_status==(CARD_CASE==1?0:4));
   short4();wait(dut.img_idx==2);page(2);short4();voice_finished();
  end else begin voice_finished();next_page();page(2);voice_finished();end
  next_page();page(3);voice_finished();prev_page();page(2);voice_finished();
  // Parameter and preview focus changes keep the current narration session.
  at=sessions;mode=1;cycles(300);mode=2;cycles(300);mode=0;cycles(300);
  if(sessions!=at || app!=1)$fatal(1,"parameter page restarted narration/app");
  mode=3;cycles(300);wait(dut.preview_intent);short4();
  mode=0;wait(sessions==at+1);page(2);voice_finished();
  if(sessions!=at+1)$fatal(1,"same-page preview did not replay from head");
  // AUTO must wait the full picture interval and all real narration samples.
  short4();wait(dut.img_idx==3);page(3);voice_finished();short4();
  toggle_app();settled(2);prev_page();wait(dut.g_scenario.warn_mode);wait(!dut.scene_fade);
  toggle_app();settled(1);page(0);voice_finished();
  if(dut.public_auto || dut.public_page!=0 || boots!=b0 || dirs!=d0)$fatal(1,"application/session reset or physical rescan");
  $display("PASS M4 modes CARD_CASE=%0d: %0d exact page/session samples in %0d sessions; four VOI, one-shot, preview same-page replay, parameter preservation, AUTO fallback, scene warning and reentry",CARD_CASE,checked,sessions);$finish;
 end
 initial begin #(64'd500000000);$fatal(1,"M4 modes watchdog app=%d busy=%b public=%d voice=%d audio=%d",app,busy,dut.g_publicity.voice.state,dut.public_voice_status,dut.g_scenario.audio_control.state);end
endmodule
