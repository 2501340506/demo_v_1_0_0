
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
    parameter integer SCENE_ENABLE = 0
)(
    output                      bgm_valid,bgm_active,
    output signed [15:0]        bgm_left,bgm_right,
    input                       bgm_ready,
    input                       scenario_muted,
    output                      scenario_fade,
    output [12:0]               scenario_state,
    output [4:0] scenario_meta,
    output font_valid,text_valid,output [7:0] font_count,output [12:0] text_bytes,
    output bin_wr_en,bin_wr_text,output [11:0] bin_wr_addr,output [7:0] bin_wr_data,
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
wire scan_request,scan_accept,scan_result_ready,scan_busy;
reg scan_result_valid,scan_success,scan_error_seen;
reg [2:0] img_found_count;
wire [1:0] img_idx,load_idx,current_bank;

localparam SC_IDLE=0,SC_RESET=1,SC_INIT=2,SC_SCAN=3,SC_RESULT=4,SC_BIN_START=5,SC_BIN_WAIT=6;
reg [2:0] scan_state;
reg [3:0] reset_count;
reg scan_start_pulse;
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
wire scene_mode,scene_next,scene_warn,scene_speed;
wire scene_request,scene_request_accept;
wire [1:0] scene_target;
wire scene_owns=scene_mode || scenario_fade;
wire [31:0] audio_cluster,audio_size,audio_fat_lba,audio_data_lba,audio_max_cluster;
wire [7:0] audio_spc;
wire a_req,a_busy,a_valid,a_done,a_urgent;
wire [31:0] a_lba;
wire [7:0] a_error,a_byte;
wire [8:0] a_index;
wire font_found,text_found;
wire [31:0] font_cluster,font_size,text_cluster,text_size;
wire bin_done,bin_req;wire [31:0] bin_lba;
wire bin_owner=SCENE_ENABLE && (scan_state==SC_BIN_START || scan_state==SC_BIN_WAIT);
generate if(SCENE_ENABLE)begin:g_bins
 bin_to_bram_loader loader(.clk(clk),.rst(parser_rst),.start(scan_state==SC_BIN_START),
  .font_found(font_found),.text_found(text_found),.font_cluster(font_cluster),.font_size(font_size),
  .text_cluster(text_cluster),.text_size(text_size),.spc(audio_spc),.fat_lba(audio_fat_lba),
  .data_lba(audio_data_lba),.max_cluster(audio_max_cluster),.done(bin_done),
  .font_valid(font_valid),.text_valid(text_valid),.font_count(font_count),.text_bytes(text_bytes),
  .wr_en(bin_wr_en),.wr_text(bin_wr_text),.wr_addr(bin_wr_addr),.wr_data(bin_wr_data),
  .sector_req(bin_req),.sector_lba(bin_lba),.sector_busy(a_busy),.sector_valid(a_valid && bin_owner),
  .sector_done(a_done && bin_owner),.sector_byte(a_byte),.sector_error(a_error),.sector_index(a_index));
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
assign scan_accept=scan_request && scan_state==SC_IDLE && !audio_run && audio_stopped;
always @(posedge clk or posedge rst) begin
 if(rst)audio_session<=0;
 else if(scan_request || rescan_event)audio_session<=0;
 else if(scan_result_valid && scan_result_ready)audio_session<=scan_success;
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
 fat32_pcm_stream u_stream(
 .clk(clk),.rst_n(!rst),.enable(audio_run),.audio_found(selected_audio_found),
 .first_cluster(selected_audio_cluster),.file_size(selected_audio_size),.sectors_per_cluster(audio_spc),
 .fat_start_lba(audio_fat_lba),.data_start_lba(audio_data_lba),.max_cluster(audio_max_cluster),
 .sector_permit(sector_permit),.player_stopped(player_stopped),.player_ready(file_ready),
 .player_enable(player_enable),.file_valid(file_valid),.file_byte(file_byte),
 .stopped(audio_stopped),.error_code(audio_stream_error),.loop_count(),
 .sector_req(a_req),.sector_lba(a_lba),.sector_busy(a_busy),.sector_valid(a_valid && !bin_owner),
 .sector_done(a_done && !bin_owner),.sector_byte(a_byte),.sector_error(a_error),.sector_index(a_index));
 pcm_stream_player u_player(
 .wr_clk(clk),.wr_rst_n(!rst),.play_enable(player_enable),
 .file_valid(file_valid),.file_byte(file_byte),.file_ready(file_ready),
 .sector_permit(sector_permit),.buffer_low(player_low),.stopped(player_stopped),.write_level(),
 .rd_clk(transition_pix_clk),.rd_rst_n(!transition_pix_rst),.sample_ready(bgm_ready),
 .sample_valid(bgm_valid),.sample_left(bgm_left),.sample_right(bgm_right),
 .active(bgm_active),.underflow_count(),.output_overrun());
end else begin: g_no_audio
 assign audio_stopped=1'b1;assign a_req=1'b0;assign a_lba=0;assign a_urgent=0;
 assign bgm_valid=0;assign bgm_active=0;assign bgm_left=0;assign bgm_right=0;
 assign audio_stream_error=0;
end endgenerate
always @(posedge clk or posedge rst) begin
 if(rst) begin
  scan_state<=SC_IDLE;reset_count<=0;scan_start_pulse<=0;scan_result_valid<=0;scan_success<=0;
  scan_error_seen<=0;img_found_count<=0;
 end else begin
  scan_start_pulse<=0;
  case(scan_state)
   SC_IDLE: if(scan_accept) begin
    scan_state<=SC_RESET;reset_count<=0;img_found_count<=0;scan_error_seen<=0;
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
     if(SCENE_ENABLE && !scan_error_seen && !bmp_scan_error)scan_state<=SC_BIN_START;
     else begin scan_result_valid<=1;scan_state<=SC_RESULT;end
    end
   end
   SC_BIN_START:scan_state<=SC_BIN_WAIT;
   SC_BIN_WAIT:if(bin_done)begin scan_result_valid<=1;scan_state<=SC_RESULT;end
   SC_RESULT: if(scan_result_ready) begin scan_result_valid<=0;scan_state<=SC_IDLE;end
   default:scan_state<=SC_IDLE;
  endcase
 end
end

wire load_request,load_accept,load_result_valid,load_result_ready,load_success,load_timeout;
wire cancel_request,cancel_ack,parser_cancel,load_start_pulse;
wire source_done_now,write_finish_now,load_fault,memory_failure;
wire [2:0] load_fault_code,memory_code;
wire load_busy,foreground_busy,timeout_stopped,first_image_committed;
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
 .clk(clk),.rst(rst),.load_request(load_request),.load_accept(load_accept),
 .load_result_valid(load_result_valid),.load_success(load_success),.load_timeout(load_timeout),
 .load_result_ready(load_result_ready),.cancel_request(cancel_request),.cancel_ack(cancel_ack),
 .parser_ready(bmp_ready),.source_done(bmp_load_done),.source_error(parser_load_error),.source_error_code(parser_error),
 .load_start(load_start_pulse),.parser_cancel(parser_cancel),
 .write_req(write_req),.write_req_ack(write_req_ack),.write_finish_toggle(write_finish_toggle),
 .frame_error_toggle(frame_error_toggle),.frame_memory_error(frame_memory_error),
 .write_cancel_req(write_cancel_req),.write_cancel_ack(write_cancel_ack),
 .fault_event(load_fault),.fault_code(load_fault_code),.memory_fault(memory_failure),.memory_code(memory_code),
 .source_complete(source_done_now),.write_complete(write_finish_now)
);

wire preview_intent,preview_selecting,preview_fullscreen_ready,preview_offer,preview_key_toggle;
assign preview_key_toggle=PREVIEW_ENABLE && mode==3 && media_auto_toggle_request;
wire cache_display_request,cache_display_ack;
wire transition_permit, transition_busy;
wire scene_muted_sd,scene_audio_running;
reg transition_auto;
wire [1:0] cache_display_image,cache_display_bank;
wire transition_needed=TRANSITION_ENABLE && !preview_selecting && first_image_committed &&
                       display_valid && cache_display_bank!=current_bank;
video_transition_sd_control #(.ENABLE(TRANSITION_ENABLE)) u_transition_sd_control(
 .clk(clk),.rst(rst),.display_request(cache_display_request),.display_valid(transition_needed),.request_wipe(transition_auto),
 .pix_clk(transition_pix_clk),.pix_rst(transition_pix_rst),
 .frame_start(transition_frame_start),.commit_done(transition_commit_done),
 .transition_busy(transition_busy),.transition_active(transition_active),
 .transition_level(transition_level),.permit_commit(transition_permit),.wipe_active(transition_wipe));
reg rescan_pending;
wire rescan_wait=(rescan_pending || rescan_raw);
assign rescan_event=(TRANSITION_ENABLE || PREVIEW_ENABLE) ? (rescan_pending && !transition_busy && preview_fullscreen_ready) : rescan_raw;
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
 if(rst) begin commit_pending<=0;display_commit_request<=0;disp_buf_idx<=0;end
 else begin
  if(!cache_display_request) commit_pending<=0;
  else if(!commit_pending && preview_fullscreen_ready && (!transition_needed || transition_permit) &&
          (!scene_owns || !scene_audio_running || scene_muted_sd)) begin
   disp_buf_idx<=cache_display_bank;
   display_commit_request<=~display_commit_request;
   commit_pending<=1;
  end
 end
end
wire ctrl_auto_play_en,ctrl_next_pending,ctrl_prev_pending,ctrl_auto_tick,ctrl_load_request;
wire ctrl_request_ready,ctrl_request_accept,ctrl_auto_load_request;
wire [1:0] ctrl_target_image;
wire transition_block=transition_busy || rescan_wait;
wire ctrl_offer=ctrl_load_request && !scene_owns && !transition_block && !preview_intent && !preview_selecting;
wire [1:0] preview_target;
wire cache_offer=ctrl_offer || preview_offer || (scene_request && !transition_block);
wire [1:0] cache_target=scene_request?scene_target:preview_offer?preview_target:ctrl_target_image;
assign scene_request_accept=scene_request && ctrl_request_ready && !transition_block;
generate if(PREVIEW_ENABLE)begin:g_preview
 media_preview_control control(.clk(clk),.rst(rst),.mode(mode),.scan_busy(scan_busy),
 .first_image_committed(first_image_committed),.transition_busy(transition_busy),.foreground_busy(foreground_busy),
 .rescan_wait(rescan_wait),.next_event(media_next_request),.previous_event(media_previous_request),.toggle_event(preview_key_toggle),
 .current_image(img_idx),.image_count(image_count),.cache_valid(cache_valid),.cache_banks(cache_banks),
 .request_ready(ctrl_request_ready),.request_failed(request_failed),.storage_stopped(timeout_stopped),.display_request(cache_display_request),.display_committed(cache_display_ack),
 .request_valid(preview_offer),.request_image(preview_target),.preview_intent(preview_intent),.selecting(preview_selecting),
 .fullscreen_ready(preview_fullscreen_ready),.preview_request(preview_request),.preview_descriptor(preview_descriptor),.preview_ack(preview_ack));
end else begin:g_no_preview
 assign preview_intent=0;assign preview_selecting=0;assign preview_fullscreen_ready=1;
 assign preview_offer=0;assign preview_target=0;assign preview_request=0;assign preview_descriptor=0;
end endgenerate
assign ctrl_request_accept=ctrl_offer && ctrl_request_ready;
// Capture origin at acceptance, not when queued keys or AUTO state later change.
always @(posedge clk or posedge rst) begin
 if(rst) transition_auto<=0;
 else if(rescan_event) transition_auto<=0;
 else if(ctrl_request_accept) transition_auto<=ctrl_auto_load_request;
end
media_frame_cache_control u_cache_control(
 .clk(clk),.rst(rst),.rescan_event(rescan_event),
 .scan_request(scan_request),.scan_accept(scan_accept),.scan_result_valid(scan_result_valid),
 .scan_success(scan_success),.scan_image_count(img_found_count),.scan_result_ready(scan_result_ready),.scan_busy(scan_busy),
 .request_valid(cache_offer),.request_image(cache_target),
 .request_manual(scene_request || preview_offer || ctrl_next_pending || ctrl_prev_pending),.request_ready(ctrl_request_ready),.foreground_busy(foreground_busy),
 .load_request(load_request),.load_accept(load_accept),.load_image(load_idx),.load_bank(write_buf_idx),
 .load_result_valid(load_result_valid),.load_success(load_success),.load_timeout(load_timeout),.load_result_ready(load_result_ready),
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
mode_key_control #(.PREVIEW_ENABLE(PREVIEW_ENABLE),.SCENE_ENABLE(SCENE_ENABLE),.CLK_FREQ_HZ(CLK_FREQ_HZ)) u_mode_key_control(
 .clk(clk),.rst(rst),.enable(!scan_busy),.key1(key1),.key2(key2),.key4(key4),.mode(mode),
 .rescan_event(rescan_raw),.next_event(media_next_request),.previous_event(media_previous_request),
 .auto_toggle_event(media_auto_toggle_request),.manual_activity(manual_activity),
 .scene_allowed(first_image_committed && image_count==4 && !scan_busy),
 .scene_mode(scene_mode),.scene_next(scene_next),.scene_warn(scene_warn),.scene_speed(scene_speed),
 .adjust_decrease(adjust_decrease),.adjust_increase(adjust_increase),.adjust_restore(adjust_restore),.adjust_select(adjust_select)
);
media_player_control #(.AUTO_PLAY_CYCLES((CLK_FREQ_HZ/1000)*AUTO_PLAY_MS)) u_media_player_control(
 .clk(clk),.rst(rst),.enable(!scan_busy && !scene_owns && !preview_intent && !preview_selecting),.scan_done(!scan_busy),
 .display_valid(display_valid),.load_busy(foreground_busy || transition_block),.first_image_committed(first_image_committed),
 .image_count(image_count),.current_image(img_idx),.mode(mode),.next_event(media_next_request),
 .previous_event(media_previous_request),.auto_toggle_event(media_auto_toggle_request),
 .request_accept(ctrl_request_accept),.manual_activity(manual_activity),
 .next_load_request(),.previous_load_request(),.auto_load_request(ctrl_auto_load_request),
 .auto_play_en(ctrl_auto_play_en),.next_pending(ctrl_next_pending),.previous_pending(ctrl_prev_pending),
 .auto_tick(ctrl_auto_tick),.load_request(ctrl_load_request),.target_image(ctrl_target_image)
);
generate if(SCENE_ENABLE)begin:g_scenario
 wire sample_tick,frame_tick,audio_request,audio_scene,audio_ready,layer_enable;
 wire [1:0] stage,speed,alert_level,audio_stage,selected_stage;
 wire [7:0] t_now;
 wire warn_mode,selected_scene;
 assign scenario_meta={scene_mode,warn_mode,speed,1'b0};
 (* ASYNC_REG="TRUE" *) reg [1:0] muted_sync,active_sync;
 always @(posedge clk or posedge rst)begin
  if(rst)begin muted_sync<=0;active_sync<=0;end
  else begin muted_sync<={muted_sync[0],scenario_muted};active_sync<={active_sync[0],bgm_active};end
 end
 assign scene_muted_sd=muted_sync[1];
 assign scene_audio_running=active_sync[1] && selected_audio_found && audio_stream_error==0;
 scene_event_cdc events(.pix_clk(transition_pix_clk),.pix_rst(transition_pix_rst),
  .sample_accept(bgm_valid && bgm_ready),.frame_start(transition_frame_start),
  .clk(clk),.rst(rst),.sample_tick(sample_tick),.frame_tick(frame_tick));
 scenario_fsm control(.clk(clk),.rst(rst),.enable(scene_mode),
  .scene_ready(first_image_committed && image_count==4 && !scan_busy),
  .key_next(scene_next),.key_mode(scene_warn),.key_speed(scene_speed),
  .sample_tick(sample_tick),.audio_running(scene_audio_running),.frame_start(frame_tick),.muted(scene_muted_sd),
  .request_ready(scene_request_accept),.picture_done(cache_display_ack),.picture_failed(request_failed),
  .transition_idle(!transition_busy),.audio_ready(audio_ready),.stage(stage),.speed(speed),.warn_mode(warn_mode),
  .t_now(t_now),.alert_level(alert_level),.stage_req(scene_request),.requested_stage(scene_target),
  .fade_mute(scenario_fade),.layer_enable(layer_enable),
  .audio_request(audio_request),.audio_scene(audio_scene),.audio_stage(audio_stage));
 scenario_audio_control audio_control(.clk(clk),.rst(rst),.request(audio_request),
  .request_scene(audio_scene),.request_stage(audio_stage),.stopped(audio_stopped),
  .sample_tick(sample_tick),.session_enable(audio_session),.stream_error(audio_stream_error),
  .selected_found(selected_audio_found),.run_enable(scene_stream_run),
  .selected_scene(selected_scene),.selected_stage(selected_stage),.ready(audio_ready));
 wire use_snd=selected_scene && snd_valid[selected_stage];
 assign selected_audio_found=use_snd || audio_found;
 assign selected_audio_cluster=use_snd?snd_clusters[selected_stage*32+:32]:audio_cluster;
 assign selected_audio_size=use_snd?snd_sizes[selected_stage*32+:32]:audio_size;
 assign scenario_state={layer_enable,alert_level,stage,t_now};
end else begin:g_no_scenario
 assign scene_request=0;assign scene_target=0;assign scenario_state=0;assign scenario_meta=0;assign scenario_fade=0;
 assign scene_muted_sd=0;assign scene_audio_running=0;assign scene_stream_run=1;
 assign selected_audio_found=audio_found;assign selected_audio_cluster=audio_cluster;assign selected_audio_size=audio_size;
end endgenerate
media_display_control #(.CLK_FREQ_HZ(CLK_FREQ_HZ),.DIAG_DISPLAY(DIAG_DISPLAY)) u_media_display_control(
 .clk(clk),.rst(rst),.combo_request(1'b0),.sd_init_done(sd_init_done),.scan_done(!scan_busy),
 .display_valid(display_valid),.load_busy(foreground_busy),.write_started_seen(write_req),
 .source_done_now(source_done_now),.write_finish_now(write_finish_now),.img_idx(img_idx),
 .bmp_state_code(bmp_state_code),.state_code(normal_state_code),.auto_play_en(ctrl_auto_play_en),
 .auto_play_indicator(auto_play_indicator),.combo_event_count(combo_event_count),.combo_debug_active(combo_debug_active)
);
reg [2:0] sticky_error;
reg recovery_active;
wire diag_commit=cache_display_request && cache_display_ack;
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
                      {5'd0,sticky_error};
assign source_frame_done=bmp_load_done;
assign source_frame_error=parser_load_error;
assign write_en=bmp_data_wr_en && !parser_cancel && !parser_rst;
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
 else if(ctrl_auto_play_en!=auto_seen) diag_events[10]=1;
end
always @(posedge clk or posedge rst) begin
 if(rst) begin
  diagnostics<=0;underflow_sync<=0;reader_code0<=0;reader_code1<=0;read_fault_seen<=0;
  pending_complete<=0;pending_hit<=0;pending_fault<=0;complete_idx<=0;hit_idx<=0;fault_idx<=0;fault_error<=0;fault_phase<=0;
  pending_retry<=0;pending_skip<=0;retry_idx<=0;skip_idx<=0;
  init_seen<=0;init_fail_seen<=0;auto_seen<=0;timeout_seen<=0;
 end else begin
  underflow_sync<={underflow_sync[0],reader_underflow};reader_code0<=reader_error;reader_code1<=reader_code0;read_fault_seen<=read_fault;
  init_seen<=sd_init_done;init_fail_seen<=sd_init_failed;auto_seen<=ctrl_auto_play_en;timeout_seen<=timeout_stopped;
  diagnostics<={diag_events,diag_image,sd_sec_read_addr,diag_error,diag_phase,ctrl_auto_play_en};
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

fat32_bmp_reader #(.LOAD_BY_INDEX(1),.SCALE_ENABLE(SCALE_ENABLE),.SCAN_AUDIO(AUDIO_ENABLE),.SCAN_TEXT(SCENE_ENABLE),.CLK_FREQ_HZ(CLK_FREQ_HZ),.TIMEOUT_MS(LOAD_TIMEOUT_MS)) bmp_read_m0(
 .clk(clk),.rst(parser_rst),.sd_init_done(sd_init_done),.ready(bmp_ready),
 .audio_found(audio_found),.audio_cluster(audio_cluster),.audio_size(audio_size),
 .font_found(font_found),.font_cluster(font_cluster),.font_size(font_size),.text_found(text_found),.text_cluster(text_cluster),.text_size(text_size),
 .snd_valid(snd_valid),.snd_clusters(snd_clusters),.snd_sizes(snd_sizes),
 .audio_spc(audio_spc),.audio_fat_lba(audio_fat_lba),.audio_data_lba(audio_data_lba),.audio_max_cluster(audio_max_cluster),
 .a_req(bin_owner?bin_req:a_req),.a_lba(bin_owner?bin_lba:a_lba),.a_cancel(!bin_owner && !audio_run),.a_urgent(bin_owner?1'b1:a_urgent),
 .a_busy(a_busy),.a_valid(a_valid),.a_done(a_done),.a_error(a_error),.a_byte(a_byte),.a_index(a_index),
 .scan_start(scan_start_pulse),.scan_done(scan_done),.scan_error(bmp_scan_error),
 .scan_found_valid(scan_found_valid),.scan_found_cluster(scan_found_cluster),.scan_found_size(scan_found_size),.scan_found_total(scan_found_total),
 .load_start(load_start_pulse),.load_cancel(parser_cancel),.load_cluster(32'd0),.load_size(32'd0),.load_index(load_idx),
 .load_done(bmp_load_done),.load_error(parser_load_error),.bmp_error(parser_error),.fat_error(),
 .state_code(bmp_state_code),.bmp_width(bmp_width),.bmp_height(bmp_height),.write_req(write_req),.write_req_ack(write_req_ack_sync),.write_ready(write_ready),
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

