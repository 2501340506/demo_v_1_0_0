`timescale 1ns/1ps
module tb_scenario;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,en=0,ready=0,kn=0,km=0,ks=0,tick=0,running=1,frame=0,muted=0;
 reg req_ready=0,pdone=0,failed=0,idle=1,aready=0,aut=0;
 wire [1:0] stage,speed,alert,target,astage;wire warn,req,fade,layer,ar,ascene;wire [7:0] t;
 scenario_fsm dut(.clk(clk),.rst(rst),.enable(en),.scene_ready(ready),.key_next(kn),.key_mode(km),.key_speed(ks),
 .auto_enable(aut),.sample_tick(tick),.audio_running(running),.frame_start(frame),.muted(muted),.request_ready(req_ready),
 .picture_done(pdone),.picture_failed(failed),.transition_idle(idle),.audio_ready(aready),
 .stage(stage),.speed(speed),.warn_mode(warn),.t_now(t),.alert_level(alert),.stage_req(req),.requested_stage(target),
 .fade_mute(fade),.layer_enable(layer),.audio_request(ar),.audio_scene(ascene),.audio_stage(astage));
 task step;begin @(posedge clk);#1;end endtask
 task samples(input integer n);begin tick=1;repeat(n)step();tick=0;end endtask
 task change(input integer expected,input bit w);
 begin
  step();if(!req || !fade || target!=expected)$fatal(1,"request %d %b %d",target,fade,expected);
  repeat(7)step();if(!req)$fatal(1,"request not held");
  req_ready=1;step();req_ready=0;idle=0;repeat(4)step();
  if(req)$fatal(1,"request repeated");
  pdone=1;step();pdone=0;
  if(stage!=expected || warn!=w || t!=(w?239:0))$fatal(1,"commit state");
  repeat(8)step();if(ar || !fade)$fatal(1,"early audio request");
  idle=1;step();if(!ar || !ascene || astage!=expected)$fatal(1,"audio selection");
  repeat(8)step();if(!fade)$fatal(1,"unmuted before first sample");
  aready=1;step();aready=0;step();if(fade || !layer)$fatal(1,"start");
 end endtask
 integer s,j;
 initial begin
  repeat(3)step();rst=0;en=1;repeat(5)step();if(req || layer)$fatal(1,"before first scene");
  ready=1;change(0,0);
  for(s=0;s<3;s++)begin
   samples((1600>>s)-1);if(t!=0)$fatal(1,"early threshold speed%d t%d",s,t);
   samples(1);if(t!=1)$fatal(1,"threshold speed%d t%d",s,t);
   if(s<2)begin ks=1;step();ks=0;kn=1;step();kn=0;change((s+1),0);end
  end
  samples(400*245);if(t!=239)$fatal(1,"saturation");
  kn=1;step();kn=0;change(3,0);kn=1;step();kn=0;change(0,0);
  running=0;step();repeat(5)step();frame=1;step();frame=0;step();if(t!=0)$fatal(1,"fallback early");
  frame=1;step();frame=0;step();if(t!=1)$fatal(1,"fallback threshold");
  km=1;step();km=0;change(3,1);samples(8000);if(t!=239 || alert!=3)$fatal(1,"warning");
  km=1;step();km=0;change(0,0);
  // AUTO may never use the media player's old 3-second timer. With no
  // samples/frames it must hold; warning must never automatically leave.
  aut=1;repeat(100)step();if(req)$fatal(1,"auto before animation complete");
  for(j=0;j<478;j++)begin frame=1;step();frame=0;step();end
  if(t!=239 || req)$fatal(1,"auto early at terminal time");
  frame=1;step();frame=0;step();if(req)$fatal(1,"terminal frame must finish");
  aut=0;frame=1;step();frame=0;step();if(req)$fatal(1,"AUTO off must hold");
  aut=1;frame=1;step();frame=0;change(1,0);
  km=1;step();km=0;change(3,1);
  repeat(10)begin frame=1;step();frame=0;step();end
  if(req || !warn)$fatal(1,"AUTO exited warning");
  aut=0;km=1;step();km=0;change(0,0);
  en=0;step();step();if(!ar || ascene)$fatal(1,"exit restore BGM");aready=1;step();aready=0;step();
  if(layer || fade || stage!=0)$fatal(1,"exit reset");
  $display("PASS M6 scenario: 1/2/4x thresholds, manual saturation, AUTO complete animation and terminal frame, AUTO off holds, warning holds, requests/audio/exit");$finish;
 end
 initial begin #5000000;$fatal(1,"watchdog");end
endmodule
