// SD-domain scene controller. PCM ticks are lossless playback events from CDC.
module scenario_fsm_reference #(parameter PRESERVE_SPEED=0, UI_GATE=0, PREVIEW_SELECT=0, MENU_ENABLE=0)(
 input pause,restart,
 input clk,rst,enable,scene_ready,key_next,key_mode,key_speed,
 input sample_tick,audio_running,frame_start,muted,auto_enable,
 input request_ready,picture_done,picture_failed,transition_idle,audio_ready,
 input ui_play,
 input select_request,input [1:0] select_stage,output select_ready,
 output reg [1:0] stage,speed,output reg warn_mode,
 output reg [7:0] t_now,output [1:0] alert_level,
 output stage_req,output [1:0] requested_stage,
 output fade_mute,layer_enable,audio_request,audio_scene,
 output [1:0] audio_stage
);
 localparam OFF=0,RUN=1,PICTURE=2,TRANS=3,AUDIO=4,EXIT_FADE=5,EXIT_AUDIO=6;
 reg [2:0] state;
 reg [1:0] target;
 reg target_warn,sent,committed,half_frame;
 reg [10:0] samples;
 reg running_q,terminal_frame;
 wire [10:0] limit=speed==0?11'd1599:speed==1?11'd799:11'd399;
 assign select_ready=PREVIEW_SELECT && enable && scene_ready && state==RUN;
 assign stage_req=state==PICTURE && !sent;
 assign requested_stage=target;
 assign fade_mute=state!=OFF && state!=RUN;
 assign layer_enable=enable && scene_ready && committed;
 assign alert_level=warn_mode?2'd3:stage;
 assign audio_request=state==AUDIO || state==EXIT_AUDIO;
 assign audio_scene=state!=EXIT_AUDIO;
 assign audio_stage=stage;
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   state<=OFF;stage<=0;speed<=0;warn_mode<=0;t_now<=0;target<=0;
   target_warn<=0;sent<=0;committed<=0;half_frame<=0;samples<=0;running_q<=0;terminal_frame<=0;
  end else if(MENU_ENABLE && restart && state==RUN)begin
   target<=stage;target_warn<=warn_mode;sent<=0;t_now<=0;samples<=0;half_frame<=0;terminal_frame<=0;state<=PICTURE;
  end else if(!(MENU_ENABLE && pause && state==RUN))begin
   running_q<=audio_running;
   if(state!=RUN)begin samples<=0;half_frame<=0;terminal_frame<=0;end
   if(UI_GATE && !ui_play)terminal_frame<=0;
   if(!scene_ready && state!=OFF && state!=EXIT_FADE && state!=EXIT_AUDIO)state<=EXIT_FADE;
   else case(state)
    OFF:begin
     stage<=0;if(!PRESERVE_SPEED)speed<=0;warn_mode<=0;t_now<=0;committed<=0;
     if(enable && scene_ready)begin target<=0;target_warn<=0;sent<=0;state<=PICTURE;end
    end
    RUN:begin
     if(!enable || !scene_ready)state<=EXIT_FADE;
     else if(select_ready && select_request)begin
      target<=select_stage;target_warn<=0;sent<=0;state<=PICTURE;
     end else if(key_mode || (!warn_mode && (key_next || (auto_enable && (!UI_GATE || ui_play) && terminal_frame && frame_start))))begin
      target<=key_mode?(warn_mode?2'd0:2'd3):stage+2'd1;
      target_warn<=key_mode?!warn_mode:warn_mode;sent<=0;state<=PICTURE;
     end else if(key_speed)begin speed<=speed==2?2'd0:speed+2'd1;samples<=0;half_frame<=0;end
     else if(warn_mode)t_now<=239;
     else if(t_now<239)begin
      if(audio_running!=running_q)begin samples<=0;half_frame<=0;end
      else if(audio_running)begin
       half_frame<=0;
       if(sample_tick)begin
        if(samples>=limit)begin samples<=0;t_now<=t_now+1'b1;end
        else samples<=samples+1'b1;
       end
      end else begin
       samples<=0;
       if(frame_start)begin half_frame<=!half_frame;if(half_frame)t_now<=t_now+1'b1;end
      end
     end
     // Two frame boundaries after saturation guarantee one whole terminal
     // frame can be shown even when t crosses the pixel-domain mailbox late.
     else if(frame_start && (!UI_GATE || ui_play))terminal_frame<=1;
    end
    PICTURE:begin
     if(stage_req && request_ready)sent<=1;
     if(sent && picture_done)begin
      stage<=target;warn_mode<=target_warn;t_now<=target_warn?8'd239:8'd0;
      committed<=1;state<=TRANS;
     end else if(sent && picture_failed)state<=TRANS;
    end
    TRANS:if(transition_idle)state<=AUDIO;
    AUDIO:if(audio_ready)state<=RUN;
    EXIT_FADE:if(muted || !audio_running)state<=EXIT_AUDIO;
    EXIT_AUDIO:if(audio_ready)state<=OFF;
    default:state<=OFF;
   endcase
  end
 end
endmodule
