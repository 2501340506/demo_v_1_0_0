`timescale 1ns/1ps
// Production SD controller/scanner/decoder/scaler. Only transport and external
// memory acknowledgements are modeled; actual SDRAM packing has its own test.
module tb_selector_controller;
 parameter CASE_ID=0, REAL_WRITER=0, BYTE_GAP=1, TONE_CLOCK_HZ=0, REAL_READER=0, HDMI_AUDIO=0, CHECK_AUTO=0, FRAME_CYCLES=100, WATCHDOG_NS=64'd12000000000;
 localparam real PIX_HALF_NS=TONE_CLOCK_HZ>0?500000000.0/TONE_CLOCK_HZ:(REAL_READER?20.0:7.0);
 reg clk=0,pix=0,rst=1;always #5 clk=~clk;always #(PIX_HALF_NS) pix=~pix;
 reg k1=1,k2=1,k4=1,sw=0;reg [1:0] mode=0;
 wire [1:0] app,wb,db,effective,focus;wire [3:0] valid;
 wire busy,error,wr,we,source_done,cancel,display_req,menu_write,visible;
 wire [5:0] identity;wire [31:0] data;wire [4:0] level;
 reg permit=1;integer permit_cycle=0;
 reg ack=0,finish=0,cancel_ack=0,display_ack=0,frame=0,commit=0;
 wire normal_req,normal_ack,descriptor_req,display_off;
 wire [17:0] normal_desc;wire [31:0] descriptor;
 reg descriptor_ack=0;
 wire mem_fault,mem_ready,mem_init,mem_source_error;wire [2:0] mem_code;
 wire muted_feedback,bgm_ready;
 wire committed_valid,committed_ready,media_update,media_enable;wire [1:0] committed_image,media_image;
 media_commit_cdc media_mailbox(.src_clk(clk),.dst_clk(pix),.src_rst(rst),.dst_rst(rst),
  .src_image(committed_image),.src_valid(committed_valid),.src_ready(committed_ready),
  .media_id(media_image),.media_update(media_update),.media_enable(media_enable));
 wire bgm_valid,bgm_active,scenario_fade;
 wire signed [15:0] bgm_left,bgm_right;
 wire mixed_valid,mixed_ready,arp_ready,volume_valid;
 wire signed [15:0] mixed_left,mixed_right,volume_left,volume_right;
 reg [1:0] fade_sync=0;
 wire tone_valid;wire signed [15:0] tone_left,tone_right;
 generate if(TONE_CLOCK_HZ>0)begin:g_tone
  pcm_media_tone #(.CLOCK_HZ(TONE_CLOCK_HZ),.FIXED_VOLUME(0)) tone(
   .clk(pix),.rst_n(!rst),.enable(1'b0),.media_update(1'b0),.media_id(2'd0),.volume(8'd0),
   .sample_valid(tone_valid),.sample_ready(arp_ready),.sample_left(tone_left),.sample_right(tone_right));
 end else begin
  assign tone_valid=1;assign tone_left=0;assign tone_right=0;
 end endgenerate
 always @(posedge pix)if(rst)fade_sync<=0;else fade_sync<={fade_sync[0],scenario_fade};
 audio_source_mux audio_mux(.clk(pix),.rst_n(!rst),.wav_valid(bgm_valid),.wav_ready(bgm_ready),
  .wav_left(bgm_left),.wav_right(bgm_right),.wav_active(bgm_active),
  .arp_valid(tone_valid),.arp_ready(arp_ready),.arp_left(tone_left),.arp_right(tone_right),
  .out_ready(mixed_ready),.out_valid(mixed_valid),.out_left(mixed_left),.out_right(mixed_right));
 wire volume_ready;
 generate if(HDMI_AUDIO)begin:g_hdmi
  wire hs,vs,de;wire [11:0] x;
  color_bar timing(.clk(pix),.rst(rst),.hs(hs),.vs(vs),.de(de),.rgb_r(),.rgb_g(),.rgb_b(),.video_x(x));
  media_hdmi_audio_bridge bridge(.pixel_clk(pix),.pixel_rst_n(!rst),
   .video_hsync(hs),.video_vsync(vs),.video_de(de),.video_x(x[9:0]),.video_rgb(24'd0),
   .select_media(1'b1),.test_valid(1'b0),.test_left(16'd0),.test_right(16'd0),.test_ready(),
   .media_valid(volume_valid),.media_ready(volume_ready),.media_left(volume_left),.media_right(volume_right),
   .channel0_symbol(),.channel1_symbol(),.channel2_symbol(),.sequence_error(),
   .pcm_tap_valid(),.pcm_tap_left(),.pcm_tap_right());
 end else assign volume_ready=1'b1;endgenerate
 pcm_master_volume volume(.clk(pix),.rst(rst),.volume_level(4'd10),.fade_mute(fade_sync[1]),.muted(muted_feedback),
  .in_valid(mixed_valid),.in_ready(mixed_ready),.in_left(mixed_left),.in_right(mixed_right),
  .out_valid(volume_valid),.out_ready(volume_ready),.out_left(volume_left),.out_right(volume_right));
 disaster_menu_descriptor mailbox(.clk(clk),.rst(rst),.normal_request(normal_req),.normal_descriptor(normal_desc),
  .normal_ack(normal_ack),.visible(visible),.focus(focus),.valid(valid),.identity(identity),
  .request(descriptor_req),.descriptor(descriptor),.ack(descriptor_ack),.display_off(display_off));
 sd_card_bmp #(.MENU_ENABLE(1),.CLK_FREQ_HZ(1000),.LOAD_TIMEOUT_MS(10000),.PUBLICITY_ENABLE(1),
  .SCENE_ENABLE(1),.AUDIO_ENABLE(CASE_ID==10 || CASE_ID==16 || CASE_ID>=19),.PREVIEW_ENABLE(1),.TRANSITION_ENABLE(1),.USE_FRAME_RESULT(1),.SCALE_ENABLE(1)) dut(
  .clk(clk),.rst(rst),.sdram_ready(REAL_WRITER?mem_init:1'b1),.key1(k1),.key2(k2),.key4(k4),.mode(mode),.sw3(sw),
  .menu_write_mode(menu_write),.menu_visible(visible),.menu_focus(focus),.menu_valid(valid),.effective_mode(effective),.menu_display_off(display_off),
  .bgm_ready(CASE_ID>=19?bgm_ready:1'b1),.scenario_muted(CASE_ID>=19?muted_feedback:1'b1),
  .bgm_valid(bgm_valid),.bgm_active(bgm_active),.bgm_left(bgm_left),.bgm_right(bgm_right),.scenario_fade(scenario_fade),
  .application_mode(app),.application_busy(busy),.application_error(error),.display_identity(identity),
  .bmp_width(16'd640),.bmp_height(16'd480),.committed_ready(committed_ready),
  .committed_valid(committed_valid),.committed_image(committed_image),
  .write_cancel_req(cancel),.write_cancel_ack(cancel_ack),.source_frame_done(source_done),.source_frame_error(mem_source_error),
  .frame_error_toggle(REAL_WRITER?mem_fault:1'b0),.frame_memory_error(REAL_WRITER?mem_code:3'd0),.reader_error(3'd0),.reader_underflow(1'b0),
  .write_finish_toggle(finish),.display_commit_ack(display_ack),.preview_ack(normal_ack),.preview_request(normal_req),.preview_descriptor(normal_desc),
  .transition_pix_clk(pix),.transition_pix_rst(rst),.transition_frame_start(frame),.transition_commit_done(commit),
  .display_commit_request(display_req),.write_buf_idx(wb),.disp_buf_idx(db),.transition_level(level),
  .write_req(wr),.write_req_ack(ack),.write_ready(permit),.write_en(we),.write_data(data),.SD_MISO(1'b1));
 // Registered drain summaries must never hand off a live reader/audio job.
 always @(posedge clk)if(!rst)begin
  if(CASE_ID>=19 && dut.load_fault)
   $fatal(1,"page load failure image=%d parser=%d fat=%h memory=%d decoder=%d offset=%d",dut.load_idx,dut.parser_error,dut.bmp_read_m0.fat_error,mem_code,dut.bmp_read_m0.decode_error,dut.bmp_read_m0.stream_offset);
  if(CASE_ID>=19 && dut.cache_complete)
   $display("cache complete image=%d t=%t",dut.cache_complete_image,$time);
  if(dut.scan_accept && (dut.audio_run || !dut.audio_stopped))
   $fatal(1,"scan accepted before audio drain");
  if(dut.menu_pending && dut.safe_menu_idle &&
    (!dut.bmp_ready || dut.load_busy || dut.load_request || dut.audio_run || !dut.audio_stopped || dut.scan_request))
   $fatal(1,"menu acquired a live transaction");
 end
 // Timing-only mux change preserves the target on every offered edge,
 // including offers stalled by the cache. Compare with the previous mux.
 always @(posedge clk)if(!rst && dut.cache_offer &&
  dut.cache_target!==(dut.scene_request?dut.scene_target:dut.preview_offer?dut.preview_target:dut.ctrl_target_image))
  $fatal(1,"retimed preview selector changed an offered cache target");
 always @(posedge clk)if(!rst && dut.scene_request &&
  dut.cache_ready_by_image[dut.scene_target] !== dut.ctrl_request_ready)
  $fatal(1,"per-image ready changed scenario acceptance");
 reg raw_valid=0,raw_end=0,raw_fail=0;reg [7:0] raw_byte=0;
 reg [31:0] meta[0:2],lbas[0:32767];reg [7:0] disk[0:16777215];
 integer sector_slot[int unsigned];
 integer gap=0;
 integer pos=0,slot=-1,k,reads=0,commits=0,background_failures=0;reg serving=0,released=1;
 initial begin
  force dut.sd_init_done=1;force dut.sd_init_failed=0;
  force dut.sd_sec_read_data_valid=raw_valid;force dut.sd_sec_read_data=raw_byte;
  force dut.sd_sec_read_end=raw_end;force dut.sd_sec_read_failed=raw_fail;
 end
 always @(negedge clk)begin
  raw_valid=0;raw_end=0;raw_fail=0;
  if(rst || dut.parser_rst)begin serving=0;released=1;end
  else if(!serving)begin
   if(!dut.sd_sec_read)released=1;
   if(dut.sd_sec_read && released)begin
    slot=sector_slot.exists(dut.sd_sec_read_addr)?sector_slot[dut.sd_sec_read_addr]:-1;
    if(slot<0)$fatal(1,"unexpected sector %d",dut.sd_sec_read_addr);
    if(dut.menu_owner && dut.menu_preview && dut.sd_sec_read_addr>=1164 && dut.sd_sec_read_addr<=1190 &&
       (dut.sd_sec_read_addr-1154)%8!=1)$fatal(1,"menu read later-stage pixels/header");
    if(CASE_ID==16 && dut.sd_sec_read_addr>=1299 && dut.sd_sec_read_addr<=1300 && commits==0)
     $fatal(1,"optional BIN loaded before real first frame");
    reads++;pos=0;serving=1;released=0;gap=0;
   end
  end else if(gap>0)gap--;
  else if(pos<512)begin
   gap=BYTE_GAP-1;
   raw_valid=1;raw_byte=disk[slot*512+pos];pos++;
   // Corrupt only full-file attempts, after the four-header preflight.
   // A physical SD timeout intentionally stops the transport; malformed
   // file data is the retryable background error exercised here.
   if(CASE_ID==18 && !dut.menu_owner && dut.load_busy && lbas[slot]==1164 && pos==1 && background_failures<2)begin
    raw_byte="X";background_failures++;
    $display("injected PIC2 malformed body attempt %0d",background_failures);
   end
   if(pos==512)begin
    raw_end=1;serving=0;
    if((CASE_ID==9 && lbas[slot]==1173) || (CASE_ID==17 && lbas[slot]==2374))raw_fail=1;
   end
  end
 end
 integer bank_pixels[0:3];reg [5:0] bank_id[0:3];reg bank_good[0:3];
 generate if(!REAL_WRITER)begin
 always @(posedge clk)begin permit_cycle<=permit_cycle+1;permit<=(permit_cycle%11)<7;end
 end else begin:g_real_memory
 reg mem_clk=0;always #12.5 mem_clk=~mem_clk;
 wire shifted;assign #12 shifted=mem_clk;
 wire refresh,mem_busy,write_busy,write_en,write_finish,write_ack,write_cack;
 wire [20:0] address;wire [31:0] pixel_data,unused_data;
 wire sc,ras,cas,swe;wire [1:0] ba;wire [10:0] addr;wire [3:0] dm;tri [31:0] dq;
 wire read_busy,refill,read_en,read_valid;wire [20:0] read_address;
 media_thumbnail_loader #(.MENU_ENABLE(1),.NATIVE_MENU_ENABLE(1)) writer(
  .rst(rst),.mem_clk(mem_clk),.write_clk(clk),.write_rst(rst),
  .Sdr_init_done(mem_init),.Sdr_init_ref_vld(refresh),.Sdr_busy(mem_busy),.App_rd_busy(read_busy || refill),
  .O_wr_busy(write_busy),.App_wr_en(write_en),.App_wr_addr(address),.App_wr_din(pixel_data),.App_wr_dm(),
  .menu_mode(menu_write),.native_menu(dut.menu_native),.write_req(wr),.write_req_ack(write_ack),
  .write_cancel_req(cancel),.write_cancel_ack(write_cack),
  .write_addr_0(21'd0),.write_addr_1(21'd307200),.write_addr_2(21'd614400),.write_addr_3(21'd921600),
  .write_addr_index(wb),.write_len(21'd307200),.write_en(we),.write_data(data),.write_ready(mem_ready),
  .source_done(source_done),.source_error(mem_source_error),.write_finish(write_finish),.error_toggle(mem_fault),.memory_error(mem_code));
 wire reader_ack,desc_ack,read_req,read_ack,consume,hs,vs,de;wire [9:0] video_x;
 wire [31:0] reader_pixel,pixel_desc;
 wire [2:0] reader_error;wire underflow;
 if(REAL_READER)begin:g_read
  video_timing_data timing(.video_clk(pix),.rst(rst),.read_req(read_req),.read_req_ack(read_ack),
   .hs(hs),.vs(vs),.de(de),.video_x(video_x));
  media_frame_reader #(.PREVIEW_ENABLE(1),.MENU_ENABLE(1),.DESC_WIDTH(32)) reader(
   .rst(rst),.mem_clk(mem_clk),.read_clk(pix),.read_rst(rst),
   .Sdr_init_done(mem_init),.Sdr_init_ref_vld(refresh),.Sdr_busy(mem_busy),.App_wr_busy(write_busy),
   .O_rd_busy(read_busy),.refill_priority(refill),.App_rd_en(read_en),.App_rd_addr(read_address),
   .Sdr_rd_en(read_valid),.Sdr_rd_dout(unused_data),.read_req(read_req),.read_req_ack(read_ack),.read_finish(),
   .preview_request(descriptor_req),.preview_descriptor(descriptor),.preview_ack(desc_ack),.pixel_descriptor(pixel_desc),
   .display_commit_request(display_req),.display_commit_ack(reader_ack),
   .read_addr_0(21'd0),.read_addr_1(21'd307200),.read_addr_2(21'd614400),.read_addr_3(21'd921600),
   .read_addr_index(db),.read_len(21'd307200),.read_en(consume),.display_valid(dut.display_valid),
   .read_data(reader_pixel),.underflow(underflow),.reader_error(reader_error));
  video_delay delay_path(.video_clk(pix),.rst(rst),.read_en(consume),.read_data(reader_pixel[31:8]),
   .hs(hs),.vs(vs),.de(de),.video_x(video_x),.hs_r(),.vs_r(),.de_r(),.vout_data(),.video_x_r());
  reg vs_q=0,seen=0;
  always @(negedge pix)begin
   vs_q<=vs;frame=vs_q && !vs;commit=reader_ack!=seen;seen=reader_ack;
   display_ack=reader_ack;descriptor_ack=desc_ack;
   if(commit)begin
    if(!bank_good[db] || bank_id[db]!==identity)$fatal(1,"real reader stale/partial commit");
    commits++;
   end
   if(!rst && reader_error!=0)$fatal(1,"real reader error=%d",reader_error);
  end
 end else begin
  assign read_busy=0;assign refill=0;assign read_en=0;assign read_address=0;
 end
 sdram controller(.Clk(mem_clk),.Clk_sft(shifted),.Rst(rst),.Sdr_init_done(mem_init),.Sdr_init_ref_vld(refresh),.Sdr_busy(mem_busy),
  .App_wr_en(write_en),.App_wr_addr(address),.App_wr_dm(4'd0),.App_wr_din(pixel_data),.App_rd_en(read_en),.App_rd_addr(read_address),
  .Sdr_rd_en(read_valid),.Sdr_rd_dout(unused_data),.SDRAM_CLK(sc),.SDR_CKE(),.SDR_RAS(ras),.SDR_CAS(cas),.SDR_WE(swe),
  .SDR_BA(ba),.SDR_ADDR(addr),.SDR_DM(dm),.SDR_DQ(dq));
 sdram_bl4_model memory(.clk(sc),.ras(ras),.cas(cas),.we(swe),.ba(ba),.addr(addr),.dm(dm),.dq(dq));
 always @*begin ack=write_ack;cancel_ack=write_cack;permit=mem_ready;end
 always @(posedge mem_clk or posedge rst)if(rst)finish<=0;else if(write_finish)finish<=~finish;
 always @(posedge clk)if(!rst && mem_code!=0)$display("memory error code=%d",mem_code);
 end endgenerate
 integer pixels=0,delay_finish=0,normal_writes=0,menu_writes=0;
 reg [7:0] bank_page[0:3];
 reg writing=0,writing_menu=0;reg [1:0] writing_bank;
 always @(negedge clk)begin
  if(rst)begin if(!REAL_WRITER)begin ack=0;finish=0;end writing=0;delay_finish=0;end
  else begin
   if(!REAL_WRITER)cancel_ack=cancel;
   if(cancel)begin if(!REAL_WRITER)ack=0;writing=0;delay_finish=0;end
   if(wr && !writing && !cancel)begin
    writing=1;writing_bank=wb;writing_menu=menu_write;pixels=0;if(!REAL_WRITER)ack=1;
    if(!menu_write)begin bank_good[wb]=0;bank_id[wb]={dut.resource_version,dut.scan_application};normal_writes++;end
    else menu_writes++;
   end
   if(we)begin
    if(CASE_ID>=19 && !menu_write && pixels==320)bank_page[wb]=data[31:24]/40;
    if(menu_write && dut.menu_native && data!=={8'(pixels/256),8'((dut.g_menu.backend.scene+1)*32),8'(pixels%256),8'hff})
     $fatal(1,"native thumbnail RGB/order/backpressure pixel=%d got=%h",pixels,data);
    if(!writing || wb!=writing_bank || menu_write!=writing_menu)$fatal(1,"write owner changed");
    if(menu_write && !dut.menu_native && (pixels%640<160 || pixels%640>=480))begin
     if(data!==32'h000000ff)$fatal(1,"menu source letterbox");
    end
    pixels++;
   end
   if(source_done && writing)begin
    if(pixels!=(menu_write && dut.menu_native?49152:307200))$fatal(1,"incomplete scaled/native frame %d",pixels);
    if(!writing_menu)begin bank_good[wb]=1;bank_pixels[wb]=pixels;end
    if(!REAL_WRITER)delay_finish=13;else writing=0;
   end
   if(delay_finish>0)begin delay_finish--;if(delay_finish==0)begin writing=0;ack=0;finish=~finish;end end
  end
 end
 integer fd=0;
 always @(negedge pix)if(!REAL_READER)begin
  frame=0;commit=0;
  if(!rst)begin
   fd++;
   if(fd==FRAME_CYCLES)begin
    fd=0;frame=1;descriptor_ack=descriptor_req;
    if(display_req!=display_ack)begin
     if(!bank_good[db] || bank_id[db]!==identity)$fatal(1,"stale/partial display");
     display_ack=display_req;commit=1;commits++;
    end
   end
  end
 end
 task cycles(input integer n);repeat(n)@(negedge clk);endtask
 task next_key;begin k2=0;cycles(60);k2=1;cycles(60);end endtask
 task previous_key;begin k1=0;cycles(60);k1=1;cycles(60);end endtask
 task short4;begin k4=0;cycles(60);k4=1;cycles(60);end endtask
 task toggle_app;begin k4=0;cycles(1100);k4=1;cycles(100);end endtask
 task menu_ready;begin
  wait(dut.menu_ready);cycles(500);
  if(valid!==4'(meta[1]) || !visible || !descriptor[24])$fatal(1,"menu valid/display got=%b expected=%b",valid,meta[1]);
 end endtask
 task app_ready(input integer wanted);begin
  wait(!busy);cycles(300);
  if(app!=wanted || error || level!=16)$fatal(1,"app settle got=%d wanted=%d error=%b",app,wanted,error);
 end endtask
 reg [4:0] last_backend=31;reg [3:0] last_app=15;
 always @(negedge clk)if(!rst)begin
  if(dut.g_application.application.state!=last_app)begin
   last_app=dut.g_application.application.state;$display("app state=%d scan=%d dir=%d reads=%d t=%t",last_app,dut.scan_state,dut.resource_directory,reads,$time);
  end
  if(dut.g_menu.backend.state!=last_backend)begin
   last_backend=dut.g_menu.backend.state;
   if(last_backend==11 || last_backend>=15)$display("backend state=%d scene=%d valid=%b",last_backend,dut.g_menu.backend.scene,valid);
  end
 end
 integer q,n,s,before_writes,before_commits;reg saved_auto;reg [1:0] saved_speed=0;string prefix;
 always @(negedge clk)if(!rst && dut.menu_active &&
  (dut.adjust_decrease || dut.adjust_increase || dut.adjust_restore || dut.adjust_select || dut.application_toggle || dut.rescan_event))
   $fatal(1,"menu key leaked into original controls");
 initial begin
  prefix=$sformatf("selector%0d_",CASE_ID);
  $readmemh({prefix,"meta.hex"},meta,0,2);$readmemh({prefix,"lba.hex"},lbas,0,meta[0]-1);
  $readmemh({prefix,"bytes.hex"},disk,0,meta[0]*512-1);
  for(q=0;q<meta[0];q++)sector_slot[lbas[q]]=q;
  for(q=0;q<4;q++)begin bank_good[q]=0;bank_id[q]=0;bank_pixels[q]=0;end
  sw=CASE_ID==6;cycles(10);rst=0;
  if(CASE_ID==6)begin menu_ready();sw=0;wait(!dut.menu_active);app_ready(1);end
  else app_ready(meta[2]);
  if(CASE_ID==16)begin
   wait(dut.scan_state==0);cycles(100);
   if(commits<1 || !dut.font_valid || !dut.text_valid)$fatal(1,"deferred resources unavailable");
   wait(dut.bgm_valid);
   $display("PASS selector startup: real frame before FONT/TEXT, delayed narration starts");$finish;
  end
  wait(dut.cache_valid==15);cycles(300);
  if(CASE_ID>=19)$display("all four pages cached t=%t",$time);
  if(CASE_ID>=19)begin
   wait(dut.public_voice_status==2 || dut.public_voice_status==3);cycles(100);
   for(s=1;s<=4;s++)begin
    next_key();wait(dut.img_idx==s%4 && !dut.public_fade && !dut.transition_busy);cycles(100);
    $display("publicity page=%d t=%t",s%4+1,$time);
    if(bank_page[db]!=s%4+1)$fatal(1,"publicity pixel page mismatch page=%d actual=%d",s%4+1,bank_page[db]);
   end
   if(CHECK_AUTO)begin
    short4();if(!dut.public_auto)$fatal(1,"publicity AUTO did not enable");
    for(s=1;s<=4;s++)begin
     wait(dut.img_idx==s%4 && !dut.public_fade && !dut.transition_busy);cycles(100);
     if(bank_page[db]!=s%4+1)$fatal(1,"AUTO pixel page mismatch");
     $display("publicity AUTO page=%d t=%t",s%4+1,$time);
    end
    short4();if(dut.public_auto)$fatal(1,"publicity AUTO did not disable");
   end
   sw=1;menu_ready();short4();wait(!dut.menu_active);app_ready(2);sw=0;
   // Application fade completion can precede the scene controller's own
   // first-picture/audio handshake. Send navigation only after it is ready.
   wait(dut.g_scenario.control.state==1 && !dut.scene_fade);cycles(100);
   for(s=1;s<=4;s++)begin
    next_key();wait(dut.g_scenario.stage==s%4 && !dut.scene_fade);cycles(100);
    if(bank_page[db]!=s%4+1 || dut.display_kind!=16+s%4+1)$fatal(1,"scene pixel/tag mismatch");
   end
   previous_key();wait(dut.g_scenario.warn_mode && !dut.scene_fade);cycles(100);
   if(bank_page[db]!=4 || dut.display_kind!=8'h14)$fatal(1,"warning did not commit PIC4");
   $display("PASS selector audio/pages: EDU1-4, PIC1-4 and warning PIC4 actual pixel identity with real mute feedback");$finish;
  end
  if(CASE_ID==10)begin
   sw=1;menu_ready();short4();wait(!dut.menu_active);app_ready(2);
   if(!dut.font_valid || !dut.text_valid || dut.font_count!=13 || dut.text_bytes!=44 || dut.snd_valid!=1)
    $fatal(1,"named optional resources not loaded");
   wait(dut.bgm_valid);
   for(s=0;s<32;)begin
    @(posedge pix);if(dut.bgm_valid)begin
     if(dut.bgm_left!==16'h091a || dut.bgm_right!==16'h091a)$fatal(1,"named PCM samples got=%h",dut.bgm_left);
     s++;
    end
   end
   sw=0;cycles(100);sw=1;wait(dut.menu_owner);
   if(dut.audio_run || !dut.audio_stopped)$fatal(1,"menu acquired a live audio transaction");
   menu_ready();sw=0;wait(!dut.menu_active);wait(dut.bgm_valid);
   if(!dut.font_valid || !dut.text_valid || dut.resource_directory!=52)$fatal(1,"cancel lost optional resources");
   sw=1;menu_ready();next_key();short4();wait(!dut.menu_active);app_ready(2);
   if(dut.font_valid || dut.text_valid || dut.snd_valid || dut.audio_found || dut.resource_directory!=53)
    $fatal(1,"stale optional resources after named scene change");
   $display("PASS selector controller case=10 named PCM samples, audio safe stop/resume, FONT/TEXT and fresh optional flags");$finish;
  end
  // AUTO and preview state survive cancellation. Loading must not touch old caches.
  short4();mode=3;cycles(500);saved_auto=dut.effective_auto;
  wait(dut.preview_intent);before_writes=normal_writes;before_commits=commits;
  sw=1;menu_ready();mode=1;cycles(100);
  if(effective!=3 || normal_writes!=before_writes || commits!=before_commits)$fatal(1,"menu changed saved page/caches");
  if(CASE_ID==2)begin
   next_key();short4();wait(dut.menu_ready);cycles(100);
   if(!dut.menu_active || valid!=13)$fatal(1,"incomplete scene not rejected");
   meta[1]=13;
   previous_key();
  end
  sw=0;wait(!dut.menu_active);cycles(500);
  if(effective!=3 || dut.effective_auto!=saved_auto || app!=meta[2])$fatal(1,"cancel restore page/AUTO/app page=%d auto=%b saved=%b app=%d wanted=%d",effective,dut.effective_auto,saved_auto,app,meta[2]);
  mode=0;cycles(500);if(effective!=0)$fatal(1,"switch after cancel");
  if(dut.effective_auto)short4();
  if(CASE_ID==4 || CASE_ID==5)begin
   // Legacy AUTO must survive a menu even on the normal play page.
   short4();if(!dut.effective_auto)$fatal(1,"legacy AUTO setup");
   sw=1;menu_ready();sw=0;wait(!dut.menu_active);cycles(500);
   if(!dut.effective_auto || app!=0 || effective!=0)$fatal(1,"legacy play AUTO cancel auto=%b app=%d page=%d",dut.effective_auto,app,effective);
   short4();
  end
  if(CASE_ID==5)begin
   $display("PASS selector controller case=%d root legacy menu unavailable/cancel",CASE_ID);$finish;
  end
  if(CASE_ID==13 || CASE_ID==14 || CASE_ID==15)begin
   sw=1;menu_ready();short4();
   if(CASE_ID==15)begin wait(dut.scan_application==2 && wr);sw=0;end
   else begin
    wait(dut.menu_rejected);cycles(100);
    if(!dut.menu_active || valid[0])$fatal(1,"invalid selection escaped menu");
    sw=0;
   end
   wait(!dut.menu_active);app_ready(1);
   if(dut.resource_directory!=40)$fatal(1,"failed/cancelled selection did not restore publicity");
   $display("PASS selector failure/cancel case=%0d: menu retained, saved app restored",CASE_ID);$finish;
  end
  if(CASE_ID==7 || CASE_ID==8 || CASE_ID==9)begin
   sw=1;menu_ready();next_key();short4();wait(dut.menu_rejected);cycles(100);
   if(valid!=13 || !dut.menu_active)$fatal(1,"bad later-stage preflight escaped");
   meta[1]=13;
   previous_key();sw=0;wait(!dut.menu_active);app_ready(1);
  end
  if(CASE_ID==18)begin
   sw=1;menu_ready();short4();wait(!dut.menu_active);app_ready(2);sw=0;
   if(dut.display_kind!=8'h11)$fatal(1,"first frame was not PIC1");
   wait(dut.cache_failed[1]);$display("PIC2 marked failed cache=%b",dut.cache_valid);
   if(dut.page_error[1]!=8'h41)$fatal(1,"malformed PIC2 diagnostic missing: %h",dut.page_error[1]);
   wait(dut.cache_valid==13);cycles(200);
   if(background_failures!=2 || dut.g_scenario.stage!=0 || dut.display_kind!=8'h11)
    $fatal(1,"background failure changed complete current frame");
   before_commits=commits;$display("retry PIC2");next_key();
   wait(dut.load_busy && dut.load_idx==1);
   if(dut.display_kind!=8'h11 || commits!=before_commits)$fatal(1,"uncached stage switched before completion");
   wait(dut.g_scenario.stage==1 && !dut.scene_fade);cycles(100);
   if(dut.display_kind!=8'h12 || dut.cache_failed!=0 || !dut.cache_valid[1])$fatal(1,"manual stage retry failed");
   if(dut.page_error[1]!=0 || dut.failed_request_detail!=0)$fatal(1,"successful PIC2 retry retained diagnostic");
   $display("PASS selector background: PIC1 entry, two malformed bodies retain frame, other prefetch continues, manual retry commits complete PIC2");$finish;
  end
  for(n=0;n<(CASE_ID==0?4:1);n++)begin
   sw=1;menu_ready();for(q=0;q<n;q++)next_key();
   if(CASE_ID==0)begin previous_key();next_key();end
   k4=0;wait(dut.menu_confirm);wait(!dut.menu_active);cycles(1500);
   if(!dut.menu_blocked || dut.scene_auto)$fatal(1,"held confirm leaked");
   k4=1;cycles(100);app_ready(2);
   if(dut.g_scenario.stage!=0 || dut.g_scenario.warn_mode || dut.scene_auto || effective!=0 || dut.selected_hazard!=n+1 || dut.g_scenario.speed!=saved_speed)
    $fatal(1,"scene entry defaults/identity");
   if(dut.resource_directory!=52+n || dut.display_kind!=((n+1)*16+1))$fatal(1,"confirmed resource mismatch dir=%d kind=%h",dut.resource_directory,dut.display_kind);
   sw=0;cycles(100);if(dut.menu_active)$fatal(1,"SW3 falling after confirmation");
   if(CASE_ID==0)begin
    // Exercise every named resource through actual stage selection, including
    // wrap back to stage one. Each visible header must match its directory.
    wait(dut.cache_valid==15);
    for(s=1;s<=4;s++)begin
     next_key();wait(dut.g_scenario.stage==s%4 && !dut.scene_fade);cycles(100);
     if(dut.display_kind!=((n+1)*16+s%4+1))$fatal(1,"16-image stage identity scene=%d stage=%d kind=%h",n,s%4,dut.display_kind);
    end
   end
   if(CASE_ID==0 && n==0)begin
    // Change speed through the real long-press gesture, then preserve it
    // while confirming three other scenes.
    k1=0;cycles(1100);k1=1;cycles(100);saved_speed=1;
    if(dut.g_scenario.speed!=1)$fatal(1,"scene speed gesture");
   end
  end
  if(CASE_ID==0)begin
   // Cancel during a real thumbnail transaction from the parameter page.
   // A long menu key must neither change parameters nor rescan on handover.
   short4();if(!dut.scene_auto)$fatal(1,"scene AUTO setup");
   mode=1;cycles(500);before_writes=menu_writes;sw=1;menu_ready();
   if(menu_writes!=before_writes)$fatal(1,"cached menu reloaded pixels");
   cycles(100);k2=0;sw=0;
   wait(!dut.menu_active);cycles(2200);
   if(!dut.scene_auto || effective!=1 || app!=2 || dut.g_scenario.speed!=saved_speed || !dut.menu_blocked)
    $fatal(1,"loading cancel/parameter page/AUTO/held key");
   k2=1;cycles(100);if(dut.menu_blocked)$fatal(1,"loading cancel key release");
  end
  if(CASE_ID==1)begin
   toggle_app();app_ready(1);if(dut.resource_directory!=0)$fatal(1,"root publicity priority");
   toggle_app();app_ready(2);if(dut.resource_directory!=0 || dut.resource_hazard!=0)$fatal(1,"root scene priority");
  end
  $display("PASS selector controller case=%d scenes=%d menuWrites=%d commits=%d reads=%d confirm/cancel/cache/page/AUTO/held keys",CASE_ID,n,menu_writes,commits,reads);$finish;
 end
 initial forever begin #100000000;
  if(REAL_READER || FRAME_CYCLES!=100)$display("progress t=%t app=%d scene=%d audio=%d transition=%b request=%b sent=%b pause=%b black=%b level=%d muted=%b fade=%b frame=%b cache=%b failed=%b image=%d parser=%d reads=%d",$time,dut.g_application.application.state,dut.g_scenario.control.state,dut.g_scenario.audio_control.state,dut.transition_busy,dut.cache_display_request,dut.g_scenario.control.sent,dut.cache_pause,dut.app_black_permit,dut.app_level,dut.scene_muted_sd,dut.scenario_fade,frame,dut.cache_valid,dut.cache_failed,dut.load_idx,dut.bmp_read_m0.state,reads);
 end
 initial begin #(WATCHDOG_NS);$display("state scan=%d app=%d backend=%d scene=%d cache=%d load=%d valid=%b failed=%b paused=%b failures=%d",dut.scan_state,dut.g_application.application.state,dut.g_menu.backend.state,dut.g_scenario.control.state,dut.u_cache_control.phase,dut.u_cache_control.load_state,dut.cache_valid,dut.cache_failed,dut.cache_pause,background_failures);$fatal(1,"watchdog");end
endmodule
