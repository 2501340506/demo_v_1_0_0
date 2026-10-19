module publicity_app_control_reference #(parameter MENU_ENABLE=0,FAST_BOOT=0)(
 input force_request,input [1:0] force_target,
 input clk,rst,toggle_request,retry_request,rescan_request,
 input pic_complete,pic_any,edu_complete,scan_valid,scan_success,
 input [1:0] scan_application,
 input idle,black,muted,audio_stopped,committed,failed,scene_ready,frame_tick,fade_busy,
 output reg [1:0] app,target,
 output reg busy,output error,output reg rejected,physical,reload,
 output reg stop_audio,scene_enable,output fade_request,release_fade,initial_display
);
 localparam BOOT=0,RUN=1,WAIT_IDLE=2,FADE=3,STOP=4,LOAD=5,FIRST=6,READY=7,FADE_IN=8,ERROR=9;
 reg [3:0] state;
 reg [2:0] settle;
 reg boot_direct;
 assign initial_display=boot_direct;
 reg [3:0] next_state;
 reg [1:0] next_app,next_target;
 reg [2:0] next_settle;
 reg next_physical,next_reload,next_rejected;
 wire [1:0] alternate=(state==ERROR?target:app)==2 ? (edu_complete?2'd1:2'd0) : 2'd2;
 wire alternate_available=alternate==2?pic_complete:alternate==1?edu_complete:pic_any;
 assign error=state==ERROR;
 assign fade_request=!boot_direct && state!=RUN && state!=WAIT_IDLE && state!=FADE_IN;
 assign release_fade=state==FADE_IN;
 // Decode the *next* state into registered boundary controls. Their cycle
 // semantics match the state decode, without a decode LUT on high-fanout
 // application -> cache/voice/scenario timing paths.
 always @* begin
  next_state=state;next_app=app;next_target=target;next_settle=settle;
  next_physical=physical;next_reload=0;next_rejected=rejected;
  case(state)
   BOOT:if(scan_valid)begin
    next_target=scan_application;next_state=scan_success?FIRST:ERROR;
   end
   RUN:begin
    if(MENU_ENABLE && force_request)begin next_target=force_target;next_physical=0;next_rejected=0;next_state=WAIT_IDLE;end
    else if(rescan_request)begin next_physical=1;next_rejected=0;next_state=WAIT_IDLE;end
    else if(toggle_request)begin
     if(alternate_available)begin next_target=alternate;next_physical=0;next_rejected=0;next_state=WAIT_IDLE;end
     else next_rejected=1;
    end
   end
   WAIT_IDLE:if(idle)next_state=FADE;
   FADE:if(black && muted)next_state=STOP;
   STOP:if(audio_stopped && idle)begin next_reload=1;next_state=LOAD;end
   LOAD:if(scan_valid)begin
    if(physical)next_target=scan_application;
    next_state=scan_success?FIRST:ERROR;
   end
   FIRST:begin
    if(failed)next_state=ERROR;
    else if(committed)begin next_app=target;next_settle=0;next_state=boot_direct?RUN:READY;end
   end
   READY:begin
    // Two actual frame boundaries settle identity/scenario mailboxes.
    if((target!=2 || scene_ready) && (target!=1 || muted))begin
     if(frame_tick)begin
      if(settle==1)next_state=FADE_IN;else next_settle=settle+1'b1;
     end
    end else next_settle=0;
    if(failed)next_state=ERROR;
   end
   FADE_IN:if(!fade_busy)next_state=RUN;
   ERROR:begin
    if(MENU_ENABLE && force_request)begin next_target=force_target;next_physical=0;next_rejected=0;next_state=STOP;end
    else if(rescan_request)begin next_physical=1;next_state=STOP;next_rejected=0;end
    else if(toggle_request && alternate_available)begin next_target=alternate;next_physical=0;next_state=STOP;next_rejected=0;end
    else if(retry_request)begin next_physical=0;next_state=STOP;next_rejected=0;end
   end
   default:next_state=ERROR;
  endcase
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   state<=BOOT;app<=0;target<=0;physical<=1;reload<=0;rejected<=0;settle<=0;
   busy<=1;stop_audio<=1;scene_enable<=0;boot_direct<=FAST_BOOT;
  end else begin
   state<=next_state;app<=next_app;target<=next_target;physical<=next_physical;
   reload<=next_reload;rejected<=next_rejected;settle<=next_settle;
   if(next_state==RUN || next_state==ERROR)boot_direct<=0;
   busy<=next_state!=RUN;
   stop_audio<=next_state!=RUN && next_state!=READY && next_state!=FADE_IN && next_state!=WAIT_IDLE;
   scene_enable<=next_app==2 && (next_state==RUN || next_state==WAIT_IDLE || next_state==READY || next_state==FADE_IN);
  end
 end
endmodule
