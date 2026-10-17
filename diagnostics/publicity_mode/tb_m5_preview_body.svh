 integer i,b0,d0,c0;reg [5:0] before_id;reg [1:0] before_stage;
 task preview(input integer focus);
 begin mode=3;cycles(300);wait(dut.preview_intent);cycles(300);
 if(dut.g_preview.control.focus!=focus)$fatal(1,"preview initial focus actual=%d wanted=%d current=%d app=%d",dut.g_preview.control.focus,focus,dut.img_idx,app);end endtask
 task submit(input integer p,input integer scene);
 begin
 short4();page(p);wait(!dut.g_preview.control.select_pending);cycles(300);
 if(dut.preview_intent || !dut.g_preview.control.full_view)$fatal(1,"preview did not finish");
 if(scene && (dut.g_scenario.stage!=p || dut.g_scenario.warn_mode || dut.selected_audio_stage!=p || !dut.selected_audio_scene))$fatal(1,"scene preview picture/stage/audio mismatch stage=%d target=%d audio=%d",dut.g_scenario.stage,p,dut.selected_audio_stage);
 if(scene && dut.g_scenario.control.t_now>8)$fatal(1,"scene preview did not restart animation");
 end endtask
 always @(negedge clk)if(!rst && preview_desc[17])begin
 for(integer b=0;b<4;b++)if(preview_desc[8+b])begin
  if(!bank_good[preview_desc[b*2+:2]] || bank_id[preview_desc[b*2+:2]]!==identity)$fatal(1,"preview offered stale resource bank");
 end
 end
 initial begin
 for(i=0;i<4;i++)begin bank_good[i]=0;bank_count[i]=0;bank_id[i]=0;end
 setup();if(CARD_CASE==10)for(i=0;i<4;i++)disk[1024+i*32]=8'he5;
 cycles(10);rst=0;
 settled(CARD_CASE==1 || CARD_CASE==2 ? 0:1);wait(dut.cache_valid==((CARD_CASE==2)?7:15));
 b0=boots;d0=dirs;before_id=identity;
 preview(0);next_page();cycles(200);
 if(dut.g_preview.control.focus!=1 || dut.img_idx!=0 || identity!==before_id)$fatal(1,"focus changed picture/resource");
 prev_page();cycles(200);if(dut.g_preview.control.focus!=0)$fatal(1,"preview previous");
 next_page();cycles(200);submit(1,0);
 short4();cycles(300);wait(dut.preview_intent);submit(1,0); // same page
 mode=0;cycles(200);
 if(CARD_CASE==2 || CARD_CASE==10)begin
 toggle_app();cycles(300);if(busy || app!=(CARD_CASE==2?0:1) || !dut.app_rejected)$fatal(1,"missing target destroyed preview/application");
 end else begin
 toggle_app();settled(2);wait(dut.cache_valid==15);preview(0);c0=commits;before_stage=dut.g_scenario.stage;
 next_page();cycles(300);
 if(dut.g_preview.control.focus!=1 || dut.g_scenario.stage!=before_stage || commits!=c0 || dut.scene_next || dut.g_scenario.warn_mode)$fatal(1,"scene preview next changed running scenario");
 prev_page();cycles(200);if(dut.g_preview.control.focus!=0 || commits!=c0)$fatal(1,"scene preview previous");
 prev_page();cycles(200);if(dut.g_preview.control.focus!=3)$fatal(1,"scene preview wrap");
 submit(3,1);short4();cycles(300);wait(dut.preview_intent);submit(3,1);
 mode=0;cycles(200);prev_page();wait(dut.g_scenario.warn_mode);wait(!dut.scene_fade);
 preview(3);next_page();next_page();cycles(200);submit(1,1); // exits warning to normal target
 mode=1;cycles(300);mode=2;cycles(300);mode=3;cycles(400);
 if(app!=2 || !dut.scene_mode)$fatal(1,"UI page lost application");
 mode=0;cycles(200);toggle_app();settled(CARD_CASE==1?0:1);wait(dut.cache_valid==15);preview(0);
 end
 if(boots!=b0 || dirs!=d0)$fatal(1,"preview/switch rescanned card");
 $display("PASS M5 current-set preview CARD_CASE=%0d: focus/previous/next, same-page commit, identity, missing targets, scene stage/audio and warning synchronization; commits=%0d",CARD_CASE,commits);$finish;
 end
 initial begin #500000000;$fatal(1,"M5 preview watchdog app=%d state=%d scene=%d preview offer=%b pending=%b image=%d",app,dut.g_application.application.state,dut.g_scenario.control.state,dut.preview_offer,dut.preview_selecting,dut.img_idx);end
endmodule
