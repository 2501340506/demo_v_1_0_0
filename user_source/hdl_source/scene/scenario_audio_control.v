// Stop/drain before changing bundled file selection. ready is held until the
// requester releases request; only a NEW session's accepted sample completes it.
module scenario_audio_control #(parameter PUBLICITY_ENABLE=0)(
 input clk,rst,request,request_scene,input [1:0] request_stage,
 input request_publicity,output reg selected_publicity,output reg [7:0] session_version,
 input stopped,sample_tick,session_enable,input [7:0] stream_error,
 input selected_found,output run_enable,output reg selected_scene,
 output reg [1:0] selected_stage,output reg ready
);
 localparam RUN=0,STOP=1,START=2,FIRST=3;
 reg [1:0] state,target_stage;
 reg target_scene,target_publicity,seen;
 reg [2:0] guard;
 assign run_enable=state!=STOP;
 always @(posedge clk or posedge rst)begin
  if(rst)begin state<=RUN;selected_scene<=0;selected_stage<=0;target_stage<=0;
   target_scene<=0;target_publicity<=0;selected_publicity<=0;session_version<=0;ready<=0;seen<=0;guard<=0;end
  else begin
   if(!request)begin ready<=0;seen<=0;end
   case(state)
    RUN:if(request && !seen)begin
     target_publicity<=PUBLICITY_ENABLE && request_publicity;target_scene<=request_scene;target_stage<=request_stage;seen<=1;ready<=0;state<=STOP;
    end
    STOP:if(stopped)begin selected_publicity<=target_publicity;session_version<=session_version+1'b1;selected_scene<=target_scene;selected_stage<=target_stage;guard<=0;state<=START;end
    START:if(guard==7)begin
     if(!selected_found || !session_enable)begin ready<=1;state<=RUN;end
     else state<=FIRST;
    end else guard<=guard+1'b1;
    FIRST:if(sample_tick || stream_error!=0 || !session_enable)begin ready<=1;state<=RUN;end
   endcase
  end
 end
endmodule
