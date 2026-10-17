`timescale 1ns/1ps
module tb_m5_scenario;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,en=0,ui=1,fr=0,select=0,ready=0,done=0,failed=0,tidle=0,ar=0,kn=0,km=0,ks=0;
 reg [1:0] target=0;wire sr,req,fade,aq,as,layer;wire [1:0] stage,speed,alert,requested,ast;wire warn;wire [7:0] t;
 scenario_fsm #(.PRESERVE_SPEED(1),.UI_GATE(1),.PREVIEW_SELECT(1)) dut(
 .clk(clk),.rst(rst),.enable(en),.scene_ready(1'b1),.key_next(kn),.key_mode(km),.key_speed(ks),
 .sample_tick(1'b0),.audio_running(1'b0),.frame_start(fr),.muted(1'b1),.auto_enable(1'b1),
 .request_ready(ready),.picture_done(done),.picture_failed(failed),.transition_idle(tidle),.audio_ready(ar),.ui_play(ui),
 .select_request(select),.select_stage(target),.select_ready(sr),.stage(stage),.speed(speed),.warn_mode(warn),.t_now(t),.alert_level(alert),
 .stage_req(req),.requested_stage(requested),.fade_mute(fade),.layer_enable(layer),.audio_request(aq),.audio_scene(as),.audio_stage(ast));
 task cyc(input integer n);repeat(n)@(negedge clk);endtask
 task frame;begin fr=1;cyc(1);fr=0;cyc(1);end endtask
 task finish_picture(input integer p,input integer w);
 begin
 wait(req);cyc(8);if(requested!=p || !req || !fade || sr)$fatal(1,"select request/backpressure");
 ready=1;cyc(1);ready=0;cyc(4);if(req || !fade)$fatal(1,"select duplicated acceptance");
 done=1;cyc(1);done=0;cyc(3);if(stage!=p || warn!=w || t!=(w?239:0))$fatal(1,"select commit");
 tidle=1;cyc(2);tidle=0;if(!aq || ast!=p || !as)$fatal(1,"select audio transaction");
 ar=1;cyc(1);ar=0;cyc(2);if(!sr || fade)$fatal(1,"select completion");
 end endtask
 initial begin
 cyc(4);rst=0;en=1;finish_picture(0,0);ks=1;cyc(1);ks=0;
 ui=0;repeat(500)frame();if(t!=239 || req || stage!=0)$fatal(1,"AUTO outside00 advanced");
 ui=1;frame();if(req)$fatal(1,"return00 skipped terminal frame");frame();finish_picture(1,0);
 ui=0;target=3;select=1;cyc(1);select=0;finish_picture(3,0);
 target=3;select=1;cyc(1);select=0;finish_picture(3,0); // same page restart
 km=1;cyc(1);km=0;finish_picture(3,1);
 target=2;select=1;cyc(1);select=0;finish_picture(2,0);
 target=1;select=1;cyc(1);select=0;wait(req);ready=1;cyc(1);ready=0;failed=1;cyc(1);failed=0;tidle=1;ar=1;cyc(4);tidle=0;ar=0;
 if(stage!=2 || warn || !sr)$fatal(1,"failed preview changed committed stage");
 en=0;ar=1;cyc(5);ar=0;en=1;finish_picture(0,0);if(speed!=1)$fatal(1,"speed lost across app");
 $display("PASS M5 scenario: non00 terminal gate/return frame, preview backpressure/same-page, warning exit, failed commit and preserved speed");$finish;
 end
 initial begin #100000;$fatal(1,"M5 scenario watchdog state=%d",dut.state);end
endmodule
