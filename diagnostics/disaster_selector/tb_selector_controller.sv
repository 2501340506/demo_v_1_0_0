`timescale 1ns/1ps
// Production SD controller/scanner/decoder/scaler. Only transport and external
// memory acknowledgements are modeled; actual SDRAM packing has its own test.
module tb_selector_controller;
 parameter CASE_ID=0;
 reg clk=0,pix=0,rst=1;always #5 clk=~clk;always #7 pix=~pix;
 reg k1=1,k2=1,k4=1,sw=0;reg [1:0] mode=0;
 wire [1:0] app,wb,db,effective,focus;wire [3:0] valid;
 wire busy,error,wr,we,source_done,cancel,display_req,menu_write,visible;
 wire [5:0] identity;wire [31:0] data;wire [4:0] level;
 reg ack=0,finish=0,cancel_ack=0,display_ack=0,frame=0,commit=0;
 wire normal_req,normal_ack,descriptor_req,display_off;
 wire [17:0] normal_desc;wire [31:0] descriptor;
 reg descriptor_ack=0;
 disaster_menu_descriptor mailbox(.clk(clk),.rst(rst),.normal_request(normal_req),.normal_descriptor(normal_desc),
  .normal_ack(normal_ack),.visible(visible),.focus(focus),.valid(valid),.identity(identity),
  .request(descriptor_req),.descriptor(descriptor),.ack(descriptor_ack),.display_off(display_off));
 sd_card_bmp #(.MENU_ENABLE(1),.CLK_FREQ_HZ(1000),.LOAD_TIMEOUT_MS(10000),.PUBLICITY_ENABLE(1),
  .SCENE_ENABLE(1),.AUDIO_ENABLE(CASE_ID==10),.PREVIEW_ENABLE(1),.TRANSITION_ENABLE(1),.USE_FRAME_RESULT(1),.SCALE_ENABLE(1)) dut(
  .clk(clk),.rst(rst),.sdram_ready(1'b1),.key1(k1),.key2(k2),.key4(k4),.mode(mode),.sw3(sw),
  .menu_write_mode(menu_write),.menu_visible(visible),.menu_focus(focus),.menu_valid(valid),.effective_mode(effective),.menu_display_off(display_off),
  .bgm_ready(1'b1),.scenario_muted(1'b1),.application_mode(app),.application_busy(busy),.application_error(error),.display_identity(identity),
  .bmp_width(16'd640),.bmp_height(16'd480),.committed_ready(1'b1),
  .write_cancel_req(cancel),.write_cancel_ack(cancel_ack),.source_frame_done(source_done),
  .frame_error_toggle(1'b0),.frame_memory_error(3'd0),.reader_error(3'd0),.reader_underflow(1'b0),
  .write_finish_toggle(finish),.display_commit_ack(display_ack),.preview_ack(normal_ack),.preview_request(normal_req),.preview_descriptor(normal_desc),
  .transition_pix_clk(pix),.transition_pix_rst(rst),.transition_frame_start(frame),.transition_commit_done(commit),
  .display_commit_request(display_req),.write_buf_idx(wb),.disp_buf_idx(db),.transition_level(level),
  .write_req(wr),.write_req_ack(ack),.write_ready(1'b1),.write_en(we),.write_data(data),.SD_MISO(1'b1));
 reg raw_valid=0,raw_end=0,raw_fail=0;reg [7:0] raw_byte=0;
 reg [31:0] meta[0:2],lbas[0:127];reg [7:0] disk[0:65535];
 integer pos=0,slot=-1,k,reads=0;reg serving=0,released=1;
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
    slot=-1;for(k=0;k<meta[0];k++)if(lbas[k]==dut.sd_sec_read_addr)slot=k;
    if(slot<0)$fatal(1,"unexpected sector %d",dut.sd_sec_read_addr);
    reads++;pos=0;serving=1;released=0;
   end
  end else if(pos<512)begin
   raw_valid=1;raw_byte=disk[slot*512+pos];pos++;
   if(pos==512)begin
    raw_end=1;serving=0;
    if(CASE_ID==9 && lbas[slot]==1173)raw_fail=1;
   end
  end
 end
 integer pixels=0,delay_finish=0,normal_writes=0,menu_writes=0,commits=0;
 integer bank_pixels[0:3];reg [5:0] bank_id[0:3];reg bank_good[0:3];
 reg writing=0,writing_menu=0;reg [1:0] writing_bank;
 always @(negedge clk)begin
  if(rst)begin ack=0;finish=0;writing=0;delay_finish=0;end
  else begin
   cancel_ack=cancel;
   if(cancel)begin ack=0;writing=0;delay_finish=0;end
   if(wr && !ack && !writing && !cancel)begin
    writing=1;writing_bank=wb;writing_menu=menu_write;pixels=0;ack=1;
    if(!menu_write)begin bank_good[wb]=0;bank_id[wb]={dut.resource_version,dut.scan_application};normal_writes++;end
    else menu_writes++;
   end
   if(we)begin
    if(!writing || wb!=writing_bank || menu_write!=writing_menu)$fatal(1,"write owner changed");
    if(menu_write && (pixels%640<160 || pixels%640>=480))begin
     if(data!==32'h000000ff)$fatal(1,"menu source letterbox");
    end
    pixels++;
   end
   if(source_done && writing)begin
    if(pixels!=307200)$fatal(1,"incomplete scaled frame %d",pixels);
    if(!writing_menu)begin bank_good[wb]=1;bank_pixels[wb]=pixels;end
    delay_finish=13;
   end
   if(delay_finish>0)begin delay_finish--;if(delay_finish==0)begin writing=0;ack=0;finish=~finish;end end
  end
 end
 integer fd=0;
 always @(negedge pix)begin
  frame=0;commit=0;
  if(!rst)begin
   fd++;
   if(fd==100)begin
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
   last_app=dut.g_application.application.state;$display("app state=%d scan=%d dir=%d reads=%d",last_app,dut.scan_state,dut.resource_directory,reads);
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
  for(q=0;q<4;q++)begin bank_good[q]=0;bank_id[q]=0;bank_pixels[q]=0;end
  sw=CASE_ID==6;cycles(10);rst=0;
  if(CASE_ID==6)begin menu_ready();sw=0;wait(!dut.menu_active);app_ready(1);end
  else app_ready(meta[2]);
  wait(dut.cache_valid==15);cycles(300);
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
   next_key();short4();cycles(1000);if(!dut.menu_active || dut.menu_force)$fatal(1,"incomplete scene confirmed");
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
   mode=1;cycles(500);sw=1;
   wait(menu_write && writing);cycles(100);k2=0;sw=0;
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
 initial begin #(64'd3000000000);$display("state scan=%d app=%d backend=%d scene=%d cache=%d load=%d",dut.scan_state,dut.g_application.application.state,dut.g_menu.backend.state,dut.g_scenario.control.state,dut.u_cache_control.phase,dut.u_cache_control.load_state);$fatal(1,"watchdog");end
endmodule
