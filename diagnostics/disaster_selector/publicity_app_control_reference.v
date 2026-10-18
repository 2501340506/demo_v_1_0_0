// Pre-optimization sequential reference from S2 TD attempt09.
module publicity_app_control_reference #(parameter MENU_ENABLE=0)(
 input force_request,
 input clk,rst,toggle_request,retry_request,rescan_request,
 input pic_complete,pic_any,edu_complete,scan_valid,scan_success,
 input [1:0] scan_application,
 input idle,black,muted,audio_stopped,committed,failed,scene_ready,frame_tick,fade_busy,
 output reg [1:0] app,target,
 output busy,error,output reg rejected,physical,reload,
 output stop_audio,scene_enable,fade_request,release_fade
);
 localparam BOOT=0,RUN=1,WAIT_IDLE=2,FADE=3,STOP=4,LOAD=5,FIRST=6,READY=7,FADE_IN=8,ERROR=9;
 reg [3:0] state;
 reg [2:0] settle;
 wire [1:0] alternate=(state==ERROR?target:app)==2 ? (edu_complete?2'd1:2'd0) : 2'd2;
 wire alternate_available=alternate==2?pic_complete:alternate==1?edu_complete:pic_any;
 assign busy=state!=RUN;
 assign error=state==ERROR;
 assign stop_audio=state!=RUN && state!=READY && state!=FADE_IN && state!=WAIT_IDLE;
 assign scene_enable=app==2 && (state==RUN || state==WAIT_IDLE || state==READY || state==FADE_IN);
 assign fade_request=state!=RUN && state!=WAIT_IDLE && state!=FADE_IN;
 assign release_fade=state==FADE_IN;
 always @(posedge clk or posedge rst)begin
  if(rst)begin state<=BOOT;app<=0;target<=0;physical<=1;reload<=0;rejected<=0;settle<=0;end
  else begin
   reload<=0;
   case(state)
    BOOT:if(scan_valid)begin
     target<=scan_application;
     state<=scan_success?FIRST:ERROR;
    end
    RUN:begin
     if(MENU_ENABLE && force_request)begin target<=2;physical<=0;rejected<=0;state<=WAIT_IDLE;end
     else if(rescan_request)begin physical<=1;rejected<=0;state<=WAIT_IDLE;end
     else if(toggle_request)begin
      if(alternate_available)begin target<=alternate;physical<=0;rejected<=0;state<=WAIT_IDLE;end
      else rejected<=1;
     end
    end
    WAIT_IDLE:if(idle)state<=FADE;
    FADE:if(black && muted)state<=STOP;
    STOP:if(audio_stopped && idle)begin reload<=1;state<=LOAD;end
    LOAD:if(scan_valid)begin
     if(physical)target<=scan_application;
     state<=scan_success?FIRST:ERROR;
    end
    FIRST:begin
     if(failed)state<=ERROR;
     else if(committed)begin app<=target;settle<=0;state<=READY;end
    end
    READY:begin
     // Boot may load faster than the sample-counted master-volume ramp.
     // Keep the publicity first frame black until accepted PCM is silent.
     if((target!=2 || scene_ready) && (target!=1 || muted))begin
      // Two actual frame boundaries let identity and scenario mailboxes settle
      // before fade-in; SD clock cycles do not establish a pixel-frame boundary.
      if(frame_tick)begin
       if(settle==1)state<=FADE_IN;else settle<=settle+1'b1;
      end
     end else settle<=0;
     if(failed)state<=ERROR;
    end
    FADE_IN:if(!fade_busy)state<=RUN;
    ERROR:begin
     if(MENU_ENABLE && force_request)begin target<=2;physical<=0;rejected<=0;state<=STOP;end
     else if(rescan_request)begin physical<=1;state<=STOP;rejected<=0;end
     else if(toggle_request && alternate_available)begin target<=alternate;physical<=0;state<=STOP;rejected<=0;end
     else if(retry_request)begin physical<=0;state<=STOP;rejected<=0;end
    end
    default:state<=ERROR;
   endcase
  end
 end
endmodule
