`timescale 1ns/1ps
// v0.25 S3: AUTO waits for the stage's narration.
//  tb_narration_lockstep: scenario_fsm with NARRATION_GATE=1 against the
//   frozen v0.24 module whose auto_enable is ANDed with !narration_hold on the
//   same clock (auto_enable is used only in the AUTO term, so the two must be
//   identical), random inputs, all 16 parameter configurations, and also with
//   the hold held low (NARRATION_GATE=0 behaviour).
//  tb_narration_directed: the three cases that matter on the board.
module tb_narration_lockstep;
 parameter integer CYCLES=1200000;
 reg clk=0,rst=1;always #5 clk=~clk;
 reg pause=0,restart=0,enable=0,scene_ready=0,key_next=0,key_mode=0,key_speed=0,sample_tick=0,audio_running=0;
 reg frame_start=0,muted=0,auto_enable=0,request_ready=0,picture_done=0,picture_failed=0,transition_idle=0,audio_ready=0;
 reg ui_play=0,select_request=0,hold=0,hold_mode=1,inject_t=0;reg [1:0] select_stage=0;
 wire hold_in=hold && hold_mode;
 genvar g;generate for(g=0;g<16;g=g+1)begin:pair
  wire select_ready[0:1];wire [1:0] stage[0:1];wire [1:0] speed[0:1];wire warn_mode[0:1];wire [7:0] t_now[0:1];
  wire [1:0] alert_level[0:1];wire stage_req[0:1];wire [1:0] requested_stage[0:1];wire fade_mute[0:1];
  wire layer_enable[0:1];wire audio_request[0:1];wire audio_scene[0:1];wire [1:0] audio_stage[0:1];
  scenario_fsm #(.PRESERVE_SPEED(g%2),.UI_GATE((g/2)%2),.PREVIEW_SELECT((g/4)%2),.MENU_ENABLE(g/8),.NARRATION_GATE(1)) dut(
   .clk(clk),.rst(rst),.pause(pause),.restart(restart),.narration_hold(hold_in),.enable(enable),.scene_ready(scene_ready),
   .key_next(key_next),.key_mode(key_mode),.key_speed(key_speed),.sample_tick(sample_tick),.audio_running(audio_running),
   .frame_start(frame_start),.muted(muted),.auto_enable(auto_enable),.request_ready(request_ready),.picture_done(picture_done),
   .picture_failed(picture_failed),.transition_idle(transition_idle),.audio_ready(audio_ready),.ui_play(ui_play),
   .select_request(select_request),.select_stage(select_stage),.select_ready(select_ready[0]),.stage(stage[0]),.speed(speed[0]),
   .warn_mode(warn_mode[0]),.t_now(t_now[0]),.alert_level(alert_level[0]),.stage_req(stage_req[0]),.requested_stage(requested_stage[0]),
   .fade_mute(fade_mute[0]),.layer_enable(layer_enable[0]),.audio_request(audio_request[0]),.audio_scene(audio_scene[0]),.audio_stage(audio_stage[0]));
  scenario_fsm_v024 #(.PRESERVE_SPEED(g%2),.UI_GATE((g/2)%2),.PREVIEW_SELECT((g/4)%2),.MENU_ENABLE(g/8)) ref_dut(
   .clk(clk),.rst(rst),.pause(pause),.restart(restart),.enable(enable),.scene_ready(scene_ready),
   .key_next(key_next),.key_mode(key_mode),.key_speed(key_speed),.sample_tick(sample_tick),.audio_running(audio_running),
   .frame_start(frame_start),.muted(muted),.auto_enable(auto_enable && !hold_in),.request_ready(request_ready),.picture_done(picture_done),
   .picture_failed(picture_failed),.transition_idle(transition_idle),.audio_ready(audio_ready),.ui_play(ui_play),
   .select_request(select_request),.select_stage(select_stage),.select_ready(select_ready[1]),.stage(stage[1]),.speed(speed[1]),
   .warn_mode(warn_mode[1]),.t_now(t_now[1]),.alert_level(alert_level[1]),.stage_req(stage_req[1]),.requested_stage(requested_stage[1]),
   .fade_mute(fade_mute[1]),.layer_enable(layer_enable[1]),.audio_request(audio_request[1]),.audio_scene(audio_scene[1]),.audio_stage(audio_stage[1]));
  // Long-run epochs write the same t_now=238 into both modules, so that the
  // terminal frame (and AUTO) is reached many times without 100k-cycle waits.
  always @(negedge clk)if(inject_t && !rst && dut.state==1 && ref_dut.state==1 && !dut.warn_mode && dut.t_now<8'd238)begin
   dut.t_now<=8'd238;ref_dut.t_now<=8'd238;
  end
  always @(negedge clk)if(!rst)begin
   if({select_ready[0],stage[0],speed[0],warn_mode[0],t_now[0],alert_level[0],stage_req[0],requested_stage[0],fade_mute[0],layer_enable[0],audio_request[0],audio_scene[0],audio_stage[0]}!==
      {select_ready[1],stage[1],speed[1],warn_mode[1],t_now[1],alert_level[1],stage_req[1],requested_stage[1],fade_mute[1],layer_enable[1],audio_request[1],audio_scene[1],audio_stage[1]})
    $fatal(1,"config=%0d outputs differ (hold_mode=%0d)",g,hold_mode);
   if({dut.state,dut.samples,dut.running_q,dut.half_frame,dut.terminal_frame,dut.sent,dut.target,dut.target_warn,dut.committed}!==
      {ref_dut.state,ref_dut.samples,ref_dut.running_q,ref_dut.half_frame,ref_dut.terminal_frame,ref_dut.sent,ref_dut.target,ref_dut.target_warn,ref_dut.committed})
    $fatal(1,"config=%0d internal state differs (hold_mode=%0d)",g,hold_mode);
  end
 end endgenerate
 // How often AUTO was actually withheld by the hold (state RUN, terminal frame, frame_start).
 integer withheld=0,auto_moves=0,i,epoch,pos;integer seed=250725;
 localparam integer EPOCH=100000;
 always @(negedge clk)if(!rst && pair[11].dut.state==1 && pair[11].dut.terminal_frame && frame_start && auto_enable && ui_play && !pair[11].dut.warn_mode)begin
  if(hold_in)withheld++;else auto_moves++;
 end
 // Epochs alternate between chaotic inputs (every control toggles at random)
 // and long runs (a scene held in RUN so that t reaches 239, with rare keys
 // and a hold that flips every 64 cycles).
 initial begin
  repeat(3)@(negedge clk);rst=0;
  for(i=0;i<CYCLES;i=i+1)begin @(negedge clk);#1;
   epoch=i/EPOCH;pos=i%EPOCH;
   if(epoch%3==0)begin
    pause=$random(seed);restart=$random(seed);enable=$random(seed);scene_ready=$random(seed);
    key_next=($random(seed)&7)==0;key_mode=($random(seed)&15)==0;key_speed=($random(seed)&15)==0;
    sample_tick=$random(seed);audio_running=$random(seed);frame_start=$random(seed);muted=$random(seed);
    auto_enable=$random(seed);request_ready=$random(seed);picture_done=$random(seed);picture_failed=($random(seed)&15)==0;
    transition_idle=$random(seed);audio_ready=$random(seed);ui_play=$random(seed);select_request=($random(seed)&15)==0;select_stage=$random(seed);
    rst=(i%997==996);
   end else begin
    pause=($random(seed)&65535)==0;restart=($random(seed)&131071)==0;enable=($random(seed)&16383)!=0;scene_ready=($random(seed)&16383)!=0;
    key_next=($random(seed)&65535)==0;key_mode=($random(seed)&65535)==0;
    key_speed=pos<3000 && ($random(seed)&255)==0;
    sample_tick=($random(seed)&15)!=0;audio_running=($random(seed)&16383)!=0;frame_start=($random(seed)&3)==0;muted=($random(seed)&2047)==0;
    auto_enable=($random(seed)&7)!=0;request_ready=($random(seed)&3)!=0;picture_done=($random(seed)&3)!=0;picture_failed=($random(seed)&255)==0;
    transition_idle=($random(seed)&3)!=0;audio_ready=($random(seed)&3)!=0;ui_play=($random(seed)&7)!=0;
    select_request=($random(seed)&8191)==0;select_stage=$random(seed);
    rst=(pos==0);
   end
   inject_t=(epoch%3!=0) && pos>3000 && (pos%4000)==3999;
   if(i%64==0)hold=$random(seed);
   hold_mode=(epoch%7)!=5;   // some epochs: the hold input stays low (NARRATION_GATE off behaviour)
  end
  if(withheld<100 || auto_moves<100)$fatal(1,"coverage: AUTO withheld %0d times, taken %0d times",withheld,auto_moves);
  $display("PASS narration lockstep: %0d cycles x 16 configurations, outputs and internal state; AUTO withheld %0d / taken %0d (config 11)",CYCLES,withheld,auto_moves);$finish;
 end
endmodule

module tb_narration_directed;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,en=0,ready=0,kn=0,km=0,ks=0,tick=0,running=1,frame=0,muted=0;
 reg req_ready=0,pdone=0,failed=0,idle=1,aready=0,aut=0,hold=0;
 wire [1:0] stage,speed,alert,target,astage;wire warn,req,fade,layer,ar,ascene;wire [7:0] t;
 scenario_fsm #(.NARRATION_GATE(1)) dut(.clk(clk),.rst(rst),.pause(1'b0),.restart(1'b0),.narration_hold(hold),
  .enable(en),.scene_ready(ready),.key_next(kn),.key_mode(km),.key_speed(ks),
  .auto_enable(aut),.sample_tick(tick),.audio_running(running),.frame_start(frame),.muted(muted),.request_ready(req_ready),
  .picture_done(pdone),.picture_failed(failed),.transition_idle(idle),.audio_ready(aready),.ui_play(1'b1),
  .select_request(1'b0),.select_stage(2'd0),
  .stage(stage),.speed(speed),.warn_mode(warn),.t_now(t),.alert_level(alert),.stage_req(req),.requested_stage(target),
  .fade_mute(fade),.layer_enable(layer),.audio_request(ar),.audio_scene(ascene),.audio_stage(astage));
 task step;begin @(posedge clk);#1;end endtask
 task samples(input integer n);begin tick=1;repeat(n)step();tick=0;end endtask
 task frames_n(input integer n);integer k;begin for(k=0;k<n;k=k+1)begin frame=1;step();frame=0;step();end end endtask
 // Run one stage change (as in the existing scenario bench).
 task change(input integer expected,input bit w);
 begin
  step();if(!req || target!=expected)$fatal(1,"request %0d expected %0d",target,expected);
  repeat(7)step();req_ready=1;step();req_ready=0;idle=0;repeat(4)step();
  pdone=1;step();pdone=0;if(stage!=expected || warn!=w)$fatal(1,"commit state");
  repeat(8)step();idle=1;step();if(!ar)$fatal(1,"audio selection");
  repeat(8)step();aready=1;step();aready=0;step();if(fade || !layer)$fatal(1,"start");
 end endtask
 // Bring stage 0 up at the given speed (0:1x 1:2x 2:4x) and run t to 239.
 task start_stage(input integer spd);
 begin
  hold=0;aut=0;kn=0;repeat(3)step();rst=0;en=1;repeat(5)step();ready=1;change(0,0);
  repeat(spd)begin ks=1;step();ks=0;step();end
  if(speed!=spd)$fatal(1,"speed %0d",speed);
  samples(1600*245/(1<<spd));if(t!=239)$fatal(1,"t %0d at saturation",t);
 end endtask
 integer j;
 initial begin
  // 1) 2x with the narration still playing: AUTO must hold, however many frames pass.
  start_stage(1);hold=1;aut=1;frames_n(600);
  if(req || stage!=0)$fatal(1,"AUTO left the stage while the narration played");
  //    The key still works during the hold.
  kn=1;step();kn=0;step();if(!req)$fatal(1,"key blocked by hold");
  change(1,0);
  // 2) After the narration finishes AUTO goes on within a frame, once.
  samples(800*245/1);if(t!=239)$fatal(1,"t");
  hold=1;aut=1;frames_n(300);if(req)$fatal(1,"AUTO ignored the hold at stage 1");
  hold=0;frame=1;step();frame=0;step();
  if(!req)$fatal(1,"AUTO did not follow the end of the narration");
  change(2,0);
  // 3) No narration (hold low from the start of t=239): the old behaviour, AUTO after the terminal frame.
  samples(1600*245);hold=0;aut=1;frames_n(4);
  if(!req)$fatal(1,"AUTO without narration did not advance");
  change(3,0);
  // 4) Warning mode ignores AUTO and the hold alike.
  km=1;step();km=0;change(3,1);hold=1;frames_n(20);if(req || !warn)$fatal(1,"warning left");
  hold=0;frames_n(20);if(req || !warn)$fatal(1,"AUTO left the warning");
  $display("PASS narration directed: 2x AUTO held while the narration plays, key unaffected, one step after it ends, no-narration unchanged, warning unchanged");$finish;
 end
 initial begin #50000000;$fatal(1,"watchdog");end
endmodule
