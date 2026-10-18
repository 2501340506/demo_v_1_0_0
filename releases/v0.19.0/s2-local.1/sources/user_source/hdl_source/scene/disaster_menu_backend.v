// One owner for directory scans, preview writes and validation. Every exit
// waits for the outstanding reader/writer transaction; no physical SD reset.
module disaster_menu_backend(
 input clk,rst,enter,confirm,cancel,input [1:0] focus,
 input parent_valid,input [31:0] parent_cluster,
 input [31:0] original_directory,input original_publicity,input [2:0] original_hazard,
 input reader_ready,scan_done,scan_error,input [3:0] mapped_valid,
 input [5:0] directory_valid,input [191:0] directory_clusters,
 input load_accept,load_result_valid,load_success,source_done,source_error,
 input application_busy,scene_ready,display_committed,display_off,
 output reg owner,output ready,discard,menu_write,
 output reg scan_start,output reg [31:0] directory,
 output reg publicity,output reg [2:0] hazard,
 output load_request,load_result_ready,output reg direct_load,
 output [1:0] load_index,write_slot,
 output reg [3:0] valid,
 output reg visible,force_scene,exit_done,resume,
 output reg [31:0] selected_directory,output reg [2:0] selected_hazard
);
 localparam IDLE=0,PARENT_ISSUE=1,SCAN_CLEAR=2,PARENT_WAIT=3,
  SCENE_ISSUE=4,SCENE_WAIT=5,WRITE_ISSUE=6,WRITE_WAIT=7,
  VERIFY_ISSUE=8,VERIFY_WAIT=9,NEXT=10,HOLD=11,
  RESTORE_ISSUE=12,RESTORE_WAIT=13,RESTORE_DONE=14,
  CONFIRM=15,CONFIRM_WAIT=16,CONFIRM_DONE=17,PREFLIGHT_WAIT=18,EXIT_DISPLAY=19;
 reg [4:0] state,after_clear;
 reg [1:0] scene,stage;
 reg [3:0] found;
 reg [127:0] clusters;
 reg [31:0] saved_directory;
 reg saved_publicity,abort_pending,chosen,seen_busy,seen_commit;
 reg [2:0] saved_hazard;
 reg scan_fault;
 assign ready=state==HOLD;
 assign discard=state==VERIFY_ISSUE || state==VERIFY_WAIT;
 assign menu_write=state==WRITE_ISSUE || state==WRITE_WAIT;
 assign load_request=state==WRITE_ISSUE && !abort_pending && !scan_fault && !scan_error && mapped_valid==15;
 assign load_result_ready=state==WRITE_WAIT;
 assign load_index=discard?stage:2'd0;
 assign write_slot=scene;
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   state<=IDLE;owner<=0;after_clear<=IDLE;scene<=0;stage<=0;found<=0;clusters<=0;
   saved_directory<=0;saved_publicity<=0;saved_hazard<=0;abort_pending<=0;
   chosen<=0;seen_busy<=0;seen_commit<=0;scan_fault<=0;
   scan_start<=0;directory<=0;publicity<=0;hazard<=0;direct_load<=0;
   valid<=0;visible<=0;force_scene<=0;exit_done<=0;resume<=0;
   selected_directory<=0;selected_hazard<=0;
  end else begin
   scan_start<=0;direct_load<=0;force_scene<=0;exit_done<=0;resume<=0;
   if(scan_start)scan_fault<=0;
   else if(scan_error)scan_fault<=1;
   if(cancel && state!=IDLE)abort_pending<=1;
   case(state)
    IDLE:if(enter)begin
     owner<=1;
     saved_directory<=original_directory;saved_publicity<=original_publicity;saved_hazard<=original_hazard;
     abort_pending<=0;chosen<=0;valid<=0;visible<=1;scene<=0;
     directory<=parent_cluster;publicity<=0;hazard<=0;
     state<=parent_valid?PARENT_ISSUE:HOLD;
    end
    PARENT_ISSUE:if(reader_ready)begin scan_start<=1;after_clear<=PARENT_WAIT;state<=SCAN_CLEAR;end
    SCAN_CLEAR:if(!scan_done && !scan_start)state<=after_clear;
    PARENT_WAIT:if(scan_done)begin
     found<=(scan_fault || scan_error)?4'd0:directory_valid[5:2];clusters<=directory_clusters[191:64];state<=SCENE_ISSUE;
    end
    SCENE_ISSUE:begin
     if(abort_pending)state<=RESTORE_ISSUE;
     else if(!found[scene])state<=NEXT;
     else if(reader_ready)begin
      directory<=clusters[scene*32+:32];hazard<={1'b0,scene}+3'd1;
      state<=SCENE_WAIT;
     end
    end
    SCENE_WAIT:if(reader_ready && !scan_start)begin
     scan_start<=1;after_clear<=PREFLIGHT_WAIT;state<=SCAN_CLEAR;
    end
    PREFLIGHT_WAIT:if(scan_done)state<=WRITE_ISSUE;
    WRITE_ISSUE:begin
     if(scan_fault || scan_error || mapped_valid!=15)state<=NEXT;
     else if(abort_pending)state<=RESTORE_ISSUE;
     else if(load_accept)state<=WRITE_WAIT;
    end
    WRITE_WAIT:if(load_result_valid)begin
     if(!load_success)state<=NEXT;
     else begin stage<=1;state<=VERIFY_ISSUE;end
    end
    VERIFY_ISSUE:if(reader_ready)begin
     if(abort_pending)state<=RESTORE_ISSUE;
     else begin direct_load<=1;state<=VERIFY_WAIT;end
    end
    VERIFY_WAIT:if(source_error)state<=NEXT;
     else if(source_done)begin
      if(stage==3)begin valid[scene]<=1;state<=NEXT;end
      else begin stage<=stage+1'b1;state<=VERIFY_ISSUE;end
     end
    NEXT:if(abort_pending)state<=RESTORE_ISSUE;
     else if(scene==3)state<=HOLD;
     else begin scene<=scene+1'b1;state<=SCENE_ISSUE;end
    HOLD:if(abort_pending || cancel)state<=RESTORE_ISSUE;
     else if(confirm && valid[focus])begin
      selected_directory<=clusters[focus*32+:32];selected_hazard<={1'b0,focus}+3'd1;
      chosen<=1;state<=CONFIRM;
     end
    RESTORE_ISSUE:if(reader_ready)begin
     directory<=saved_directory;publicity<=saved_publicity;hazard<=saved_hazard;
     state<=RESTORE_WAIT;
    end
    RESTORE_WAIT:if(reader_ready)begin scan_start<=1;after_clear<=RESTORE_DONE;state<=SCAN_CLEAR;end
    RESTORE_DONE:if(scan_done)begin visible<=0;state<=EXIT_DISPLAY;end
    CONFIRM:begin owner<=0;force_scene<=1;seen_busy<=0;seen_commit<=0;state<=CONFIRM_WAIT;end
    CONFIRM_WAIT:begin
     if(application_busy)seen_busy<=1;
     if(display_committed)seen_commit<=1;
     if(seen_busy && seen_commit && !application_busy && scene_ready)state<=CONFIRM_DONE;
    end
    CONFIRM_DONE:begin owner<=1;visible<=0;state<=EXIT_DISPLAY;end
    EXIT_DISPLAY:if(display_off)begin owner<=0;resume<=!chosen;exit_done<=1;state<=IDLE;end
    default:begin owner<=0;state<=IDLE;end
   endcase
  end
 end
endmodule
