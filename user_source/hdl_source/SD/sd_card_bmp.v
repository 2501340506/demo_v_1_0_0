
module sd_card_bmp #(
    parameter integer CLK_FREQ_HZ       = 100_000_000,
    parameter [31:0]  SCAN_START_SECTOR = 32'd0,
    parameter [31:0]  SCAN_MAX_SECTOR   = 32'd131071,
    parameter [2:0]   SCAN_TARGET_COUNT = 3'd4,
    parameter integer AUTO_PLAY_MS       = 3000,
    parameter integer LOAD_TIMEOUT_MS    = 500,
    parameter integer DIAG_DISPLAY       = 0
)(
    input                       clk,
    input                       rst,
    input                       sdram_ready, // Synchronized into clk; gates first scan only.
    input                       key1,
    input                       key2,
    input                       key4,
    input [1:0]                 mode,
    output     [3:0]            state_code,
    output [63:0]               sd_debug,
    output reg [57:0]          diagnostics,
    output     [7:0]            combo_event_count,
    output                      combo_debug_active,
    output                      auto_play_indicator,
    input  [15:0]               bmp_width,
    input  [15:0]               bmp_height,
    output reg                  display_valid,
    output reg [1:0]            committed_image,
    output reg                  committed_valid,
    input                       committed_ready,

    output reg write_cancel_req,
    input write_cancel_ack,
    input                       write_finish_toggle,
    input                       display_commit_ack,
    output reg                  display_commit_request,
    output reg [1:0]            write_buf_idx,
    output reg [1:0]            disp_buf_idx,

    output                      write_req,
    input                       write_req_ack,
    output                      write_en,
    output [31:0]               write_data,
    output                      SD_nCS,
    output                      SD_DCLK,
    output                      SD_MOSI,
    input                       SD_MISO
);

wire rescan_event;
wire sd_init_failed, sd_sec_read_failed;
reg [2:0] recovery_phase;
reg [3:0] recovery_reset_count;
reg [1:0] cancel_ack_sync;
wire recovery_active = recovery_phase != 0;
wire recovering_reset = recovery_phase >= 1 && recovery_phase <= 3;
wire parser_rst = rst || recovering_reset;
wire sd_local_rst = rst || recovery_phase == 2;
wire manual_activity;
wire media_next_request, media_previous_request, media_auto_toggle_request;
wire ctrl_auto_play_en, ctrl_next_pending, ctrl_prev_pending, ctrl_auto_tick, ctrl_load_request;
wire [1:0] ctrl_target_image;
wire ctrl_request_accept;
wire ctrl_auto_load_request;
wire [3:0] normal_state_code;
wire bmp_load_done, bmp_load_error, bmp_scan_error;
reg timeout_stopped;
wire [2:0] bmp_error;
wire timeout_event = sd_sec_read_failed || bmp_scan_error || (bmp_load_error && bmp_error == 3'd2);
reg [2:0] sticky_error;
reg retry_used, restart_pending, recovery_chain;
reg first_load_failed, auto_blocked;
reg [2:0] candidates_tried;

wire             sd_sec_read;
wire [31:0]      sd_sec_read_addr;
wire [7:0]       sd_sec_read_data;
wire             sd_sec_read_data_valid;
wire             sd_sec_read_end;
wire             bmp_data_wr_en;
wire [23:0]      bmp_data;
wire             sd_init_done;
wire             bmp_ready;
wire             scan_done;
wire             scan_found_valid;
wire [31:0]      scan_found_sector;
wire [2:0]       scan_found_total;
wire [3:0]       bmp_state_code;
wire             write_req_ack_sync;
reg [1:0]        write_req_ack_pipe;

reg              scan_start_pulse;
reg              load_start_pulse;
wire [31:0]      load_sector;
reg              scan_kicked;
reg              first_image_committed;
reg [2:0]        img_found_count;
reg [1:0]        img_idx;              // 当前真正显示中的图片编号
reg [1:0]        load_idx;             // 当前正在写入的图片编号
reg [1:0]        pending_buf_idx;      // 当前正在写入的目标缓冲区
reg [31:0]       img_sector0;
reg [31:0]       img_sector1;
reg [31:0]       img_sector2;
reg [31:0]       img_sector3;
reg              load_busy;
reg              commit_pending;
reg [1:0]        commit_ack_sync;

// Source completion is the parser's explicit success, never merely ready.
reg              source_busy_seen;
reg              source_done_seen;
reg              write_finish_seen;
reg              write_started_seen;
reg              write_epoch_active;

// 同步 mem_clk 域的 write_finish_toggle
reg [2:0]        wrfin_tgl_sync;
wire             write_finish_pulse;
wire             current_write_finish;

wire source_done_now;
wire write_finish_now;

localparam integer AUTO_PLAY_CYCLES  = (CLK_FREQ_HZ / 1000) * AUTO_PLAY_MS;

// Consume a queued request only on the edge where this block can actually
// start a new load.  Without the busy guard, the control block clears its
// pending direction while the loader is still handling a prior request.
assign ctrl_request_accept = !recovery_active && ctrl_load_request && !load_busy && bmp_ready && !timeout_stopped && !timeout_event &&
                             (ctrl_next_pending || ctrl_prev_pending || !auto_blocked);
// With load_request asserted, pending directions select manual requests;
// AUTO requires both pending flags clear. Avoid feeding the full AUTO request
// availability cone back through acceptance just to distinguish the source.
assign state_code = sd_init_failed ? 4'hf :
                    recovering_reset ? 4'h0 :
                    (recovery_active && !sd_init_done) ? 4'h0 :
                    (sticky_error == 3'd1) ? 4'he :
                    (sticky_error == 3'd2) ? 4'hf :
                    (sticky_error == 3'd3) ? 4'hd :
                    recovery_active ? bmp_state_code : normal_state_code;
assign write_en   = bmp_data_wr_en && !recovering_reset;
assign write_data = {bmp_data[23:16], bmp_data[15:8], bmp_data[7:0], 8'b0};
assign write_finish_pulse = wrfin_tgl_sync[2] ^ wrfin_tgl_sync[1];
assign source_done_now = source_done_seen || bmp_load_done;
assign current_write_finish = write_epoch_active && !write_req_ack_sync && write_finish_pulse;
assign write_finish_now = write_finish_seen || current_write_finish;
assign write_req_ack_sync = write_req_ack_pipe[1];

// Observation only: use real transactions, never the multiplexed panel code.
// Packet = {events[15:0], image[1:0], sector[31:0], error[2:0], phase[3:0], auto}.
reg diag_init_seen, diag_init_fail_seen, diag_scan_seen, diag_auto_seen;
reg [3:0] diag_phase_seen;
wire diag_rescan = rescan_event && !recovery_active;
wire diag_running = !diag_rescan && !recovering_reset &&
                    !timeout_event && !timeout_stopped && sd_init_done;
wire diag_failure = diag_running && load_busy && bmp_load_error;
wire diag_commit = !diag_rescan && commit_pending &&
                   commit_ack_sync[1] == display_commit_request &&
                   (recovering_reset || (diag_running && !bmp_load_error &&
                   !restart_pending && (!committed_valid || committed_ready)));
wire diag_timeout = !diag_rescan && !recovering_reset && timeout_event && !timeout_stopped;
wire [3:0] diag_phase = (recovery_phase == 1) ? 4'd8 :
                        (recovery_phase == 2 || recovery_phase == 3) ? 4'd9 :
                        !sd_init_done ? 4'd0 :
                        commit_pending ? 4'd7 :
                        (load_busy && source_done_seen && !write_finish_seen) ? 4'd6 :
                        !load_busy ? ((!scan_done && scan_kicked) ? 4'd2 : 4'd1) :
                        write_req ? 4'd4 : (write_started_seen ? 4'd5 : 4'd3);
reg [15:0] diag_events;
reg [2:0] diag_error;
always @* begin
    diag_events=0;
    diag_events[0]=sd_init_done && !diag_init_seen;
    diag_events[1]=sd_init_failed && !diag_init_fail_seen;
    diag_events[2]=scan_start_pulse;
    diag_events[3]=scan_done && !diag_scan_seen;
    diag_events[4]=load_start_pulse;
    diag_events[5]=diag_failure && !retry_used;
    diag_events[6]=diag_failure && retry_used && recovery_chain &&
                    (!first_image_committed || ctrl_auto_play_en) && candidates_tried < img_found_count;
    diag_events[7]=diag_commit;
    diag_events[8]=diag_failure || diag_timeout;
    diag_events[9]=diag_rescan;
    diag_events[10]=ctrl_auto_play_en != diag_auto_seen;
    diag_events[11]=(diag_phase != diag_phase_seen) &&
                     ((diag_phase == 4) || (diag_phase >= 6));
    diag_events[12]=scan_done && !diag_scan_seen && img_found_count == 0;
    diag_events[13]=diag_timeout || (diag_failure && retry_used && !diag_events[6]);
    diag_events[14]=diag_commit && recovery_active;
    diag_error=0;
    if(diag_failure) diag_error=bmp_error;
    if(diag_events[1] || diag_timeout) diag_error=3'd2;
end
always @(posedge clk or posedge rst) begin
    if(rst) begin
        diagnostics<=0;
        diag_init_seen<=0; diag_init_fail_seen<=0; diag_scan_seen<=0;
        diag_auto_seen<=0; diag_phase_seen<=0;
    end else begin
        diag_init_seen<=sd_init_done;
        diag_init_fail_seen<=sd_init_failed;
        diag_scan_seen<=scan_done;
        diag_auto_seen<=ctrl_auto_play_en;
        diag_phase_seen<=diag_phase;
        diagnostics<={diag_events,
            (load_busy || load_start_pulse || diag_commit) ? load_idx : img_idx,
            (diag_failure || load_start_pulse || diag_commit) ? load_sector : sd_sec_read_addr,
            diag_error, diag_phase, ctrl_auto_play_en};
    end
end

// A new request acknowledges only after the previous burst has ended and the
// write FIFO is cleared. Discard old completion toggles through that handshake.
always @(posedge clk or posedge rst) begin
    if (rst) write_epoch_active <= 1'b0;
    else if (recovering_reset || !sd_init_done || !load_busy || load_start_pulse || bmp_load_error)
        write_epoch_active <= 1'b0;
    else if (write_req && write_req_ack_sync)
        write_epoch_active <= 1'b1;
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        write_req_ack_pipe <= 2'b00;
        commit_ack_sync <= 2'b00;
        cancel_ack_sync <= 0;
    end else begin
        write_req_ack_pipe <= {write_req_ack_pipe[0], write_req_ack};
        commit_ack_sync <= {commit_ack_sync[0], display_commit_ack};
        cancel_ack_sync <= {cancel_ack_sync[0], write_cancel_ack};
    end
end

mode_key_control #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) u_mode_key_control (
    .clk(clk), .rst(rst), .enable(!recovery_active && sd_init_done && scan_kicked),
    .key1(key1), .key2(key2), .key4(key4), .mode(mode),
    .rescan_event(rescan_event), .next_event(media_next_request), .previous_event(media_previous_request),
    .auto_toggle_event(media_auto_toggle_request), .manual_activity(manual_activity)
);

media_display_control #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .DIAG_DISPLAY(DIAG_DISPLAY)) u_media_display_control (
 .clk(clk), .rst(rst), .combo_request(1'b0),
 .sd_init_done(sd_init_done), .scan_done(scan_done), .display_valid(display_valid),
 .load_busy(load_busy), .write_started_seen(write_started_seen),
 .source_done_now(source_done_now), .write_finish_now(write_finish_now),
 .img_idx(img_idx), .bmp_state_code(bmp_state_code), .state_code(normal_state_code),
 .auto_play_en(ctrl_auto_play_en), .auto_play_indicator(auto_play_indicator),
 .combo_event_count(combo_event_count), .combo_debug_active(combo_debug_active)
);

media_player_control #(
    .AUTO_PLAY_CYCLES(AUTO_PLAY_CYCLES)
) u_media_player_control (
    .clk(clk), .rst(rst), .enable(!recovery_active && sd_init_done && (scan_kicked || !bmp_ready)), .scan_done(scan_done),
    .display_valid(display_valid), .load_busy(load_busy),
    .first_image_committed(first_image_committed), .image_count(img_found_count),
    .current_image(img_idx), .mode(mode), .next_event(media_next_request),
    .previous_event(media_previous_request), .auto_toggle_event(media_auto_toggle_request),
    .request_accept(ctrl_request_accept),
    .manual_activity(manual_activity),
    .next_load_request(), .previous_load_request(), .auto_load_request(ctrl_auto_load_request),
    .auto_play_en(ctrl_auto_play_en), .next_pending(ctrl_next_pending),
    .previous_pending(ctrl_prev_pending), .auto_tick(ctrl_auto_tick),
    .load_request(ctrl_load_request), .target_image(ctrl_target_image)
);

function [31:0] sector_lut;
    input [1:0] idx;
    begin
        case (idx)
            2'd0: sector_lut = img_sector0;
            2'd1: sector_lut = img_sector1;
            2'd2: sector_lut = img_sector2;
            2'd3: sector_lut = img_sector3;
            default: sector_lut = img_sector0;
        endcase
    end
endfunction

// Decode the registered task index directly. Avoid a second wide register
// enabled by the full retry/selection decision chain.
assign load_sector = sector_lut(load_idx);

function [1:0] next_buf_lut;
    input [1:0] cur_disp_buf;
    input       valid_now;
    begin
        if (!valid_now)
            next_buf_lut = 2'd0;                 // 首图固定写 buffer0
        else if (cur_disp_buf == 2'd0)
            next_buf_lut = 2'd1;
        else
            next_buf_lut = 2'd0;
    end
endfunction

function [1:0] next_image;
    input [1:0] current;
    begin
        next_image = ({1'b0, current} + 3'd1 >= img_found_count) ? 2'd0 : current + 2'd1;
    end
endfunction

// 记录本次加载是否发出过写请求，区分读图头失败与真正的源端完成。
always @(posedge clk or posedge rst) begin
    if (rst)
        write_started_seen <= 1'b0;
    else if (!sd_init_done || !load_busy)
        write_started_seen <= 1'b0;
    else if (write_req)
        write_started_seen <= 1'b1;
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        recovery_phase <= 0; recovery_reset_count <= 0; write_cancel_req <= 0;
        timeout_stopped <= 0;
        sticky_error <= 0;
        retry_used <= 0;
        restart_pending <= 0;
        recovery_chain <= 0;
        first_load_failed <= 0;
        auto_blocked <= 0;
        candidates_tried <= 0;
        committed_image <= 0;
        committed_valid <= 0;
        wrfin_tgl_sync        <= 3'b000;
        scan_start_pulse      <= 1'b0;
        load_start_pulse      <= 1'b0;
        scan_kicked           <= 1'b0;
        first_image_committed <= 1'b0;

        img_found_count       <= 3'd0;
        img_idx               <= 2'd0;
        load_idx              <= 2'd0;
        pending_buf_idx       <= 2'd0;
        write_buf_idx         <= 2'd0;
        disp_buf_idx          <= 2'd0;
        img_sector0           <= 32'd0;
        img_sector1           <= 32'd0;
        img_sector2           <= 32'd0;
        img_sector3           <= 32'd0;

        load_busy             <= 1'b0;
        commit_pending        <= 1'b0;
        display_commit_request <= 1'b0;
        source_busy_seen      <= 1'b0;
        source_done_seen      <= 1'b0;
        write_finish_seen     <= 1'b0;
        display_valid         <= 1'b0;
    end else begin
        if (committed_valid && committed_ready) committed_valid <= 0;
        wrfin_tgl_sync   <= {wrfin_tgl_sync[1:0], write_finish_toggle};
        scan_start_pulse <= 1'b0;
        load_start_pulse <= 1'b0;

        if (rescan_event && !recovery_active) begin
            recovery_phase <= 1;
            write_cancel_req <= 1;
            load_start_pulse <= 0; scan_start_pulse <= 0;
        end else if (recovering_reset) begin
            // Never reset the display toggle locally; first adopt an issued commit.
            if (commit_pending && commit_ack_sync[1] == display_commit_request) begin
                commit_pending <= 0; display_valid <= 1; img_idx <= load_idx;
            end
            load_busy <= 0; source_busy_seen <= 0; source_done_seen <= 0;
            write_finish_seen <= 0; restart_pending <= 0;
            timeout_stopped <= 0; sticky_error <= 0;
            retry_used <= 0; recovery_chain <= 0; first_load_failed <= 0;
            auto_blocked <= 0; candidates_tried <= 0;
            scan_kicked <= 0; first_image_committed <= 0; img_found_count <= 0;
            img_sector0 <= 0; img_sector1 <= 0; img_sector2 <= 0; img_sector3 <= 0;
            if (recovery_phase == 1 && !commit_pending && cancel_ack_sync[1]) begin
                recovery_phase <= 2; recovery_reset_count <= 0;
            end else if (recovery_phase == 2) begin
                if (recovery_reset_count == 7) begin
                    recovery_phase <= 3; write_cancel_req <= 0;
                end else recovery_reset_count <= recovery_reset_count + 1'b1;
            end else if (recovery_phase == 3 && !cancel_ack_sync[1])
                recovery_phase <= 4;
        end else if (timeout_event || timeout_stopped) begin
            recovery_phase <= 0;
            timeout_stopped <= 1'b1;
            sticky_error <= 3'd2;
            load_busy <= 1'b0;
            restart_pending <= 1'b0;
            commit_pending <= 1'b0;
            source_done_seen <= 1'b0;
            write_finish_seen <= 1'b0;
            auto_blocked <= 1'b1;
        end else if (!sd_init_done) begin
            sticky_error <= sd_init_failed ? 3'd2 : 3'd0;
            if (sd_init_failed) recovery_phase <= 0;
            retry_used <= 0;
            restart_pending <= 0;
            recovery_chain <= 0;
            first_load_failed <= 0;
            auto_blocked <= 0;
            candidates_tried <= 0;
            scan_kicked           <= 1'b0;
            first_image_committed <= 1'b0;

            img_found_count       <= 3'd0;
            img_idx               <= 2'd0;
            load_idx              <= 2'd0;
            pending_buf_idx       <= 2'd0;
            write_buf_idx         <= 2'd0;
            img_sector0           <= 32'd0;
            img_sector1           <= 32'd0;
            img_sector2           <= 32'd0;
            img_sector3           <= 32'd0;

            load_busy             <= 1'b0;
            commit_pending        <= 1'b0;
            source_busy_seen      <= 1'b0;
            source_done_seen      <= 1'b0;
            write_finish_seen     <= 1'b0;

        end else begin
            // 扫描阶段缓存前 4 张图的起始 sector
            if (scan_done && img_found_count == 0) begin
                sticky_error <= 1; recovery_phase <= 0;
            end
            if (first_load_failed) recovery_phase <= 0;
            if (scan_found_valid) begin
                case (img_found_count)
                    3'd0: img_sector0 <= scan_found_sector;
                    3'd1: img_sector1 <= scan_found_sector;
                    3'd2: img_sector2 <= scan_found_sector;
                    3'd3: img_sector3 <= scan_found_sector;
                    default: ;
                endcase

                if (img_found_count < 3'd4)
                    img_found_count <= img_found_count + 3'd1;
            end

            // 两个完成事件独立锁存，避免跨时钟脉冲和源端完成的先后顺序造成丢失
            if (load_busy && !bmp_ready)
                source_busy_seen <= 1'b1;

            if (load_busy && bmp_load_done)
                source_done_seen <= 1'b1;

            if (load_busy && current_write_finish)
                write_finish_seen <= 1'b1;
            if (write_req_ack_sync)
                write_finish_seen <= 1'b0;

            // Keep the old buffer owned by the reader until its frame request
            // has adopted the new base address. Data stays stable until ack.
            if (load_busy && bmp_load_error) begin
                sticky_error <= bmp_error;
                source_busy_seen <= 1'b0;
                source_done_seen <= 1'b0;
                write_finish_seen <= 1'b0;
                if (!retry_used) begin
                    retry_used <= 1'b1;
                    restart_pending <= 1'b1;
                end else if (recovery_chain && (!first_image_committed || ctrl_auto_play_en) &&
                             candidates_tried < img_found_count) begin
                    load_idx <= next_image(load_idx);
                    candidates_tried <= candidates_tried + 3'd1;
                    retry_used <= 1'b0;
                    restart_pending <= 1'b1;
                end else begin
                    load_busy <= 1'b0;
                    restart_pending <= 1'b0;
                    if (!first_image_committed) first_load_failed <= 1'b1;
                    if (recovery_chain) auto_blocked <= 1'b1;
                end
            end else if (restart_pending && bmp_ready) begin
                load_start_pulse <= 1'b1;
                restart_pending <= 1'b0;
                source_busy_seen <= 1'b0;
                source_done_seen <= 1'b0;
                write_finish_seen <= 1'b0;
            end else if (commit_pending && commit_ack_sync[1] == display_commit_request &&
                (!committed_valid || committed_ready)) begin
                sticky_error <= 0;
                auto_blocked <= 0;
                recovery_phase <= 0;
                committed_image <= load_idx;
                committed_valid <= 1;
                commit_pending        <= 1'b0;
                load_busy             <= 1'b0;
                source_busy_seen      <= 1'b0;
                source_done_seen      <= 1'b0;
                write_finish_seen     <= 1'b0;
                img_idx               <= load_idx;
                display_valid         <= 1'b1;
                first_image_committed <= 1'b1;
            end else if (!commit_pending && load_busy && source_done_now && write_finish_now) begin
                commit_pending        <= 1'b1;
                display_commit_request <= ~display_commit_request;
                disp_buf_idx          <= pending_buf_idx;
            end

            // 上电后自动发起一次“扫描前 4 张 BMP”
            if (!scan_kicked && bmp_ready && sdram_ready) begin
                scan_start_pulse      <= 1'b1;
                scan_kicked           <= 1'b1;
                first_image_committed <= 1'b0;

                img_found_count       <= 3'd0;
                img_idx               <= 2'd0;
                load_idx              <= 2'd0;
                pending_buf_idx       <= 2'd0;
                write_buf_idx         <= 2'd0;

                load_busy             <= 1'b0;
                source_busy_seen      <= 1'b0;
                source_done_seen      <= 1'b0;
                write_finish_seen     <= 1'b0;
            end else begin
                // First image loading stays local.
                if (scan_done && !first_image_committed && !first_load_failed && bmp_ready && !load_busy && (img_found_count != 3'd0)) begin
                    retry_used <= 1'b0;
                    recovery_chain <= 1'b1;
                    candidates_tried <= 3'd1;
                    load_idx         <= 2'd0;
                    pending_buf_idx  <= next_buf_lut(disp_buf_idx, display_valid);
                    write_buf_idx    <= next_buf_lut(disp_buf_idx, display_valid);
                    load_start_pulse <= 1'b1;
                    load_busy        <= 1'b1;
                    source_busy_seen <= 1'b0;
                    source_done_seen <= 1'b0;
                    write_finish_seen <= 1'b0;

                end
                // Accept request and index together; write to the inactive buffer.
                else if (ctrl_request_accept) begin
                    retry_used <= 1'b0;
                    recovery_chain <= ctrl_auto_load_request;
                    candidates_tried <= 3'd1;
                    if (!ctrl_auto_load_request) auto_blocked <= 1'b0;
                    load_idx <= ctrl_target_image;
                    pending_buf_idx <= next_buf_lut(disp_buf_idx, display_valid);
                    write_buf_idx <= next_buf_lut(disp_buf_idx, display_valid);
                    load_start_pulse <= 1'b1;
                    load_busy <= 1'b1;
                    source_busy_seen <= 1'b0;
                    source_done_seen <= 1'b0;
                    write_finish_seen <= 1'b0;
                end
            end
        end
    end
end

bmp_read #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .TIMEOUT_MS(LOAD_TIMEOUT_MS)) bmp_read_m0(
    .clk                    (clk),
    .rst                    (parser_rst),
    .ready                  (bmp_ready),

    .scan_start             (scan_start_pulse),
    .scan_start_sector      (SCAN_START_SECTOR),
    .scan_max_sector        (SCAN_MAX_SECTOR),
    .scan_target_count      (SCAN_TARGET_COUNT),
    // S3 interface is verified independently; production keeps full-scan boot.
    .scan_pause_request     (1'b0),
    .scan_resume            (1'b0),
    .scan_paused            (),
    .scan_resume_sector     (),
    .scan_done              (scan_done),
    .scan_error             (bmp_scan_error),
    .scan_found_valid       (scan_found_valid),
    .scan_found_sector      (scan_found_sector),
    .scan_found_total       (scan_found_total),

    .load_start             (load_start_pulse),
    .load_sector            (load_sector),
    .load_done              (bmp_load_done),
    .load_error             (bmp_load_error),
    .bmp_error              (bmp_error),

    .sd_init_done           (sd_init_done),
    .state_code             (bmp_state_code),
    .bmp_width              (bmp_width),
    .bmp_height             (bmp_height),
    .write_req              (write_req),
    .write_req_ack          (write_req_ack_sync),
    .sd_sec_read            (sd_sec_read),
    .sd_sec_read_addr       (sd_sec_read_addr),
    .sd_sec_read_data       (sd_sec_read_data),
    .sd_sec_read_data_valid (sd_sec_read_data_valid),
    .sd_sec_read_failed(sd_sec_read_failed),
    .sd_sec_read_end        (sd_sec_read_end),
    .bmp_data_wr_en         (bmp_data_wr_en),
    .bmp_data               (bmp_data)
);

sd_card_top #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) sd_card_top_m0(
    .sd_debug(sd_debug),
    .sd_init_failed(sd_init_failed),
    .clk                    (clk),
    .rst                    (sd_local_rst),
    .SD_nCS                 (SD_nCS),
    .SD_DCLK                (SD_DCLK),
    .SD_MOSI                (SD_MOSI),
    .SD_MISO                (SD_MISO),
    .sd_init_done           (sd_init_done),
    .sd_sec_read            (sd_sec_read),
    .sd_sec_read_addr       (sd_sec_read_addr),
    .sd_sec_read_data       (sd_sec_read_data),
    .sd_sec_read_data_valid (sd_sec_read_data_valid),
    .sd_sec_read_failed(sd_sec_read_failed),
    .sd_sec_read_end        (sd_sec_read_end),
    .sd_sec_write           (1'b0),
    .sd_sec_write_addr      (32'd0),
    .sd_sec_write_data      (),
    .sd_sec_write_data_req  (),
    .sd_sec_write_end       ()
);

endmodule
