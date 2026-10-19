`timescale 1ns/1ps
module tb_scenario_equivalence;
reg clk=0,rst=1;always #5 clk=~clk;
reg pause=0;
reg restart=0;
reg enable=0;
reg scene_ready=0;
reg key_next=0;
reg key_mode=0;
reg key_speed=0;
reg sample_tick=0;
reg audio_running=0;
reg frame_start=0;
reg muted=0;
reg auto_enable=0;
reg request_ready=0;
reg picture_done=0;
reg picture_failed=0;
reg transition_idle=0;
reg audio_ready=0;
reg ui_play=0;
reg select_request=0;
reg [1:0] select_stage=0;
genvar g;generate for(g=0;g<16;g=g+1)begin:pair
wire select_ready[0:1];
wire [1:0] stage[0:1];
wire [1:0] speed[0:1];
wire warn_mode[0:1];
wire [7:0] t_now[0:1];
wire [1:0] alert_level[0:1];
wire stage_req[0:1];
wire [1:0] requested_stage[0:1];
wire fade_mute[0:1];
wire layer_enable[0:1];
wire audio_request[0:1];
wire audio_scene[0:1];
wire [1:0] audio_stage[0:1];
scenario_fsm #(.PRESERVE_SPEED(g%2),.UI_GATE((g/2)%2),.PREVIEW_SELECT((g/4)%2),.MENU_ENABLE(g/8)) dut(.clk(clk),.rst(rst),.pause(pause),.restart(restart),.enable(enable),.scene_ready(scene_ready),.key_next(key_next),.key_mode(key_mode),.key_speed(key_speed),.sample_tick(sample_tick),.audio_running(audio_running),.frame_start(frame_start),.muted(muted),.auto_enable(auto_enable),.request_ready(request_ready),.picture_done(picture_done),.picture_failed(picture_failed),.transition_idle(transition_idle),.audio_ready(audio_ready),.ui_play(ui_play),.select_request(select_request),.select_stage(select_stage),.select_ready(select_ready[0]),.stage(stage[0]),.speed(speed[0]),.warn_mode(warn_mode[0]),.t_now(t_now[0]),.alert_level(alert_level[0]),.stage_req(stage_req[0]),.requested_stage(requested_stage[0]),.fade_mute(fade_mute[0]),.layer_enable(layer_enable[0]),.audio_request(audio_request[0]),.audio_scene(audio_scene[0]),.audio_stage(audio_stage[0]));
scenario_fsm_reference #(.PRESERVE_SPEED(g%2),.UI_GATE((g/2)%2),.PREVIEW_SELECT((g/4)%2),.MENU_ENABLE(g/8)) ref_dut(.clk(clk),.rst(rst),.pause(pause),.restart(restart),.enable(enable),.scene_ready(scene_ready),.key_next(key_next),.key_mode(key_mode),.key_speed(key_speed),.sample_tick(sample_tick),.audio_running(audio_running),.frame_start(frame_start),.muted(muted),.auto_enable(auto_enable),.request_ready(request_ready),.picture_done(picture_done),.picture_failed(picture_failed),.transition_idle(transition_idle),.audio_ready(audio_ready),.ui_play(ui_play),.select_request(select_request),.select_stage(select_stage),.select_ready(select_ready[1]),.stage(stage[1]),.speed(speed[1]),.warn_mode(warn_mode[1]),.t_now(t_now[1]),.alert_level(alert_level[1]),.stage_req(stage_req[1]),.requested_stage(requested_stage[1]),.fade_mute(fade_mute[1]),.layer_enable(layer_enable[1]),.audio_request(audio_request[1]),.audio_scene(audio_scene[1]),.audio_stage(audio_stage[1]));
always @(negedge clk)if(!rst)begin
if(select_ready[0]!==select_ready[1])$fatal(1,"config=%d select_ready",g);
if(stage[0]!==stage[1])$fatal(1,"config=%d stage",g);
if(speed[0]!==speed[1])$fatal(1,"config=%d speed",g);
if(warn_mode[0]!==warn_mode[1])$fatal(1,"config=%d warn_mode",g);
if(t_now[0]!==t_now[1])$fatal(1,"config=%d t_now",g);
if(alert_level[0]!==alert_level[1])$fatal(1,"config=%d alert_level",g);
if(stage_req[0]!==stage_req[1])$fatal(1,"config=%d stage_req",g);
if(requested_stage[0]!==requested_stage[1])$fatal(1,"config=%d requested_stage",g);
if(fade_mute[0]!==fade_mute[1])$fatal(1,"config=%d fade_mute",g);
if(layer_enable[0]!==layer_enable[1])$fatal(1,"config=%d layer_enable",g);
if(audio_request[0]!==audio_request[1])$fatal(1,"config=%d audio_request",g);
if(audio_scene[0]!==audio_scene[1])$fatal(1,"config=%d audio_scene",g);
if(audio_stage[0]!==audio_stage[1])$fatal(1,"config=%d audio_stage",g);
if(dut.state!==ref_dut.state)$fatal(1,"config=%d state",g);
if(dut.samples!==ref_dut.samples)$fatal(1,"config=%d samples",g);
if(dut.running_q!==ref_dut.running_q)$fatal(1,"config=%d running_q",g);
if(dut.half_frame!==ref_dut.half_frame)$fatal(1,"config=%d half_frame",g);
if(dut.terminal_frame!==ref_dut.terminal_frame)$fatal(1,"config=%d terminal_frame",g);
if(dut.sent!==ref_dut.sent)$fatal(1,"config=%d sent",g);
if(dut.target!==ref_dut.target)$fatal(1,"config=%d target",g);
if(dut.target_warn!==ref_dut.target_warn)$fatal(1,"config=%d target_warn",g);
if(dut.committed!==ref_dut.committed)$fatal(1,"config=%d committed",g);
end
end endgenerate
integer i;integer seed=133714;initial begin
repeat(3)@(negedge clk);rst=0;
for(i=0;i<300000;i=i+1)begin @(negedge clk);#1;
pause=$random(seed);
restart=$random(seed);
enable=$random(seed);
scene_ready=$random(seed);
key_next=$random(seed);
key_mode=$random(seed);
key_speed=$random(seed);
sample_tick=$random(seed);
audio_running=$random(seed);
frame_start=$random(seed);
muted=$random(seed);
auto_enable=$random(seed);
request_ready=$random(seed);
picture_done=$random(seed);
picture_failed=$random(seed);
transition_idle=$random(seed);
audio_ready=$random(seed);
ui_play=$random(seed);
select_request=$random(seed);
select_stage=$random(seed);
rst=(i%997==996);
end
$display("PASS scenario equivalence 300000 cycles x 16 configurations, outputs and internal state");$finish;end
endmodule
