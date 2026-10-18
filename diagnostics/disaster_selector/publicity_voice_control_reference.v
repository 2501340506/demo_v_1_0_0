module publicity_voice_control_reference #(parameter MIN_FRAMES=300, MENU_ENABLE=0)(
 input pause,restart,
 input clk,rst,enable,commit,input [1:0] commit_page,
 input page_pending,busy,ui_play,frame_tick,toggle_auto,manual,offer_ready,
 input audio_ready,selected_publicity,selected_found,input [7:0] stream_error,
 input [15:0] session_id,done_id,input done,
 output voice_request,output reg [1:0] page,output fade,
 output reg auto_enable,output auto_offer,auto_accept,output reg [2:0] status
);
 localparam OFF=0,WAIT=1,REQUEST=2,RUN=3;
 reg [1:0] state;
 reg [15:0] identity;
 reg [8:0] dwell;reg [1:0] tail_frames;
 reg advanced;
 wire terminal=status==0 || status==3 || status==4;
 assign voice_request=state==REQUEST;
 assign fade=enable && (page_pending || state==WAIT || state==REQUEST);
 // request_ready depends on the selected request_image in the shared cache.
 // Keep valid independent of ready; only acceptance can use that feedback.
 assign auto_offer=!(MENU_ENABLE && pause) && enable && state==RUN && auto_enable && ui_play && !busy && !page_pending &&
                   !manual && !toggle_auto && !advanced && dwell>=MIN_FRAMES && terminal && tail_frames==2;
 assign auto_accept=auto_offer && offer_ready;
 always @(posedge clk or posedge rst)begin
  if(rst)begin state<=OFF;page<=0;identity<=0;dwell<=0;tail_frames<=0;advanced<=0;auto_enable<=0;status<=1;end
  else if(MENU_ENABLE && restart && enable)begin state<=WAIT;status<=1;dwell<=0;tail_frames<=0;advanced<=0;end
  else if(MENU_ENABLE && pause)begin dwell<=0;tail_frames<=0;end
  else if(!enable)begin state<=OFF;dwell<=0;tail_frames<=0;advanced<=0;auto_enable<=0;status<=1;end
  else begin
   if(toggle_auto && !busy)auto_enable<=!auto_enable;
   if(!ui_play || busy || page_pending || state!=RUN)dwell<=0;
   else if(frame_tick && dwell<MIN_FRAMES)dwell<=dwell+1'b1;
   if(state==RUN && terminal && frame_tick && tail_frames<2)tail_frames<=tail_frames+1'b1;
   if(auto_accept)advanced<=1;
   if(commit)begin page<=commit_page;state<=WAIT;status<=1;dwell<=0;tail_frames<=0;advanced<=0;end
   else case(state)
    WAIT:if(!busy && !audio_ready)state<=REQUEST;
    REQUEST:if(audio_ready)begin
     identity<=session_id;state<=RUN;
     status<=stream_error!=0?3'd4:!selected_found?3'd0:3'd2;
    end
    RUN:if(selected_publicity && session_id==identity)begin
     if(stream_error!=0)status<=4;
     else if(done && done_id==identity && status==2)status<=3;
    end
    default:;
   endcase
  end
 end
endmodule
