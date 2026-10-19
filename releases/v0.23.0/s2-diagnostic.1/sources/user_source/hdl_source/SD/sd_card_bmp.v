
module sd_card_bmp #(
    parameter integer CLK_FREQ_HZ       = 100_000_000,
    parameter [31:0]  SCAN_START_SECTOR = 32'd0,
    parameter [31:0]  SCAN_MAX_SECTOR   = 32'd131071,
    parameter [2:0]   SCAN_TARGET_COUNT = 3'd4,
    parameter integer AUTO_PLAY_MS       = 3000,
    parameter integer LOAD_TIMEOUT_MS    = 500,
    parameter integer DIAG_DISPLAY       = 0,
    parameter integer USE_FRAME_RESULT   = 0,
    parameter integer AUDIO_ENABLE = 0,
    parameter integer SCALE_ENABLE = 0,
    parameter integer PREVIEW_ENABLE = 0,
    parameter integer TRANSITION_ENABLE = 0,
    parameter integer SCENE_ENABLE = 0,
    parameter integer MENU_ENABLE=0,
    parameter integer PUBLICITY_ENABLE = 0
)(
    output                      bgm_valid,bgm_active,
    output signed [15:0]        bgm_left,bgm_right,
    input                       bgm_ready,
    input                       scenario_muted,
    output                      scenario_fade,
    output [12:0]               scenario_state,
    output [4:0] scenario_meta,
    output [1:0] application_mode,output application_busy,application_error,
    output reg [5:0] display_identity,
    output reg [7:0] display_kind,
    output [3:0] publicity_audio_status,
    output font_valid,text_valid,output [7:0] font_count,output [12:0] text_bytes,
    output bin_wr_en,bin_wr_text,output [11:0] bin_wr_addr,output [7:0] bin_wr_data,
    input sw3,
    output menu_write_mode,output menu_native,output menu_visible,output [1:0] menu_focus,
    output [3:0] menu_valid,output [1:0] effective_mode,
    input menu_display_off,
    input                       clk,
    input                       rst,
    input                       sdram_ready, // Synchronized into clk; gates first scan only.
    input                       key1,
    input                       key2,
    input                       key4,
    input [1:0]                 mode,
    output adjust_decrease,adjust_increase,adjust_restore,adjust_select,
    output     [3:0]            state_code,
    output [63:0]               sd_debug,
    output reg [57:0]          diagnostics,
    output     [7:0]            combo_event_count,
    output                      combo_debug_active,
    output                      auto_play_indicator,
    output [7:0]                osd_error_code,
    input  [15:0]               bmp_width,
    input  [15:0]               bmp_height,
    output                      display_valid,
    output     [1:0]            committed_image,
    output                      committed_valid,
    input                       committed_ready,

    output write_cancel_req,
    input write_cancel_ack,
    output source_frame_done, source_frame_error,
    input frame_error_toggle,
    input [2:0] frame_memory_error, reader_error,
    input reader_underflow,
    input                       write_finish_toggle,
    input                       display_commit_ack,
    input preview_ack,output preview_request,output [17:0] preview_descriptor,
    input                       transition_pix_clk, transition_pix_rst,
    input                       transition_frame_start, transition_commit_done,
    output reg                  display_commit_request,
    output     [1:0]            write_buf_idx,
    output reg [1:0]            disp_buf_idx,
    output                      transition_active,
    output [4:0]                transition_level,
    output                      transition_wipe,

    output                      write_req,
    input                       write_req_ack,
    input                       write_ready,
    output                      write_en,
    output [31:0]               write_data,
    output                      SD_nCS,
    output                      SD_DCLK,
    output                      SD_MOSI,
    input                       SD_MISO
);

// Menu requests quiesce audio/new cache work while accepted transactions drain.
wire cache_pause,menu_pause,safe_menu_idle;
wire [31:0] desired_directory;
wire menu_pending,menu_active,menu_blocked,menu_enter,menu_confirm,menu_cancel;
wire menu_owner,menu_ready,menu_discard,menu_load_request,menu_load_ready,menu_scan,menu_direct;
wire menu_force,menu_exit,menu_resume;
wire [1:0] menu_force_target;
wire menu_preview,menu_fallback,menu_rejected;
wire [31:0] menu_directory,menu_selected_directory;
wire [2:0] menu_hazard,menu_selected_hazard;
wire menu_publicity;
wire [1:0] menu_load_index,menu_slot;
wire [5:0] directory_valid;
wire [191:0] directory_clusters;
reg [31:0] scene_parent,publicity_directory,resource_directory,selected_directory;
reg scene_parent_valid,root_pic_complete,root_edu_complete,menu_resource_active;
// Capture the wide nonzero test when discovering the root directory. TD04
// measured a seven-LUT fallback path from publicity_directory into scan_state.
reg publicity_directory_valid;
reg directory_boot_fallback;
reg [2:0] resource_hazard,selected_hazard;
// FAT32 directory and board controls stay here; cache ownership is independent.
wire rescan_event,rescan_raw,manual_activity,media_next_request,media_previous_request,media_auto_toggle_request;
wire sd_init_done,sd_init_failed,sd_sec_read_failed;
wire sd_sec_read,sd_sec_read_data_valid,sd_sec_read_end;
wire [31:0] sd_sec_read_addr;
wire [7:0] sd_sec_read_data;
wire bmp_ready,scan_done,bmp_scan_error,scan_found_valid,bmp_load_done,parser_load_error;
wire [31:0] scan_found_cluster,scan_found_size;
wire [2:0] scan_found_total,parser_error;
wire [3:0] bmp_state_code,normal_state_code;
wire bmp_data_wr_en;wire [31:0] bmp_data;
wire parser_write_req;
assign write_req=parser_write_req && !menu_discard;
wire scan_request,scan_accept,scan_result_ready,scan_busy;
reg scan_result_valid,scan_success,scan_error_seen;
reg [2:0] img_found_count;
wire [1:0] img_idx,load_idx,current_bank,cache_write_bank;
assign write_buf_idx=menu_write_mode?menu_slot:cache_write_bank;
wire first_image_committed;
wire normal_transition_active,normal_transition_wipe;
wire [4:0] normal_transition_level;

localparam SC_IDLE=0,SC_RESET=1,SC_INIT=2,SC_SCAN=3,SC_RESULT=4,SC_BIN_START=5,SC_BIN_WAIT=6,
 SC_MAP_ISSUE=7,SC_MAP_WAIT=8,SC_DECIDE=9,SC_DIRECTORY_ISSUE=10,SC_DIRECTORY_WAIT=11,SC_SELECT_DIRECTORY=12,
 SC_FIRST_WAIT=13,SC_BG_BIN_START=14,SC_BG_BIN_WAIT=15;
reg [3:0] scan_state;
reg bins_pending;
// Separate the application/resource mux from the directory comparison. TD24
// measured eight LUT levels from app_target through this IDLE decision.
reg [31:0] scan_directory_pending;
reg [2:0] scan_hazard_pending;
reg [3:0] reset_count;
reg scan_start_pulse,map_start_pulse,map_publicity,map_boot;
reg [3:0] pic_checked,edu_checked;
reg [1:0] scan_application;
wire [3:0] mapped_valid;
wire reader_publicity;
wire [3:0] pic_valid,edu_valid,voi_valid,voi_invalid;
wire [127:0] pic_clusters,pic_sizes,edu_clusters,edu_sizes,voi_clusters,voi_sizes;
wire parser_rst=rst || scan_state==SC_RESET;
wire sd_local_rst=parser_rst;
wire audio_stopped;
reg audio_session;
wire audio_found;
wire [3:0] snd_valid;
wire [127:0] snd_clusters,snd_sizes;
wire selected_audio_found,scene_stream_run;
wire [31:0] selected_audio_cluster,selected_audio_size;
wire [7:0] audio_stream_error;
wire public_audio_request,public_fade,public_auto,public_offer,public_accept;
wire [1:0] public_page;
wire [2:0] public_voice_status;
wire selected_publicity,voice_done;
wire [15:0] voice_done_id,audio_identity;
wire [7:0] audio_version;
wire [1:0] selected_audio_stage;
wire common_audio_ready;
wire selected_audio_scene;
wire public_commit;
wire scene_mode,scene_next,scene_warn,scene_speed;
wire scene_request,scene_request_accept;
wire [1:0] scene_target;
wire scene_fade;
wire scene_owns=scene_mode || scene_fade;
wire application_toggle,app_reload,app_physical,app_stop_audio,app_scene_enable,app_fade_request,app_release;
wire app_rejected,app_black_permit,app_fade_busy,app_pixel_active,app_wipe_unused;
wire [4:0] app_level;
wire [1:0] app_target;
reg [3:0] resource_version;
assign audio_identity={resource_version,selected_publicity?2'd1:selected_audio_scene?2'd2:2'd0,selected_audio_stage,audio_version};

wire cache_rescan_event=PUBLICITY_ENABLE?app_reload:rescan_event;
wire app_controls_blocked=PUBLICITY_ENABLE && application_busy;
wire controls_blocked=app_controls_blocked || (MENU_ENABLE && menu_blocked);
assign scenario_fade=scene_fade || (PUBLICITY_ENABLE && application_busy) || public_fade || menu_pause;
assign publicity_audio_status={public_auto,public_voice_status};
wire [31:0] audio_cluster,audio_size,audio_fat_lba,audio_data_lba,audio_max_cluster;
wire [7:0] audio_spc;
wire a_req,a_busy,a_valid,a_done,a_urgent;
wire [31:0] a_lba;
wire [7:0] a_error,a_byte;
wire [8:0] a_index;
wire font_found,text_found;
wire [31:0] font_cluster,font_size,text_cluster,text_size;
wire bin_done,bin_req;wire [31:0] bin_lba;
wire bin_owner=SCENE_ENABLE && (scan_state==SC_BIN_START || scan_state==SC_BIN_WAIT || scan_state==SC_BG_BIN_START || scan_state==SC_BG_BIN_WAIT);
// Retiming the complete shared response keeps protocol state/valid off the
// audio and BIN byte-register enables. Capture ownership with the response;
// coincident last-byte and done remain coincident at both consumers.
reg response_valid,response_done,response_bin;
reg [7:0] response_byte,response_error;
reg [8:0] response_index;
always @(posedge clk or posedge rst)begin
 if(rst)begin response_valid<=0;response_done<=0;response_bin<=0;end
 else begin response_valid<=a_valid;response_done<=a_done;response_bin<=bin_owner;end
end
always @(posedge clk)begin
 response_byte<=a_byte;response_index<=a_index;response_error<=a_error;
end
wire response_busy=a_busy || a_valid || a_done || response_valid || response_done;
generate if(SCENE_ENABLE)begin:g_bins
 // A scan acceptance precedes all BIN starts by directory/header states.
 // Register its epoch reset locally instead of driving asynchronous resets
 // through shared-reader/audio/menu arbitration (TD11 recovery path).
 reg epoch_reset;
 wire loader_epoch_reset;
 // TD17: local reset release -> BIN registers removal was -0.052 ns.
 (* keep="true" *) AL_MAP_LUT1 #(.INIT(2'b10),.EQN("A"))
  u_epoch_reset_hold(.o(loader_epoch_reset),.a(epoch_reset));
 always @(posedge clk or posedge rst)begin
  if(rst)epoch_reset<=1;
  else epoch_reset<=parser_rst || (MENU_ENABLE && scan_accept);
 end
 bin_to_bram_loader #(.PIPELINED_METADATA(PUBLICITY_ENABLE)) loader(.clk(clk),.rst(loader_epoch_reset),.start((scan_state==SC_BIN_START && !(MENU_ENABLE && scan_application==1)) || scan_state==SC_BG_BIN_START),
  .font_found(font_found),.text_found(text_found),.font_cluster(font_cluster),.font_size(font_size),
  .text_cluster(text_cluster),.text_size(text_size),.spc(audio_spc),.fat_lba(audio_fat_lba),
  .data_lba(audio_data_lba),.max_cluster(audio_max_cluster),.done(bin_done),
  .font_valid(font_valid),.text_valid(text_valid),.font_count(font_count),.text_bytes(text_bytes),
  .wr_en(bin_wr_en),.wr_text(bin_wr_text),.wr_addr(bin_wr_addr),.wr_data(bin_wr_data),
  .sector_req(bin_req),.sector_lba(bin_lba),.sector_busy(response_busy),.sector_valid(response_valid && response_bin),
  .sector_done(response_done && response_bin),.sector_byte(response_byte),.sector_error(response_error),.sector_index(response_index));
end else begin:g_no_bins
 assign bin_done=1;assign bin_req=0;assign bin_lba=0;
 assign font_valid=0;assign text_valid=0;assign font_count=0;assign text_bytes=0;
 assign bin_wr_en=0;assign bin_wr_text=0;assign bin_wr_addr=0;assign bin_wr_data=0;
end endgenerate
// Hold the scan request until the audio transaction and both ring pointers
// have stopped. The physical SD reset must never cut an audio sector short.
// Register the stop through audio_session: preview/rescan decisions must not
// feed the file streamer's same-cycle enable path. A start can coincide with
// that final enabled edge, so wait for both enable low and the stopped ack.
wire audio_run=audio_session && scene_stream_run;
// The reader/player drain acknowledgement includes the shared SD arbiter.
// Sample it after enable is low, breaking the long arbiter -> scan enable
// path. A live enable veto prevents reusing a previous session's idle sample;
// every enabled edge also clears the sample before a subsequent stop.
reg audio_drained;
always @(posedge clk or posedge rst)begin
 if(rst)audio_drained<=0;
 else audio_drained<=!audio_run && audio_stopped;
end
assign scan_accept=scan_request && !menu_owner && scan_state==SC_IDLE && !audio_run && audio_drained;
always @(posedge clk or posedge rst) begin
 if(rst)audio_session<=0;
 else if(menu_pause || bins_pending || scan_request || (!PUBLICITY_ENABLE && rescan_event) || (PUBLICITY_ENABLE && app_stop_audio))audio_session<=0;
 // After remapping, READY may precede the target audio request. Keep the old
 // selection stopped until the common controller selects the new resource set.
 // Register this gate here: do not add resource decode to audio_run's fanout.
 else if(PUBLICITY_ENABLE && selected_publicity!=(scan_application==1))audio_session<=0;
 else if(scan_result_valid && scan_result_ready)audio_session<=scan_success;
 else if(PUBLICITY_ENABLE && !app_stop_audio && !scan_busy && first_image_committed)audio_session<=1;
end
generate if(AUDIO_ENABLE)begin: g_audio
 wire player_enable,file_valid,file_ready,sector_permit,player_stopped;
 wire [7:0] file_byte;
 wire player_low;
 reg urgent_latched;
 always @(posedge clk or posedge rst)begin
  if(rst)urgent_latched<=1;else urgent_latched<=player_low;
 end
 assign a_urgent=urgent_latched;
 fat32_pcm_stream #(.SINGLE_SUPPORT(PUBLICITY_ENABLE)) u_stream(
 .clk(clk),.rst_n(!rst),.enable(audio_run),.audio_found(selected_audio_found),.single_play(selected_publicity),
 .first_cluster(selected_audio_cluster),.file_size(selected_audio_size),.sectors_per_cluster(audio_spc),
 .fat_start_lba(audio_fat_lba),.data_start_lba(audio_data_lba),.max_cluster(audio_max_cluster),
 .sector_permit(sector_permit),.player_stopped(player_stopped),.player_ready(file_ready),
 .player_enable(player_enable),.file_valid(file_valid),.file_byte(file_byte),
 .stopped(audio_stopped),.error_code(audio_stream_error),.loop_count(),
 .sector_req(a_req),.sector_lba(a_lba),.sector_busy(response_busy),.sector_valid(response_valid && !response_bin),
 .sector_done(response_done && !response_bin),.sector_byte(response_byte),.sector_error(response_error),.sector_index(response_index));
 pcm_stream_player #(.SINGLE_SUPPORT(PUBLICITY_ENABLE)) u_player(
 .wr_clk(clk),.wr_rst_n(!rst),.play_enable(player_enable),
 .single_play(selected_publicity),.sample_total(selected_audio_size[31:1]),.session_id(audio_identity),
 .playback_done(voice_done),.done_session(voice_done_id),
 .file_valid(file_valid),.file_byte(file_byte),.file_ready(file_ready),
 .sector_permit(sector_permit),.buffer_low(player_low),.stopped(player_stopped),.write_level(),
 .rd_clk(transition_pix_clk),.rd_rst_n(!transition_pix_rst),.sample_ready(bgm_ready),
 .sample_valid(bgm_valid),.sample_left(bgm_left),.sample_right(bgm_right),
 .active(bgm_active),.underflow_count(),.output_overrun());
end else begin: g_no_audio
 assign audio_stopped=1'b1;assign a_req=1'b0;assign a_lba=0;assign a_urgent=0;
 assign bgm_valid=0;assign bgm_active=0;assign bgm_left=0;assign bgm_right=0;
 assign audio_stream_error=0;assign voice_done=0;assign voice_done_id=0;
end endgenerate
always @(posedge clk or posedge rst) begin
 if(rst) begin
  scan_state<=SC_IDLE;reset_count<=0;scan_start_pulse<=0;scan_result_valid<=0;scan_success<=0;
  scan_error_seen<=0;img_found_count<=0;map_start_pulse<=0;map_publicity<=0;map_boot<=0;
  pic_checked<=0;edu_checked<=0;scan_application<=0;resource_version<=0;bins_pending<=0;
  scan_directory_pending<=0;scan_hazard_pending<=0;
  scene_parent<=0;scene_parent_valid<=0;publicity_directory<=0;publicity_directory_valid<=0;resource_directory<=0;resource_hazard<=0;
  selected_directory<=0;selected_hazard<=0;root_pic_complete<=0;root_edu_complete<=0;menu_resource_active<=0;directory_boot_fallback<=0;
 end else begin
  scan_start_pulse<=0;map_start_pulse<=0;
  if(MENU_ENABLE && menu_force)begin selected_directory<=menu_selected_directory;selected_hazard<=menu_selected_hazard;menu_resource_active<=1;end
  else if(application_toggle || rescan_event)menu_resource_active<=0;
  case(scan_state)
   SC_IDLE: if(scan_accept) begin
    reset_count<=0;img_found_count<=0;scan_error_seen<=0;
    resource_version<=resource_version+1'b1;
    if(PUBLICITY_ENABLE && !app_physical)begin
     map_boot<=0;map_publicity<=app_target==1;scan_application<=app_target;
     if(MENU_ENABLE)begin
      scan_directory_pending<=desired_directory;
      scan_hazard_pending<=app_target==2 && (!root_pic_complete || menu_resource_active) && selected_directory!=0?selected_hazard:3'd0;
      scan_state<=SC_SELECT_DIRECTORY;
     end else scan_state<=SC_MAP_ISSUE;
    end else begin
     scan_state<=SC_RESET;map_publicity<=MENU_ENABLE && PUBLICITY_ENABLE;map_boot<=PUBLICITY_ENABLE;scan_application<=0;
     pic_checked<=0;edu_checked<=0;resource_directory<=0;resource_hazard<=0;
     scene_parent<=0;scene_parent_valid<=0;publicity_directory<=0;publicity_directory_valid<=0;root_pic_complete<=0;root_edu_complete<=0;directory_boot_fallback<=0;
    end
   end
   SC_SELECT_DIRECTORY:begin
    if(resource_directory!=scan_directory_pending)begin
     resource_directory<=scan_directory_pending;resource_hazard<=scan_hazard_pending;scan_state<=SC_DIRECTORY_ISSUE;
    end else scan_state<=SC_MAP_ISSUE;
   end
   SC_RESET: if(reset_count==7) scan_state<=SC_INIT; else reset_count<=reset_count+1'b1;
   SC_INIT: if(sd_init_failed) begin
    scan_success<=0;scan_result_valid<=1;scan_state<=SC_RESULT;
   end else if(sd_init_done && bmp_ready && sdram_ready) begin
    scan_start_pulse<=1;scan_state<=SC_SCAN;
   end
   SC_SCAN: begin
    if(bmp_scan_error) scan_error_seen<=1;
    // The reader keeps the found-image table; loads select it by index.
    if(scan_found_valid) img_found_count<=scan_found_total;
    if(scan_done) begin
     scan_success<=!scan_error_seen && !bmp_scan_error;
     if(PUBLICITY_ENABLE && !scan_error_seen && !bmp_scan_error)begin
      pic_checked<=MENU_ENABLE?4'd0:mapped_valid;root_pic_complete<=MENU_ENABLE?(pic_valid==15):(mapped_valid==15);
      if(MENU_ENABLE)begin
       scene_parent<=directory_clusters[31:0];scene_parent_valid<=directory_valid[0];
       publicity_directory<=directory_valid[1]?directory_clusters[63:32]:32'd0;
       publicity_directory_valid<=directory_valid[1] && directory_clusters[63:32]!=0;
      end
      map_publicity<=1;scan_state<=MENU_ENABLE?SC_DECIDE:SC_MAP_ISSUE;
     end else if(SCENE_ENABLE && !scan_error_seen && !bmp_scan_error)scan_state<=SC_BIN_START;
     else begin scan_result_valid<=1;scan_state<=SC_RESULT;end
    end
   end
   SC_MAP_ISSUE:if(bmp_ready && !a_busy)begin
    map_start_pulse<=1;scan_error_seen<=0;img_found_count<=0;scan_state<=SC_MAP_WAIT;
   end
   // scan_done is sticky; wait until the accepted request clears it first.
   SC_MAP_WAIT:if(!scan_done && !map_start_pulse)scan_state<=SC_DECIDE;
   SC_DECIDE:begin
    if(bmp_scan_error)scan_error_seen<=1;
    if(scan_found_valid)img_found_count<=scan_found_total;
    if(scan_done)begin
     if(map_boot && map_publicity)begin
      root_edu_complete<=mapped_valid==15 && !scan_error_seen && !bmp_scan_error;
      edu_checked<=(!scan_error_seen && !bmp_scan_error)?mapped_valid:4'd0;
      if(mapped_valid==15 && !scan_error_seen && !bmp_scan_error)begin
       scan_application<=1;map_boot<=0;scan_success<=1;scan_state<=SC_BIN_START;
      end else if(MENU_ENABLE && publicity_directory_valid)begin
       resource_directory<=publicity_directory;resource_hazard<=0;scan_application<=1;map_boot<=0;directory_boot_fallback<=1;scan_state<=SC_DIRECTORY_ISSUE;
      end else begin map_publicity<=0;map_boot<=0;scan_application<=0;scan_state<=SC_MAP_ISSUE;end
     end else if(MENU_ENABLE && directory_boot_fallback && (scan_error_seen || bmp_scan_error || mapped_valid!=15))begin
      directory_boot_fallback<=0;resource_directory<=0;resource_hazard<=0;map_publicity<=0;scan_application<=0;scan_state<=SC_DIRECTORY_ISSUE;
     end else begin
      directory_boot_fallback<=0;
      scan_success<=!scan_error_seen && !bmp_scan_error &&
       (scan_application==0 || mapped_valid==15);
      if(scan_application!=1)pic_checked<=(!scan_error_seen && !bmp_scan_error)?mapped_valid:4'd0;
      // FONT/TEXT are loaded once after physical scan and remain valid on map.
      if(scan_application==1)edu_checked<=(!scan_error_seen && !bmp_scan_error)?mapped_valid:4'd0;
      if(MENU_ENABLE || (scan_application==0 && app_physical))scan_state<=SC_BIN_START;
      else begin scan_result_valid<=1;scan_state<=SC_RESULT;end
     end
    end
   end
   SC_DIRECTORY_ISSUE:if(bmp_ready && !a_busy)begin scan_start_pulse<=1;scan_error_seen<=0;img_found_count<=0;scan_state<=SC_DIRECTORY_WAIT;end
   SC_DIRECTORY_WAIT:if(!scan_done && !scan_start_pulse)scan_state<=SC_DECIDE;
   SC_BIN_START:if(MENU_ENABLE && scan_application==1)begin
    bins_pending<=1;scan_result_valid<=1;scan_state<=SC_RESULT;
   end else scan_state<=SC_BIN_WAIT;
   SC_BIN_WAIT:if(bin_done)begin scan_result_valid<=1;scan_state<=SC_RESULT;end
   SC_RESULT: if(scan_result_ready) begin scan_result_valid<=0;scan_state<=bins_pending?SC_FIRST_WAIT:SC_IDLE;end
   SC_FIRST_WAIT:if(first_image_committed || application_error)scan_state<=SC_BG_BIN_START;
   SC_BG_BIN_START:scan_state<=SC_BG_BIN_WAIT;
   SC_BG_BIN_WAIT:if(bin_done)begin bins_pending<=0;scan_state<=SC_IDLE;end
   default:scan_state<=SC_IDLE;
  endcase
 end
end

wire load_request,load_accept,load_result_valid,load_result_ready,load_success,load_timeout;
wire [7:0] loaded_kind;
reg [7:0] bank_kind[0:3];
integer kind_i;
always @(posedge clk or posedge rst)begin
 if(rst)for(kind_i=0;kind_i<4;kind_i=kind_i+1)bank_kind[kind_i]<=0;
 else if(!menu_owner && load_result_valid && load_result_ready && load_success)
  bank_kind[write_buf_idx]<=loaded_kind;
end
wire cancel_request,cancel_ack,parser_cancel,load_start_pulse;
// Cancellation is held through the writer/parser drain handshake. Keep the
// immediate source write gate below, but register the parser's high-fanout
// cancel/reset boundary rather than route cache/application decode into it.
reg parser_cancel_q;
always @(posedge clk or posedge rst)begin
 if(rst)parser_cancel_q<=0;
 else parser_cancel_q<=parser_cancel;
end
wire source_done_now,write_finish_now,load_fault,memory_failure;
wire [2:0] load_fault_code,memory_code;
wire [7:0] parser_fat_error;
wire load_busy,foreground_busy,timeout_stopped;
wire [2:0] image_count;
wire [3:0] cache_valid,cache_failed;
wire [7:0] cache_banks;
wire cache_complete,cache_hit,request_failed,load_failed,retry_event;
wire [1:0] cache_complete_image,cache_hit_image,failed_image;
reg [1:0] write_req_ack_pipe,commit_ack_sync;
wire write_req_ack_sync=write_req_ack_pipe[1];
always @(posedge clk or posedge rst) begin
 if(rst) begin write_req_ack_pipe<=0;commit_ack_sync<=0;end
 else begin
  write_req_ack_pipe<={write_req_ack_pipe[0],write_req_ack};
  commit_ack_sync<={commit_ack_sync[0],display_commit_ack};
 end
end
media_frame_load_control #(.USE_FRAME_RESULT(USE_FRAME_RESULT)) u_load_control(
 .clk(clk),.rst(rst),.load_request(menu_owner?menu_load_request:load_request),.load_accept(load_accept),
 .load_result_valid(load_result_valid),.load_success(load_success),.load_timeout(load_timeout),
 .load_result_ready(menu_owner?menu_load_ready:load_result_ready),.cancel_request(!menu_owner && cancel_request),.cancel_ack(cancel_ack),
 .parser_ready(bmp_ready),.source_done(bmp_load_done && !menu_discard),.source_error(parser_load_error && !menu_discard),.source_error_code(parser_error),
 .load_start(load_start_pulse),.parser_cancel(parser_cancel),
 .write_req(write_req),.write_req_ack(write_req_ack),.write_finish_toggle(write_finish_toggle),
 .frame_error_toggle(frame_error_toggle),.frame_memory_error(frame_memory_error),
 .write_cancel_req(write_cancel_req),.write_cancel_ack(write_cancel_ack),
 .fault_event(load_fault),.fault_code(load_fault_code),.memory_fault(memory_failure),.memory_code(memory_code),
 .source_complete(source_done_now),.write_complete(write_finish_now)
);

wire preview_intent,preview_selecting,preview_fullscreen_ready,preview_offer,preview_key_toggle;
assign preview_key_toggle=PREVIEW_ENABLE && effective_mode==3 && media_auto_toggle_request;
wire cache_display_request,cache_display_ack;
assign public_commit=PUBLICITY_ENABLE && scan_application==1 && cache_display_request && cache_display_ack;
wire transition_permit, transition_busy;
wire scene_muted_sd,scene_audio_running;
reg transition_auto;
wire [1:0] cache_display_image,cache_display_bank;
wire app_initial_display;
wire transition_needed=TRANSITION_ENABLE && !controls_blocked && !preview_selecting && first_image_committed &&
                       display_valid && cache_display_bank!=current_bank;
video_transition_sd_control #(.ENABLE(TRANSITION_ENABLE)) u_transition_sd_control(
 .clk(clk),.rst(rst),.display_request(cache_display_request),.display_valid(transition_needed),.request_wipe(transition_auto),
 .pix_clk(transition_pix_clk),.pix_rst(transition_pix_rst),
 .frame_start(transition_frame_start),.commit_done(transition_commit_done),
 .transition_busy(transition_busy),.transition_active(normal_transition_active),
 .transition_level(normal_transition_level),.permit_commit(transition_permit),.wipe_active(normal_transition_wipe));
assign transition_active=normal_transition_active || app_pixel_active;
assign transition_level=app_level<normal_transition_level?app_level:normal_transition_level;
assign transition_wipe=normal_transition_wipe && !app_pixel_active;
generate if(PUBLICITY_ENABLE)begin:g_application
 wire app_frame_tick;
 scene_event_cdc frame_events(.pix_clk(transition_pix_clk),.pix_rst(transition_pix_rst),
  .sample_accept(1'b0),.frame_start(transition_frame_start),.clk(clk),.rst(rst),
  .sample_tick(),.frame_tick(app_frame_tick));
 publicity_app_control #(.MENU_ENABLE(MENU_ENABLE),.FAST_BOOT(MENU_ENABLE)) application(
  .force_request(menu_force),.force_target(menu_force_target),.clk(clk),.rst(rst),.toggle_request(application_toggle),
  .retry_request(media_auto_toggle_request && effective_mode==0),.rescan_request(rescan_event),
  .pic_complete(pic_checked==15 || (MENU_ENABLE && (root_pic_complete || selected_directory!=0))),.pic_any(pic_checked!=0 || (MENU_ENABLE && pic_valid!=0)),.edu_complete(edu_checked==15),
  .scan_valid(scan_result_valid && scan_result_ready),.scan_success(scan_success && img_found_count!=0),.scan_application(scan_application),
  .idle(!foreground_busy && !transition_busy && !scene_fade && preview_fullscreen_ready),
  .black(app_black_permit),.muted(scene_muted_sd || !AUDIO_ENABLE),.audio_stopped(audio_stopped),
  .committed(cache_display_request && cache_display_ack),.failed(request_failed || timeout_stopped),
  .scene_ready(scenario_state[12] && !scene_fade),.frame_tick(app_frame_tick),.fade_busy(app_fade_busy),
  .app(application_mode),.target(app_target),.busy(application_busy),.error(application_error),.rejected(app_rejected),
  .physical(app_physical),.reload(app_reload),.stop_audio(app_stop_audio),.scene_enable(app_scene_enable),
  .fade_request(app_fade_request),.release_fade(app_release),.initial_display(app_initial_display));
 reg release_q,release_toggle;
 (* ASYNC_REG="TRUE" *) reg [1:0] release_sync;
 reg release_seen;
 always @(posedge clk or posedge rst)begin
  if(rst)begin release_q<=0;release_toggle<=0;end
  else begin release_q<=app_release;if(app_release && !release_q)release_toggle<=~release_toggle;end
 end
 always @(posedge transition_pix_clk or posedge transition_pix_rst)begin
  if(transition_pix_rst)begin release_sync<=0;release_seen<=0;end
  else begin release_sync<={release_sync[0],release_toggle};release_seen<=release_sync[1];end
 end
 video_transition_sd_control #(.ENABLE(1)) fade(.clk(clk),.rst(rst),
  .display_request(app_fade_request),.display_valid(1'b1),.request_wipe(1'b0),
  .pix_clk(transition_pix_clk),.pix_rst(transition_pix_rst),.frame_start(transition_frame_start),
  .commit_done(release_sync[1]!=release_seen),.transition_busy(app_fade_busy),
  .transition_active(app_pixel_active),.transition_level(app_level),.permit_commit(app_black_permit),.wipe_active(app_wipe_unused));
end else begin:g_no_application
 assign application_mode=0;assign application_busy=0;assign application_error=0;assign app_target=0;
 assign app_physical=1;assign app_reload=0;assign app_stop_audio=0;assign app_scene_enable=0;
 assign app_fade_request=0;assign app_release=0;assign app_rejected=0;
 assign app_level=16;assign app_pixel_active=0;assign app_black_permit=1;assign app_fade_busy=0;
 assign app_initial_display=0;
end endgenerate
reg rescan_pending;
wire rescan_wait=(rescan_pending || rescan_raw || controls_blocked);
assign rescan_event=(TRANSITION_ENABLE || PREVIEW_ENABLE || PUBLICITY_ENABLE) ?
 (rescan_pending && !transition_busy && preview_fullscreen_ready && (!app_controls_blocked || application_error)) : rescan_raw;
always @(posedge clk or posedge rst) begin
 if(rst) rescan_pending<=0;
 else if(rescan_raw) rescan_pending<=1;
 else if(rescan_event) rescan_pending<=0;
end
reg commit_pending;
// The core holds its request until this adapter returns the actual reader ack.
// Do not issue it again on the clock the core consumes that acknowledgement.
assign cache_display_ack=commit_pending && commit_ack_sync[1]==display_commit_request;
always @(posedge clk or posedge rst) begin
 if(rst) begin commit_pending<=0;display_commit_request<=0;disp_buf_idx<=0;display_identity<=0;display_kind<=0;end
 else begin
  if(!cache_display_request) commit_pending<=0;
  else if(!commit_pending && preview_fullscreen_ready && (!app_controls_blocked || app_black_permit || app_initial_display) && (!transition_needed || transition_permit) &&
          (!scene_owns || !scene_audio_running || scene_muted_sd) &&
          (!PUBLICITY_ENABLE || application_mode!=1 || scene_muted_sd || !AUDIO_ENABLE || app_initial_display)) begin
   disp_buf_idx<=cache_display_bank;
   display_identity<={resource_version,scan_application};
   display_kind<=bank_kind[cache_display_bank];
   display_commit_request<=~display_commit_request;
   commit_pending<=1;
  end
 end
end
wire ctrl_auto_play_en,ctrl_next_pending,ctrl_prev_pending,ctrl_auto_tick,ctrl_load_request;
reg scene_auto,scene_mode_q;
wire effective_auto=scene_mode?scene_auto:(PUBLICITY_ENABLE && application_mode==1)?public_auto:ctrl_auto_play_en;
always @(posedge clk or posedge rst)begin
 if(rst)begin scene_auto<=0;scene_mode_q<=0;end
 else begin
  scene_mode_q<=scene_mode;
  if(!scene_mode || rescan_event || app_controls_blocked || menu_force)scene_auto<=0;
  else if(!scene_mode_q)scene_auto<=PUBLICITY_ENABLE?1'b0:ctrl_auto_play_en;
  else if(media_auto_toggle_request && effective_mode==0)scene_auto<=!scene_auto;
 end
end
wire ctrl_request_ready,ctrl_request_accept,ctrl_auto_load_request;
wire [3:0] cache_ready_by_image;
wire [1:0] ctrl_target_image;
wire transition_block=transition_busy || (PUBLICITY_ENABLE ? (rescan_pending || rescan_raw) : rescan_wait);
wire ctrl_offer=ctrl_load_request && !controls_blocked && !scene_owns && !transition_block && !preview_intent && !preview_selecting;
wire [1:0] preview_target;
wire preview_target_select;
wire scene_preview=PUBLICITY_ENABLE && scene_mode;
wire scene_select_ready;
wire cache_offer=!cache_pause && (ctrl_offer || (preview_offer && !scene_preview) || (scene_request && !transition_block) || public_offer);
// Publicity AUTO only offers on a complete four-page set, with no pending
// manual navigation. The player's default target is already the same next
// page (including page 4 -> 1). Do not send the AUTO valid/busy decode back
// through the target mux and the cache's target-dependent ready path.
// rescan_wait inhibits preview, player and publicity offers together. Use
// the registered preview owner for the target mux so rescan/UI inhibition
// does not cross the target-dependent cache-ready decode. Scene wins both
// muxes; on every valid cache offer this selects exactly the old target.
wire [1:0] cache_target=scene_request?scene_target:preview_target_select?preview_target:ctrl_target_image;
assign scene_request_accept=scene_request && !cache_pause && cache_ready_by_image[scene_target] && !transition_block;
generate if(PREVIEW_ENABLE)begin:g_preview
 media_preview_control control(.clk(clk),.rst(rst),.mode(effective_mode),.scan_busy(scan_busy),
 .first_image_committed(first_image_committed),.transition_busy(transition_busy),.foreground_busy(foreground_busy),
 .rescan_wait(rescan_wait),.next_event(media_next_request),.previous_event(media_previous_request),.toggle_event(preview_key_toggle),
 .current_image(img_idx),.image_count(image_count),.cache_valid(cache_valid),.cache_banks(cache_banks),
 .request_ready(scene_preview?scene_select_ready:ctrl_request_ready),.request_failed(request_failed),.storage_stopped(timeout_stopped),.display_request(cache_display_request),.display_committed(cache_display_ack),
 .request_valid(preview_offer),.request_image(preview_target),.target_select(preview_target_select),.preview_intent(preview_intent),.selecting(preview_selecting),
 .fullscreen_ready(preview_fullscreen_ready),.preview_request(preview_request),.preview_descriptor(preview_descriptor),.preview_ack(preview_ack));
end else begin:g_no_preview
 assign preview_intent=0;assign preview_selecting=0;assign preview_fullscreen_ready=1;
 assign preview_offer=0;assign preview_target=0;assign preview_target_select=0;assign preview_request=0;assign preview_descriptor=0;
end endgenerate
assign ctrl_request_accept=ctrl_offer && ctrl_request_ready;
// Capture origin at acceptance, not when queued keys or AUTO state later change.
always @(posedge clk or posedge rst) begin
 if(rst) transition_auto<=0;
 else if(rescan_event) transition_auto<=0;
 else if(ctrl_request_accept) transition_auto<=ctrl_auto_load_request;
 else if(public_accept)transition_auto<=1;
end
media_frame_cache_control #(.PAUSE_ENABLE(MENU_ENABLE),.STRICT_FIRST_ENABLE(MENU_ENABLE)) u_cache_control(
 .pause(cache_pause || (bins_pending && first_image_committed)),.strict_first(scan_application!=0),
 .clk(clk),.rst(rst),.rescan_event(cache_rescan_event),
 .scan_request(scan_request),.scan_accept(scan_accept),.scan_result_valid(scan_result_valid),
 .scan_success(scan_success),.scan_image_count(img_found_count),.scan_result_ready(scan_result_ready),.scan_busy(scan_busy),
 .request_valid(cache_offer),.request_image(cache_target),
 .request_manual(scene_request || preview_offer || ctrl_next_pending || ctrl_prev_pending),.request_ready(ctrl_request_ready),.request_ready_by_image(cache_ready_by_image),.foreground_busy(foreground_busy),
 .load_request(load_request),.load_accept(load_accept && !menu_owner),.load_image(load_idx),.load_bank(cache_write_bank),
 .load_result_valid(load_result_valid && !menu_owner),.load_success(load_success),.load_timeout(load_timeout),.load_result_ready(load_result_ready),
 .cancel_request(cancel_request),.cancel_ack(cancel_ack),.communication_fault(1'b0),
 .storage_busy(load_busy),.storage_stopped(timeout_stopped),
 .display_request(cache_display_request),.display_image(cache_display_image),.display_bank(cache_display_bank),.display_ack(cache_display_ack),
 .display_valid(display_valid),.current_image(img_idx),.current_bank(current_bank),.first_image_committed(first_image_committed),
 .committed_valid(committed_valid),.committed_image(committed_image),.committed_ready(committed_ready),
 .image_count(image_count),.cache_valid(cache_valid),.cache_failed(cache_failed),.cache_banks(cache_banks),
 .cache_complete(cache_complete),.cache_hit(cache_hit),.request_failed(request_failed),.load_failed(load_failed),
 .retry_event(retry_event),
 .cache_complete_image(cache_complete_image),.cache_hit_image(cache_hit_image),.failed_image(failed_image)
);
mode_key_control #(.PREVIEW_ENABLE(PREVIEW_ENABLE),.SCENE_ENABLE(SCENE_ENABLE),.PUBLICITY_ENABLE(PUBLICITY_ENABLE),.CLK_FREQ_HZ(CLK_FREQ_HZ)) u_mode_key_control(
 .clk(clk),.rst(rst),.enable(!scan_busy && !menu_blocked && (!app_controls_blocked || application_error)),.key1(key1),.key2(key2),.key4(key4),.mode(effective_mode),
 .scene_active(app_scene_enable),.application_busy(menu_blocked || (app_controls_blocked && !application_error)),.application_toggle(application_toggle),
 .rescan_event(rescan_raw),.next_event(media_next_request),.previous_event(media_previous_request),
 .auto_toggle_event(media_auto_toggle_request),.manual_activity(manual_activity),
 .scene_allowed(first_image_committed && image_count==4 && !scan_busy),
 .scene_mode(scene_mode),.scene_next(scene_next),.scene_warn(scene_warn),.scene_speed(scene_speed),
 .adjust_decrease(adjust_decrease),.adjust_increase(adjust_increase),.adjust_restore(adjust_restore),.adjust_select(adjust_select)
);
media_player_control #(.AUTO_PLAY_CYCLES((CLK_FREQ_HZ/1000)*AUTO_PLAY_MS),.UI_GATE(PUBLICITY_ENABLE),.PAUSE_ENABLE(MENU_ENABLE)) u_media_player_control(
 // UI ownership extends through pending requests and key-release handover.
 // The cache can resume earlier, but AUTO must survive the whole menu visit.
 .pause(MENU_ENABLE && menu_blocked),
 .clk(clk),.rst(rst),.enable(!scan_busy && !controls_blocked && !scene_owns && !preview_intent && !preview_selecting),.scan_done(!scan_busy),
 .display_valid(display_valid),.load_busy(foreground_busy || transition_block),.first_image_committed(first_image_committed),
 .image_count(image_count),.current_image(img_idx),.mode(effective_mode),.next_event(media_next_request),
 .previous_event(media_previous_request),.auto_toggle_event(media_auto_toggle_request && (!PUBLICITY_ENABLE || application_mode==0)),
 .request_accept(ctrl_request_accept),.manual_activity(manual_activity),
 .next_load_request(),.previous_load_request(),.auto_load_request(ctrl_auto_load_request),
 .auto_play_en(ctrl_auto_play_en),.next_pending(ctrl_next_pending),.previous_pending(ctrl_prev_pending),
 .auto_tick(ctrl_auto_tick),.load_request(ctrl_load_request),.target_image(ctrl_target_image)
);
generate if(SCENE_ENABLE)begin:g_scenario
 wire sample_tick,frame_tick,audio_request,audio_scene,audio_ready,layer_enable;
 wire [1:0] stage,speed,alert_level,audio_stage;
 wire [1:0] selected_stage=selected_audio_stage;
 wire [7:0] t_now;
 wire warn_mode;
 wire selected_scene=selected_audio_scene;
 assign scenario_meta={scene_mode,warn_mode,speed,1'b0};
 (* ASYNC_REG="TRUE" *) reg [1:0] muted_sync,active_sync;
 always @(posedge clk or posedge rst)begin
  if(rst)begin muted_sync<=0;active_sync<=0;end
  else begin muted_sync<={muted_sync[0],scenario_muted};active_sync<={active_sync[0],bgm_active};end
 end
 assign scene_muted_sd=muted_sync[1];
 // Availability is stable before playback starts. Register its summary so
 // a stage/table mux does not reach the scenario sample-counter enables.
 reg audio_available_q;
 always @(posedge clk or posedge rst)begin
  if(rst)audio_available_q<=0;
  else audio_available_q<=selected_audio_found && audio_stream_error==0;
 end
 assign scene_audio_running=active_sync[1] && audio_available_q;
 scene_event_cdc events(.pix_clk(transition_pix_clk),.pix_rst(transition_pix_rst),
  .sample_accept(bgm_valid && bgm_ready),.frame_start(transition_frame_start),
  .clk(clk),.rst(rst),.sample_tick(sample_tick),.frame_tick(frame_tick));
 scenario_fsm #(.PRESERVE_SPEED(PUBLICITY_ENABLE),.UI_GATE(PUBLICITY_ENABLE),.PREVIEW_SELECT(PUBLICITY_ENABLE),.MENU_ENABLE(MENU_ENABLE)) control(.pause(cache_pause),.restart(menu_resume),.clk(clk),.rst(rst),.enable(scene_mode),.auto_enable(scene_auto && (!PUBLICITY_ENABLE || !controls_blocked)),
  .ui_play(effective_mode==0 && !controls_blocked),
  .select_request(preview_offer && scene_preview && !controls_blocked),.select_stage(preview_target),.select_ready(scene_select_ready),
  .scene_ready(first_image_committed && image_count==4 && !scan_busy),
  .key_next(scene_next),.key_mode(scene_warn),.key_speed(scene_speed),
  .sample_tick(sample_tick),.audio_running(scene_audio_running),.frame_start(frame_tick),.muted(scene_muted_sd),
  .request_ready(scene_request_accept),.picture_done(cache_display_ack),.picture_failed(request_failed),
  .transition_idle(!transition_busy),.audio_ready(audio_ready),.stage(stage),.speed(speed),.warn_mode(warn_mode),
  .t_now(t_now),.alert_level(alert_level),.stage_req(scene_request),.requested_stage(scene_target),
  .fade_mute(scene_fade),.layer_enable(layer_enable),
  .audio_request(audio_request),.audio_scene(audio_scene),.audio_stage(audio_stage));
 scenario_audio_control #(.PUBLICITY_ENABLE(PUBLICITY_ENABLE),.PIPELINED_FOUND(MENU_ENABLE)) audio_control(.clk(clk),.rst(rst),.request(audio_request || public_audio_request),
  .request_publicity(public_audio_request),.selected_publicity(selected_publicity),.session_version(audio_version),
  .request_scene(!public_audio_request && audio_scene),.request_stage(public_audio_request?public_page:audio_stage),.stopped(audio_stopped),
  .sample_tick(sample_tick),.session_enable(audio_session),.stream_error(audio_stream_error),
  .selected_found(selected_audio_found),.run_enable(scene_stream_run),
  .selected_scene(selected_audio_scene),.selected_stage(selected_audio_stage),.ready(common_audio_ready));
 assign audio_ready=common_audio_ready && !public_audio_request;
 wire use_snd=selected_scene && snd_valid[selected_stage];
 assign selected_audio_found=selected_publicity?voi_valid[selected_stage]:(use_snd || audio_found);
 assign selected_audio_cluster=selected_publicity?voi_clusters[selected_stage*32+:32]:use_snd?snd_clusters[selected_stage*32+:32]:audio_cluster;
 assign selected_audio_size=selected_publicity?voi_sizes[selected_stage*32+:32]:use_snd?snd_sizes[selected_stage*32+:32]:audio_size;
 assign scenario_state={layer_enable,alert_level,stage,t_now};
end else begin:g_no_scenario
 assign scene_request=0;assign scene_target=0;assign scenario_state=0;assign scenario_meta=0;assign scene_fade=0;assign scene_select_ready=0;
 assign scene_muted_sd=0;assign scene_audio_running=0;assign scene_stream_run=1;
 assign selected_publicity=0;assign selected_audio_scene=0;assign selected_audio_stage=0;assign audio_version=0;assign common_audio_ready=1;
 assign selected_audio_found=audio_found;assign selected_audio_cluster=audio_cluster;assign selected_audio_size=audio_size;
end endgenerate
generate if(PUBLICITY_ENABLE)begin:g_publicity
 wire frame_tick;
 scene_event_cdc frames(.pix_clk(transition_pix_clk),.pix_rst(transition_pix_rst),
  .sample_accept(1'b0),.frame_start(transition_frame_start),.clk(clk),.rst(rst),.sample_tick(),.frame_tick(frame_tick));
 publicity_voice_control #(.MENU_ENABLE(MENU_ENABLE)) voice(
  .pause(cache_pause),.restart(menu_resume),.clk(clk),.rst(rst),
  .enable((application_mode==1 && !app_stop_audio && !scan_busy) || public_commit),
  .commit(public_commit),.commit_page(cache_display_image),.page_pending(cache_display_request && scan_application==1),
  .busy(controls_blocked || transition_block || foreground_busy || bins_pending),.ui_play(effective_mode==0),.frame_tick(frame_tick),
  .toggle_auto(media_auto_toggle_request && effective_mode==0),.manual(manual_activity || ctrl_load_request || preview_offer || scene_request),
  .offer_ready(ctrl_request_ready && !ctrl_offer && !preview_offer && !scene_request && !transition_block && !foreground_busy),
  .audio_ready(common_audio_ready),.selected_publicity(selected_publicity),.selected_found(selected_audio_found && AUDIO_ENABLE),
  .stream_error(selected_publicity && voi_invalid[selected_audio_stage]?8'h30:audio_stream_error),.session_id(audio_identity),.done(voice_done),.done_id(voice_done_id),
  .voice_request(public_audio_request),.page(public_page),.fade(public_fade),.auto_enable(public_auto),
  .auto_offer(public_offer),.auto_accept(public_accept),.status(public_voice_status));
end else begin:g_no_publicity_voice
 assign public_audio_request=0;assign public_page=0;assign public_fade=0;assign public_auto=0;
 assign public_offer=0;assign public_accept=0;assign public_voice_status=0;
end endgenerate
media_display_control #(.CLK_FREQ_HZ(CLK_FREQ_HZ),.DIAG_DISPLAY(DIAG_DISPLAY)) u_media_display_control(
 .clk(clk),.rst(rst),.combo_request(1'b0),.sd_init_done(sd_init_done),.scan_done(!scan_busy),
 .display_valid(display_valid),.load_busy(foreground_busy),.write_started_seen(write_req),
 .source_done_now(source_done_now),.write_finish_now(write_finish_now),.img_idx(img_idx),
 .bmp_state_code(bmp_state_code),.state_code(normal_state_code),.auto_play_en(effective_auto),
 .auto_play_indicator(auto_play_indicator),.combo_event_count(combo_event_count),.combo_debug_active(combo_debug_active)
);
reg [2:0] sticky_error;
reg recovery_active;
wire diag_commit=cache_display_request && cache_display_ack;
// Preserve the cause for each logical image: a later background load must not
// overwrite the diagnostic for the page the user is trying to display.
// 10..26: sector/FAT error, 40|BMP: decoder/mapping, 80|MEM: writer error.
reg [7:0] page_error[0:3];
reg [1:0] diagnostic_target;
reg [7:0] failed_request_detail;
integer error_i;
always @(posedge clk or posedge rst)begin
 if(rst)begin
  for(error_i=0;error_i<4;error_i=error_i+1)page_error[error_i]<=0;
  diagnostic_target<=0;failed_request_detail<=0;
 end else begin
  if(scan_accept)begin
   for(error_i=0;error_i<4;error_i=error_i+1)page_error[error_i]<=0;
   diagnostic_target<=0;failed_request_detail<=0;
  end else begin
   if(cache_offer && ctrl_request_ready)diagnostic_target<=cache_target;
   if(!menu_owner)begin
    if(load_result_valid && load_result_ready && load_success)page_error[load_idx]<=0;
    if(parser_load_error && !menu_discard)
     page_error[load_idx]<=parser_fat_error!=0?parser_fat_error:{5'b01000,parser_error};
    if(memory_failure)page_error[load_idx]<={5'b10000,memory_code};
   end
   if(request_failed)failed_request_detail<=page_error[diagnostic_target];
   if(diag_commit)failed_request_detail<=0;
  end
 end
end
always @(posedge clk or posedge rst) begin
 if(rst) begin sticky_error<=0;recovery_active<=0;end
 else begin
  if(rescan_event && !scan_busy) recovery_active<=1;
  if(scan_accept) sticky_error<=0;
  if(scan_result_valid && scan_result_ready) begin
   if(!scan_success) begin sticky_error<=2;recovery_active<=0;end
   else if(img_found_count==0) begin sticky_error<=1;recovery_active<=0;end
  end
  if(load_fault && load_fault_code==2) sticky_error<=2;
  if(request_failed && !timeout_stopped) sticky_error<=3;
  if(diag_commit) begin sticky_error<=0;recovery_active<=0;end
 end
end
// Cached manual switches remain available after a background timeout. Clear a
// stale failure indication on the next successful visible commit, not preload.
assign state_code=(scan_state==SC_RESET)?4'd0:
                  (scan_busy && !sd_init_done)?(sd_init_failed?4'hf:4'd0):
                  sticky_error==1?4'he:sticky_error==2?4'hf:sticky_error==3?4'hd:
                  scan_busy?bmp_state_code:normal_state_code;
// Stable status, not the transient UART event code. Match the existing panel
// error priority/clear behavior; a completed cached switch clears sticky errors.
assign osd_error_code=(scan_state==SC_RESET)?8'd0:
                      (scan_busy && !sd_init_done)?(sd_init_failed?8'd2:8'd0):
                      application_error?8'd5:app_rejected?8'd4:
                      (MENU_ENABLE && sticky_error==3 && failed_request_detail!=0)?failed_request_detail:
                      {5'd0,sticky_error};
assign source_frame_done=bmp_load_done && !menu_discard;
assign source_frame_error=parser_load_error && !menu_discard;
assign write_en=bmp_data_wr_en && !menu_discard && !parser_cancel && !parser_rst;
assign write_data=bmp_data;

// Keep original UART event IDs. WAIT phase C/D carries CACHE_DONE/CACHE_HIT.
// Defer cache/fault records so a concurrent display acknowledgement retains
// its own image index instead of borrowing the background load index.
reg [1:0] underflow_sync;
reg [2:0] reader_code0,reader_code1;
reg read_fault_seen;
wire read_fault=(underflow_sync[1] || reader_code1!=0) && USE_FRAME_RESULT;
reg pending_complete,pending_hit,pending_fault,pending_retry,pending_skip;
reg [1:0] retry_idx,skip_idx;
reg [1:0] complete_idx,hit_idx,fault_idx;
reg [2:0] fault_error;
reg [3:0] fault_phase;
reg init_seen,init_fail_seen,auto_seen,timeout_seen;
reg [15:0] diag_events;
reg [1:0] diag_image;
reg [2:0] diag_error;
reg [3:0] diag_phase;
// Performance markers share the existing nonblocking UART queue. Pending
// bits preserve concurrent events; no diagnostic signal gates business work.
reg [7:0] pending_timing;
reg menu_ready_seen,bin_pending_seen,sdram_seen,source_timing_seen,write_timing_seen;
reg [2:0] timing_slot;
always @* begin
 timing_slot=0;
 if(pending_timing[0])timing_slot=0;
 else if(pending_timing[1])timing_slot=1;
 else if(pending_timing[2])timing_slot=2;
 else if(pending_timing[3])timing_slot=3;
 else if(pending_timing[4])timing_slot=4;
 else if(pending_timing[5])timing_slot=5;
 else if(pending_timing[6])timing_slot=6;
 else timing_slot=7;
end
always @* begin
 diag_events=0;diag_image=img_idx;diag_error=0;diag_phase=1;
 if(diag_commit) begin
  diag_events[7]=1;diag_events[14]=recovery_active;diag_image=cache_display_image;diag_phase=7;
 end else if(load_start_pulse) begin diag_events[4]=1;diag_image=load_idx;diag_phase=3;end
 else if(rescan_event && !scan_busy) begin diag_events[9]=1;diag_phase=8;end
 else if(sd_init_failed && !init_fail_seen) begin diag_events[1]=1;diag_error=2;diag_phase=0;end
 else if(sd_init_done && !init_seen) begin diag_events[0]=1;diag_phase=0;end
 else if(scan_start_pulse) begin diag_events[2]=1;diag_phase=2;end
 else if(scan_result_valid && scan_result_ready) begin
  diag_events[3]=1;diag_events[12]=scan_success && img_found_count==0;diag_phase=2;
 end else if(timeout_stopped && !timeout_seen) begin diag_events[13]=1;diag_error=2;end
 else if(pending_fault) begin diag_events[8]=1;diag_image=fault_idx;diag_error=fault_error;diag_phase=fault_phase;end
 else if(pending_retry) begin diag_events[5]=1;diag_image=retry_idx;diag_phase=3;end
 else if(pending_skip) begin diag_events[6]=1;diag_image=skip_idx;diag_phase=3;end
 else if(pending_complete) begin diag_events[11]=1;diag_image=complete_idx;diag_phase=4'hc;end
 else if(pending_hit) begin diag_events[11]=1;diag_image=hit_idx;diag_phase=4'hd;end
 else if(|pending_timing)begin
  diag_events[11]=1;
  case(timing_slot)
   0:diag_phase=9;1:diag_phase=10;2:diag_phase=11;3:diag_phase=4;
   4:diag_phase=5;5:diag_phase=6;6:diag_phase=14;default:diag_phase=8;
  endcase
 end
 else if(effective_auto!=auto_seen) diag_events[10]=1;
end
always @(posedge clk or posedge rst) begin
 if(rst) begin
  diagnostics<=0;underflow_sync<=0;reader_code0<=0;reader_code1<=0;read_fault_seen<=0;
  pending_complete<=0;pending_hit<=0;pending_fault<=0;complete_idx<=0;hit_idx<=0;fault_idx<=0;fault_error<=0;fault_phase<=0;
  pending_retry<=0;pending_skip<=0;retry_idx<=0;skip_idx<=0;
  init_seen<=0;init_fail_seen<=0;auto_seen<=0;timeout_seen<=0;
  pending_timing<=0;menu_ready_seen<=0;bin_pending_seen<=0;sdram_seen<=0;source_timing_seen<=0;write_timing_seen<=0;
 end else begin
  underflow_sync<={underflow_sync[0],reader_underflow};reader_code0<=reader_error;reader_code1<=reader_code0;read_fault_seen<=read_fault;
  init_seen<=sd_init_done;init_fail_seen<=sd_init_failed;auto_seen<=effective_auto;timeout_seen<=timeout_stopped;
  diagnostics<={diag_events,diag_image,sd_sec_read_addr,diag_error,diag_phase,effective_auto};
  menu_ready_seen<=menu_ready;bin_pending_seen<=bins_pending;sdram_seen<=sdram_ready;
  source_timing_seen<=source_done_now;write_timing_seen<=write_finish_now;
  if(diag_events[11] && diag_phase!=12 && diag_phase!=13)pending_timing[timing_slot]<=0;
  if(menu_enter)pending_timing[0]<=1;
  if(menu_ready && !menu_ready_seen)pending_timing[1]<=1;
  if(menu_confirm)pending_timing[2]<=1;
  if(source_done_now && !source_timing_seen)pending_timing[3]<=1;
  if(write_finish_now && !write_timing_seen)pending_timing[4]<=1;
  if(bin_pending_seen && !bins_pending)pending_timing[5]<=1;
  if(sdram_ready && !sdram_seen)pending_timing[6]<=1;
  if(scan_done && (scan_state==SC_SCAN || scan_state==SC_DECIDE))pending_timing[7]<=1;
  if(diag_events[8]) pending_fault<=0;
  if(diag_events[5]) pending_retry<=0;
  if(diag_events[6]) pending_skip<=0;
  if(diag_events[11] && diag_phase==4'hc) pending_complete<=0;
  if(diag_events[11] && diag_phase==4'hd) pending_hit<=0;
  if(cache_complete) begin pending_complete<=1;complete_idx<=cache_complete_image;end
  if(cache_hit) begin pending_hit<=1;hit_idx<=cache_hit_image;end
  if(retry_event) begin pending_retry<=1;retry_idx<=load_idx;end
  if(load_failed && !timeout_stopped) begin pending_skip<=1;skip_idx<=failed_image;end
  if(load_fault) begin pending_fault<=1;fault_idx<=load_idx;fault_error<=load_fault_code;fault_phase<=3;end
  if(memory_failure || (read_fault && !read_fault_seen)) begin
   pending_fault<=1;fault_idx<=memory_failure?load_idx:img_idx;fault_phase<=4'hf;
   fault_error<=memory_failure?memory_code:(underflow_sync[1]?3'd4:(reader_code1==1?3'd5:3'd6));
  end
 end
end

assign desired_directory=app_target==1?(root_edu_complete?32'd0:publicity_directory):
 app_target==2 && (!root_pic_complete || menu_resource_active)?selected_directory:32'd0;
// Pending must drain an existing foreground/application/scene handover,
// including the first image at power-up. Pausing that work would prevent
// safe_menu_idle forever. Key routing already blocks new manual requests.
// Break the foreground-busy -> pause -> cache arbitration feedback path.
// Pending waits for the extra registered cycle and any offered file request
// before acquiring the shared reader, so a transaction is never stolen.
reg menu_quiesce;
reg menu_reader_idle;
always @(posedge clk or posedge rst)begin
 if(rst)begin menu_quiesce<=0;menu_reader_idle<=0;end
 else begin
  menu_quiesce<=MENU_ENABLE && menu_pending && !application_busy && !scene_fade && !foreground_busy;
  // Quiescing blocks new cache offers. Keep the live request/scan vetoes
  // below so this one-cycle reader snapshot cannot steal a just-issued job.
  menu_reader_idle<=MENU_ENABLE && menu_quiesce && scan_state==SC_IDLE && bmp_ready && !load_busy && !load_request;
 end
end
assign cache_pause=MENU_ENABLE && (menu_owner || menu_quiesce);
assign menu_pause=MENU_ENABLE && (menu_pending || menu_active);
assign safe_menu_idle=scan_state==SC_IDLE && menu_reader_idle && !scan_request && !load_request && !foreground_busy &&
 (!menu_pending || menu_quiesce) &&
 !transition_busy && !scene_fade && audio_drained && !audio_run &&
 (!application_busy || application_error);
generate if(MENU_ENABLE)begin:g_menu
 disaster_menu_control #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) ui(
  .clk(clk),.rst(rst),.sw3(sw3),.key1(key1),.key2(key2),.key4(key4),.switch_mode(mode),
  .safe_idle(safe_menu_idle),.backend_ready(menu_ready),.rejected(menu_rejected),.exit_done(menu_exit),.scene_valid(menu_valid),
  .pending(menu_pending),.active(menu_active),.enter(menu_enter),.confirm(menu_confirm),.cancel(menu_cancel),
  .focus(menu_focus),.blocked(menu_blocked),.effective_mode(effective_mode));
 disaster_menu_backend backend(.clk(clk),.rst(rst),.enter(menu_enter),.confirm(menu_confirm),.cancel(menu_cancel),.focus(menu_focus),
  .parent_valid(scene_parent_valid),.parent_cluster(scene_parent),
  .original_directory(resource_directory),.original_publicity(reader_publicity),.original_hazard(resource_hazard),
  .original_app(application_mode),
  .invalidate(scan_accept && app_physical),.native_thumb(menu_native),.reader_ready(bmp_ready),.scan_done(scan_done),.scan_error(bmp_scan_error),.mapped_valid(mapped_valid),
  .directory_valid(directory_valid),.directory_clusters(directory_clusters),
  .load_accept(load_accept),.load_result_valid(load_result_valid),.load_success(load_success),
  .source_done(bmp_load_done),.source_error(parser_load_error),
  .application_busy(application_busy),.application_error(application_error),.storage_busy(load_busy),.scene_ready(scenario_state[12] && !scene_fade),
  .display_committed(cache_display_request && cache_display_ack),.display_off(menu_display_off),
  .owner(menu_owner),.ready(menu_ready),.discard(menu_discard),.menu_write(menu_write_mode),.preview_mode(menu_preview),.fallback_thumbnail(menu_fallback),.rejected(menu_rejected),
  .scan_start(menu_scan),.directory(menu_directory),.publicity(menu_publicity),.hazard(menu_hazard),
  .load_request(menu_load_request),.load_result_ready(menu_load_ready),.direct_load(menu_direct),
  .load_index(menu_load_index),.write_slot(menu_slot),.valid(menu_valid),.visible(menu_visible),
  .force_scene(menu_force),.exit_done(menu_exit),.resume(menu_resume),
  .selected_directory(menu_selected_directory),.selected_hazard(menu_selected_hazard),.force_target(menu_force_target));
end else begin:g_no_menu
 assign menu_pending=0;assign menu_active=0;assign menu_blocked=0;assign menu_enter=0;assign menu_confirm=0;assign menu_cancel=0;
 assign menu_owner=0;assign menu_ready=0;assign menu_discard=0;assign menu_load_request=0;assign menu_load_ready=0;
 assign menu_scan=0;assign menu_direct=0;assign menu_force=0;assign menu_exit=0;assign menu_resume=0;
 assign menu_directory=0;assign menu_selected_directory=0;assign menu_hazard=0;assign menu_selected_hazard=0;assign menu_publicity=0;
 assign menu_load_index=0;assign menu_slot=0;assign menu_valid=0;assign menu_visible=0;assign menu_focus=0;
 assign menu_write_mode=0;assign effective_mode=mode;
 assign menu_preview=0;assign menu_fallback=0;assign menu_rejected=0;
 assign menu_force_target=2;
end endgenerate

fat32_bmp_reader #(.FAST_START(MENU_ENABLE),.DIRECTORY_ENABLE(MENU_ENABLE),.LOAD_BY_INDEX(1),.SCALE_ENABLE(SCALE_ENABLE),.SCAN_AUDIO(AUDIO_ENABLE),.SCAN_TEXT(SCENE_ENABLE),.SCAN_PUBLICITY(PUBLICITY_ENABLE),.CLK_FREQ_HZ(CLK_FREQ_HZ),.TIMEOUT_MS(LOAD_TIMEOUT_MS)) bmp_read_m0(
 .clk(clk),.rst(parser_rst),.sd_init_done(sd_init_done),.ready(bmp_ready),
 .menu_preview(menu_owner && menu_preview),.menu_fallback(menu_fallback),.native_thumb(menu_native),
 .audio_found(audio_found),.audio_cluster(audio_cluster),.audio_size(audio_size),
 .font_found(font_found),.font_cluster(font_cluster),.font_size(font_size),.text_found(text_found),.text_cluster(text_cluster),.text_size(text_size),
 .snd_valid(snd_valid),.snd_clusters(snd_clusters),.snd_sizes(snd_sizes),
 .map_start(map_start_pulse && !menu_owner),.resource_publicity(menu_owner?menu_publicity:map_publicity),.active_publicity(reader_publicity),.mapped_valid(mapped_valid),.scan_found_slot(),
 .pic_valid(pic_valid),.pic_clusters(pic_clusters),.pic_sizes(pic_sizes),
 .edu_valid(edu_valid),.edu_clusters(edu_clusters),.edu_sizes(edu_sizes),
 .voi_valid(voi_valid),.voi_invalid(voi_invalid),.voi_clusters(voi_clusters),.voi_sizes(voi_sizes),
 .audio_spc(audio_spc),.audio_fat_lba(audio_fat_lba),.audio_data_lba(audio_data_lba),.audio_max_cluster(audio_max_cluster),
 .a_req(bin_owner?bin_req:a_req),.a_lba(bin_owner?bin_lba:a_lba),.a_cancel(!bin_owner && !audio_run),.a_urgent(bin_owner?1'b1:a_urgent),
 .a_busy(a_busy),.a_valid(a_valid),.a_done(a_done),.a_error(a_error),.a_byte(a_byte),.a_index(a_index),
 .directory_cluster(menu_owner?menu_directory:resource_directory),.expected_hazard(menu_owner?menu_hazard:resource_hazard),
 .directory_valid(directory_valid),.directory_clusters(directory_clusters),
 .scan_start(menu_owner?menu_scan:scan_start_pulse),.scan_done(scan_done),.scan_error(bmp_scan_error),
 .scan_found_valid(scan_found_valid),.scan_found_cluster(scan_found_cluster),.scan_found_size(scan_found_size),.scan_found_total(scan_found_total),
 .load_start(menu_discard?menu_direct:load_start_pulse),.load_cancel(MENU_ENABLE?parser_cancel_q:parser_cancel),.load_cluster(32'd0),.load_size(32'd0),.load_index(menu_owner?menu_load_index:load_idx),
 .loaded_kind(loaded_kind),.load_done(bmp_load_done),.load_error(parser_load_error),.bmp_error(parser_error),.fat_error(parser_fat_error),
 .state_code(bmp_state_code),.bmp_width(bmp_width),.bmp_height(bmp_height),.write_req(parser_write_req),.write_req_ack(menu_discard?1'b1:write_req_ack_sync),.write_ready(menu_discard?1'b1:write_ready),
 .sd_sec_read(sd_sec_read),.sd_sec_read_addr(sd_sec_read_addr),.sd_sec_read_data(sd_sec_read_data),
 .sd_sec_read_data_valid(sd_sec_read_data_valid),.sd_sec_read_end(sd_sec_read_end),.sd_sec_read_failed(sd_sec_read_failed),
 .bmp_data_wr_en(bmp_data_wr_en),.bmp_data(bmp_data)
);
sd_card_top #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) sd_card_top_m0(
 .clk(clk),.rst(sd_local_rst),.SD_nCS(SD_nCS),.SD_DCLK(SD_DCLK),.SD_MOSI(SD_MOSI),.SD_MISO(SD_MISO),
 .sd_debug(sd_debug),.sd_init_failed(sd_init_failed),.sd_init_done(sd_init_done),
 .sd_sec_read(sd_sec_read),.sd_sec_read_addr(sd_sec_read_addr),.sd_sec_read_data(sd_sec_read_data),
 .sd_sec_read_data_valid(sd_sec_read_data_valid),.sd_sec_read_end(sd_sec_read_end),.sd_sec_read_failed(sd_sec_read_failed),
 .sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),.sd_sec_write_data(),.sd_sec_write_data_req(),.sd_sec_write_end()
);
endmodule

// Application identity is independent of the switch page. A logical reload
// uses the cache's cancel/drain handshake, never the physical SD reset.
// app: 0 COMPAT, 1 PUBLICITY, 2 SCENARIO. Target stays bundled through commit.
module publicity_app_control #(parameter MENU_ENABLE=0,FAST_BOOT=0)(
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
   // Decode boundary outputs from the local transition conditions. A full
   // next_state decode needlessly includes alternate-application arbitration.
   if(state==RUN || state==ERROR ||
      ((state==BOOT || state==LOAD) && scan_valid && !scan_success) ||
      (state==FIRST && (failed || (committed && boot_direct))) ||
      (state==READY && failed) || (state==FADE_IN && !fade_busy))boot_direct<=0;
   case(state)
    RUN:busy<=(MENU_ENABLE && force_request) || rescan_request || (toggle_request && alternate_available);
    FIRST:busy<=failed || !committed || !boot_direct;
    FADE_IN:busy<=fade_busy;
    default:busy<=1;
   endcase
   case(state)
    RUN:begin stop_audio<=0;scene_enable<=app==2;end
    WAIT_IDLE:begin stop_audio<=idle;scene_enable<=app==2 && !idle;end
    FIRST:begin stop_audio<=failed || !committed;scene_enable<=!failed && committed && target==2;end
    READY:begin stop_audio<=failed;scene_enable<=app==2 && !failed;end
    FADE_IN:begin stop_audio<=0;scene_enable<=app==2;end
    default:begin stop_audio<=1;scene_enable<=0;end
   endcase
  end
 end
endmodule


// One request per actual display commit, including preview commits of the same
// page. Completion identity is accepted only after the common stop/start ack.
module publicity_voice_control #(parameter MIN_FRAMES=300, MENU_ENABLE=0)(
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
 reg [1:0] state_n,page_n,tail_frames_n;
 reg [15:0] identity_n;
 reg [8:0] dwell_n;
 reg advanced_n,auto_enable_n,auto_armed;
 reg [2:0] status_n;
 wire terminal=status==0 || status==3 || status==4;
 assign voice_request=state==REQUEST;
 assign fade=enable && (page_pending || state==WAIT || state==REQUEST);
 // request_ready depends on the selected request_image in the shared cache.
 // Keep valid independent of ready; only acceptance can use that feedback.
 assign auto_offer=!(MENU_ENABLE && pause) && enable && auto_armed && ui_play && !busy && !page_pending &&
                   !manual && !toggle_auto;
 assign auto_accept=auto_offer && offer_ready;
 // Compute the next registered state once. The registered summary removes
 // the dwell/status reduction from the shared cache request/ready path.
 always @* begin
  state_n=state;page_n=page;identity_n=identity;dwell_n=dwell;tail_frames_n=tail_frames;
  advanced_n=advanced;auto_enable_n=auto_enable;status_n=status;
  if(MENU_ENABLE && restart && enable)begin state_n=WAIT;status_n=1;dwell_n=0;tail_frames_n=0;advanced_n=0;end
  else if(MENU_ENABLE && pause)begin dwell_n=0;tail_frames_n=0;end
  else if(!enable)begin state_n=OFF;dwell_n=0;tail_frames_n=0;advanced_n=0;auto_enable_n=0;status_n=1;end
  else begin
   if(toggle_auto && !busy)auto_enable_n=!auto_enable;
   if(!ui_play || busy || page_pending || state!=RUN)dwell_n=0;
   else if(frame_tick && dwell<MIN_FRAMES)dwell_n=dwell+1'b1;
   if(state==RUN && terminal && frame_tick && tail_frames<2)tail_frames_n=tail_frames+1'b1;
   if(auto_accept)advanced_n=1;
   if(commit)begin page_n=commit_page;state_n=WAIT;status_n=1;dwell_n=0;tail_frames_n=0;advanced_n=0;end
   else case(state)
    WAIT:if(!busy && !audio_ready)state_n=REQUEST;
    REQUEST:if(audio_ready)begin
     identity_n=session_id;state_n=RUN;
     status_n=stream_error!=0?3'd4:!selected_found?3'd0:3'd2;
    end
    RUN:if(selected_publicity && session_id==identity)begin
     if(stream_error!=0)status_n=4;
     else if(done && done_id==identity && status==2)status_n=3;
    end
    default:;
   endcase
  end
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   state<=OFF;page<=0;identity<=0;dwell<=0;tail_frames<=0;advanced<=0;auto_enable<=0;status<=1;auto_armed<=0;
  end else begin
   state<=state_n;page<=page_n;identity<=identity_n;dwell<=dwell_n;tail_frames<=tail_frames_n;
   advanced<=advanced_n;auto_enable<=auto_enable_n;status<=status_n;
   auto_armed<=state_n==RUN && auto_enable_n && !advanced_n && dwell_n>=MIN_FRAMES &&
     (status_n==0 || status_n==3 || status_n==4) && tail_frames_n==2;
  end
 end
endmodule
