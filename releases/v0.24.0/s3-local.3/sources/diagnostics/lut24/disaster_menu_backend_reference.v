// One owner for directory scans, preview writes and validation. Every exit
// waits for the outstanding reader/writer transaction; no physical SD reset.
module disaster_menu_backend_reference(
 input clk,rst,enter,confirm,cancel,input [1:0] focus,
 input invalidate,native_thumb,application_error,storage_busy,
 input parent_valid,input [31:0] parent_cluster,
 input [31:0] original_directory,input original_publicity,input [2:0] original_hazard,input [1:0] original_app,
 input reader_ready,scan_done,scan_error,input [3:0] mapped_valid,
 input [5:0] directory_valid,input [191:0] directory_clusters,
 input load_accept,load_result_valid,load_success,source_done,source_error,
 input application_busy,scene_ready,display_committed,display_off,
 output reg owner,output ready,discard,menu_write,
 output preview_mode,output reg fallback_thumbnail,rejected,
 output reg scan_start,output reg [31:0] directory,
 output reg publicity,output reg [2:0] hazard,
 output load_request,load_result_ready,output reg direct_load,
 output [1:0] load_index,write_slot,
 output reg [3:0] valid,
 output reg visible,force_scene,exit_done,resume,
 output reg [31:0] selected_directory,output reg [2:0] selected_hazard,output reg [1:0] force_target
);
 localparam IDLE=0,PARENT_ISSUE=1,SCAN_CLEAR=2,PARENT_WAIT=3,
  SCENE_ISSUE=4,SCENE_WAIT=5,WRITE_ISSUE=6,WRITE_WAIT=7,
  NEXT=10,HOLD=11,
  RESTORE_ISSUE=12,RESTORE_WAIT=13,RESTORE_DONE=14,
  CONFIRM=15,CONFIRM_WAIT=16,CONFIRM_DONE=17,PREFLIGHT_WAIT=18,EXIT_DISPLAY=19,
  CONFIRM_SCAN=20,CONFIRM_ISSUE=21,CONFIRM_CHECK=22,RECOVER=23,RECOVER_WAIT=24,ENTRY_CHECK=25,CONFIRM_SELECT=26;
 reg [4:0] state,after_clear;
 reg [1:0] scene,saved_app;
 reg [3:0] found;
 reg scene_found,entry_cache_hit,entry_parent_valid;
 reg [127:0] clusters;
 reg [31:0] saved_directory;
 reg saved_publicity,abort_pending,chosen,seen_busy,seen_commit;
 reg [2:0] saved_hazard;
 reg scan_fault;
 reg cache_complete;reg [31:0] cached_parent;
 reg [1:0] chosen_focus;
 // Only consume settled exit summaries while the application owns the
 // reader. One extra control cycle breaks reader/cache -> menu -> shared
 // resource enables; no transaction can be issued in these wait states.
 reg failed_idle_q,confirm_settled_q,recover_settled_q;
 always @(posedge clk or posedge rst)begin
  if(rst)begin failed_idle_q<=0;confirm_settled_q<=0;recover_settled_q<=0;end
  else begin
   failed_idle_q<=state==CONFIRM_WAIT && application_error && reader_ready && !storage_busy;
   confirm_settled_q<=state==CONFIRM_WAIT && seen_busy && seen_commit && !application_busy && scene_ready;
   recover_settled_q<=state==RECOVER_WAIT && seen_busy && ((application_error && reader_ready && !storage_busy) ||
    (seen_commit && !application_busy && (saved_app!=2 || scene_ready)));
  end
 end
 assign ready=state==HOLD;
 assign discard=1'b0;
 assign preview_mode=state!=CONFIRM_SCAN && state!=CONFIRM_ISSUE && state!=CONFIRM_CHECK &&
  !(state==SCAN_CLEAR && after_clear==CONFIRM_CHECK) && state!=RESTORE_ISSUE && state!=RESTORE_WAIT &&
  state!=RESTORE_DONE && !(state==SCAN_CLEAR && after_clear==RESTORE_DONE);
 assign menu_write=state==WRITE_ISSUE || state==WRITE_WAIT;
 assign load_request=state==WRITE_ISSUE && !abort_pending && !scan_fault && !scan_error && mapped_valid[0];
 assign load_result_ready=state==WRITE_WAIT;
 assign load_index=2'd0;
 assign write_slot=scene;
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   state<=IDLE;owner<=0;after_clear<=IDLE;scene<=0;saved_app<=0;force_target<=2;found<=0;clusters<=0;
   saved_directory<=0;saved_publicity<=0;saved_hazard<=0;abort_pending<=0;
   chosen<=0;seen_busy<=0;seen_commit<=0;scan_fault<=0;
   scan_start<=0;directory<=0;publicity<=0;hazard<=0;direct_load<=0;
   valid<=0;visible<=0;force_scene<=0;exit_done<=0;resume<=0;
   selected_directory<=0;selected_hazard<=0;
   cache_complete<=0;cached_parent<=0;chosen_focus<=0;scene_found<=0;entry_cache_hit<=0;entry_parent_valid<=0;fallback_thumbnail<=0;rejected<=0;
  end else begin
   scan_start<=0;direct_load<=0;force_scene<=0;exit_done<=0;resume<=0;rejected<=0;
   if(invalidate)begin cache_complete<=0;valid<=0;end
   if(scan_start)scan_fault<=0;
   else if(scan_error)scan_fault<=1;
   if(cancel && state!=IDLE)abort_pending<=1;
   case(state)
    IDLE:if(enter)begin
     owner<=1;
     saved_directory<=original_directory;saved_publicity<=original_publicity;saved_hazard<=original_hazard;
     saved_app<=original_app;force_target<=2;
     abort_pending<=0;chosen<=0;visible<=1;scene<=0;fallback_thumbnail<=0;
     directory<=parent_cluster;publicity<=0;hazard<=0;
     // Latch the entry decision before driving state and wide register enables.
     entry_cache_hit<=cache_complete && cached_parent==parent_cluster && parent_valid;
     entry_parent_valid<=parent_valid;state<=ENTRY_CHECK;
    end
    ENTRY_CHECK:begin
     if(entry_cache_hit)state<=HOLD;
     else begin valid<=0;cache_complete<=0;cached_parent<=directory;state<=entry_parent_valid?PARENT_ISSUE:HOLD;end
    end
    PARENT_ISSUE:if(reader_ready)begin scan_start<=1;after_clear<=PARENT_WAIT;state<=SCAN_CLEAR;end
    SCAN_CLEAR:if(!scan_done && !scan_start)state<=after_clear;
    PARENT_WAIT:if(scan_done)begin
     scene_found<=!scan_fault && !scan_error && directory_valid[2];
     found<=(scan_fault || scan_error)?4'd0:directory_valid[5:2];clusters<=directory_clusters[191:64];state<=SCENE_ISSUE;
    end
    SCENE_ISSUE:begin
     if(abort_pending)state<=RESTORE_ISSUE;
     else if(!scene_found)state<=NEXT;
     else if(reader_ready)begin
      fallback_thumbnail<=0;
      directory<=clusters[scene*32+:32];hazard<={1'b0,scene}+3'd1;
      state<=SCENE_WAIT;
     end
    end
    SCENE_WAIT:if(reader_ready && !scan_start)begin
     scan_start<=1;after_clear<=PREFLIGHT_WAIT;state<=SCAN_CLEAR;
    end
    PREFLIGHT_WAIT:if(scan_done)state<=WRITE_ISSUE;
    WRITE_ISSUE:begin
     if(scan_fault || scan_error || !mapped_valid[0])state<=NEXT;
     else if(abort_pending)state<=RESTORE_ISSUE;
     else if(load_accept)state<=WRITE_WAIT;
    end
    WRITE_WAIT:if(load_result_valid)begin
     if(load_success)begin valid[scene]<=1;state<=NEXT;end
     else if(native_thumb && !fallback_thumbnail)begin fallback_thumbnail<=1;state<=SCENE_WAIT;end
     else state<=NEXT;
    end
    NEXT:if(abort_pending)state<=RESTORE_ISSUE;
     else if(scene==3)begin cache_complete<=1;state<=HOLD;end
     else begin scene<=scene+1'b1;scene_found<=found[scene+2'd1];state<=SCENE_ISSUE;end
    HOLD:if(abort_pending || cancel)state<=chosen?RECOVER:RESTORE_ISSUE;
     else if(confirm && valid[focus])begin
      chosen_focus<=focus;state<=CONFIRM_SELECT;
     end
    // Snapshot the accepted focus before driving the wide selection enables.
    CONFIRM_SELECT:begin
     selected_directory<=clusters[chosen_focus*32+:32];selected_hazard<={1'b0,chosen_focus}+3'd1;
     state<=CONFIRM_SCAN;
    end
    CONFIRM_SCAN:if(reader_ready)begin
     if(abort_pending)state<=chosen?RECOVER:RESTORE_ISSUE;
     else begin directory<=selected_directory;hazard<=selected_hazard;publicity<=0;state<=CONFIRM_ISSUE;end
    end
    CONFIRM_ISSUE:if(reader_ready)begin scan_start<=1;after_clear<=CONFIRM_CHECK;state<=SCAN_CLEAR;end
    CONFIRM_CHECK:if(scan_done)begin
     if(abort_pending)state<=chosen?RECOVER:RESTORE_ISSUE;
     else if(scan_fault || scan_error || mapped_valid!=15)begin valid[chosen_focus]<=0;rejected<=1;state<=HOLD;end
     else begin chosen<=1;state<=CONFIRM;end
    end
    RESTORE_ISSUE:if(reader_ready)begin
     directory<=saved_directory;publicity<=saved_publicity;hazard<=saved_hazard;
     state<=RESTORE_WAIT;
    end
    RESTORE_WAIT:if(reader_ready)begin scan_start<=1;after_clear<=RESTORE_DONE;state<=SCAN_CLEAR;end
    RESTORE_DONE:if(scan_done)begin visible<=0;state<=EXIT_DISPLAY;end
    CONFIRM:begin owner<=0;force_target<=2;force_scene<=1;seen_busy<=0;seen_commit<=0;state<=CONFIRM_WAIT;end
    CONFIRM_WAIT:begin
     if(application_busy)seen_busy<=1;
     if(display_committed)seen_commit<=1;
     if(failed_idle_q)begin
      owner<=1;valid[chosen_focus]<=0;rejected<=1;state<=abort_pending?RECOVER:HOLD;
     end else if(confirm_settled_q)state<=abort_pending?RECOVER:CONFIRM_DONE;
    end
    // A selected load invalidates the old cache epoch. Cancellation after
    // that point must reload the saved application, including from ERROR.
    RECOVER:if(reader_ready && !storage_busy)begin
     selected_directory<=saved_directory;selected_hazard<=saved_hazard;force_target<=saved_app;
     owner<=0;state<=RECOVER_WAIT;seen_busy<=0;seen_commit<=0;force_scene<=1;
    end
    RECOVER_WAIT:begin
     if(application_busy)seen_busy<=1;
     if(display_committed)seen_commit<=1;
     if(recover_settled_q)begin
      chosen<=0;owner<=1;visible<=0;state<=EXIT_DISPLAY;
     end
    end
    CONFIRM_DONE:begin owner<=1;visible<=0;state<=EXIT_DISPLAY;end
    EXIT_DISPLAY:if(display_off)begin owner<=0;resume<=!chosen;exit_done<=1;state<=IDLE;end
    default:begin owner<=0;state<=IDLE;end
   endcase
  end
 end
endmodule
