
module sd_card_bmp #(
    parameter integer CLK_FREQ_HZ       = 100_000_000,
    parameter [31:0]  SCAN_START_SECTOR = 32'd0,
    parameter [31:0]  SCAN_MAX_SECTOR   = 32'd131071,
    parameter [2:0]   SCAN_TARGET_COUNT = 3'd4,
    parameter integer LONG_PRESS_MS      = 1000,
    parameter integer AUTO_PLAY_MS       = 3000,
    parameter integer COMBO_WINDOW_MS    = 1,
    parameter integer DIAG_DISPLAY       = 0
)(
    input                       clk,
    input                       rst,
    input                       key_next,
    input                       key_auto,
    output reg [3:0]            state_code,
    output reg [7:0]            combo_event_count,
    output reg                  combo_debug_active,
    input  [15:0]               bmp_width,
    input  [15:0]               bmp_height,
    output reg                  display_valid,

    input                       write_finish_toggle,
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

wire key1_stable;
wire key2_stable;
reg  key1_stable_d;
reg  key2_stable_d;
wire key1_press_event;
wire key2_press_event;
wire key2_release_event;
wire key1_release_event;
wire key1_single_press_event;
wire key2_single_press_event;
wire key1_single_release_event;
wire key2_single_release_event;
wire combo_active;
wire combo_press_event;
wire combo_release_event;
wire key2_long_due;
reg  prev_event;
reg  short_event;
reg  key2_state;
reg  key2_long_fired;
localparam KEY2_IDLE = 1'b0, KEY2_HELD = 1'b1;

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
reg [31:0]       load_sector;
reg              scan_kicked;
reg              first_image_committed;
reg              auto_play_en;
reg [31:0]       auto_cnt;
reg [2:0]        img_found_count;
reg [1:0]        img_idx;              // 当前真正显示中的图片编号
reg [1:0]        load_idx;             // 当前正在写入的图片编号
reg [1:0]        pending_buf_idx;      // 当前正在写入的目标缓冲区
reg [31:0]       img_sector0;
reg [31:0]       img_sector1;
reg [31:0]       img_sector2;
reg [31:0]       img_sector3;
reg              next_req_pending;
reg              prev_req_pending;
reg              load_busy;
reg [31:0]       long_press_cnt;

// 一次加载必须先观察到 bmp_read 进入忙态，之后返回 ready 才算源端完成
reg              source_busy_seen;
reg              source_done_seen;
reg              write_finish_seen;
reg              write_started_seen;

// 同步 mem_clk 域的 write_finish_toggle
reg [2:0]        wrfin_tgl_sync;
wire             write_finish_pulse;

wire auto_tick;
wire [1:0] next_from_current;
wire [1:0] prev_from_current;
wire source_done_now;
wire write_finish_now;

localparam integer LONG_PRESS_CYCLES = (CLK_FREQ_HZ / 1000) * LONG_PRESS_MS;
localparam integer AUTO_PLAY_CYCLES  = (CLK_FREQ_HZ / 1000) * AUTO_PLAY_MS;
localparam integer COMBO_WINDOW_CYCLES = (CLK_FREQ_HZ / 1000) * COMBO_WINDOW_MS;
localparam integer COMBO_DEBUG_CYCLES = CLK_FREQ_HZ / 1;
reg [31:0] combo_debug_timer;

assign write_en   = bmp_data_wr_en;
assign write_data = {bmp_data[23:16], bmp_data[15:8], bmp_data[7:0], 8'b0};
assign auto_tick  = (auto_cnt == (AUTO_PLAY_CYCLES - 1));
assign next_from_current = next_index_limited(img_idx, img_found_count);
assign prev_from_current = prev_index_limited(img_idx, img_found_count);
assign write_finish_pulse = wrfin_tgl_sync[2] ^ wrfin_tgl_sync[1];
assign source_done_now = source_done_seen || (source_busy_seen && bmp_ready);
assign write_finish_now = write_finish_seen || write_finish_pulse;
assign key1_press_event   = key1_stable_d && !key1_stable;
assign key2_press_event   = key2_stable_d && !key2_stable;
assign key1_release_event = !key1_stable_d && key1_stable;
assign key2_release_event = !key2_stable_d && key2_stable;
assign key2_long_due = (key2_state == KEY2_HELD) && !key2_stable &&
                       !key2_long_fired && (long_press_cnt >= LONG_PRESS_CYCLES - 1);
assign write_req_ack_sync = write_req_ack_pipe[1];

always @(posedge clk or posedge rst) begin
    if (rst)
        write_req_ack_pipe <= 2'b00;
    else
        write_req_ack_pipe <= {write_req_ack_pipe[0], write_req_ack};
end

key_press_debounce #(
    .CLK_FREQ_HZ (CLK_FREQ_HZ),
    .DEBOUNCE_MS (20)
) u_key_next (
    .clk        (clk),
    .rst        (rst),
    .button_in        (key_next),
    .press_pulse      (),
    .button_stable_out(key1_stable)
);

dual_key_event_router #(
    .COMBO_WINDOW_CYCLES(COMBO_WINDOW_CYCLES)
) u_dual_key_event_router (
    .clk                     (clk),
    .rst                     (rst),
    .key1_stable             (key1_stable),
    .key2_stable             (key2_stable),
    .key1_press_event        (key1_press_event),
    .key2_press_event        (key2_press_event),
    .key1_release_event      (key1_release_event),
    .key2_release_event      (key2_release_event),
    .combo_active            (combo_active),
    .combo_press_event       (combo_press_event),
    .combo_release_event     (combo_release_event),
    .key1_single_press_event (key1_single_press_event),
    .key2_single_press_event (key2_single_press_event),
    .key1_single_release_event(key1_single_release_event),
    .key2_single_release_event(key2_single_release_event)
);

key_press_debounce #(
    .CLK_FREQ_HZ (CLK_FREQ_HZ),
    .DEBOUNCE_MS (20)
) u_key_auto (
    .clk        (clk),
    .rst        (rst),
    .button_in        (key_auto),
    .press_pulse      (),
    .button_stable_out(key2_stable)
);

function [1:0] next_index_limited;
    input [1:0] cur;
    input [2:0] count;
    begin
        case (count)
            3'd0: next_index_limited = 2'd0;
            3'd1: next_index_limited = 2'd0;
            3'd2: next_index_limited = (cur == 2'd1) ? 2'd0 : (cur + 2'd1);
            3'd3: next_index_limited = (cur == 2'd2) ? 2'd0 : (cur + 2'd1);
            default: next_index_limited = (cur == 2'd3) ? 2'd0 : (cur + 2'd1);
        endcase
    end
endfunction

function [1:0] prev_index_limited;
    input [1:0] cur;
    input [2:0] count;
    begin
        case (count)
            3'd0: prev_index_limited = 2'd0;
            3'd1: prev_index_limited = 2'd0;
            3'd2: prev_index_limited = (cur == 2'd0) ? 2'd1 : (cur - 2'd1);
            3'd3: prev_index_limited = (cur == 2'd0) ? 2'd2 : (cur - 2'd1);
            default: prev_index_limited = (cur == 2'd0) ? 2'd3 : (cur - 2'd1);
        endcase
    end
endfunction

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
        wrfin_tgl_sync        <= 3'b000;
        scan_start_pulse      <= 1'b0;
        load_start_pulse      <= 1'b0;
        load_sector           <= 32'd0;
        scan_kicked           <= 1'b0;
        first_image_committed <= 1'b0;
        auto_play_en          <= 1'b0;
        auto_cnt              <= 32'd0;
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
        next_req_pending      <= 1'b0;
        prev_req_pending      <= 1'b0;
        load_busy             <= 1'b0;
        long_press_cnt        <= 32'd0;
        key1_stable_d         <= 1'b1;
        key2_stable_d         <= 1'b1;
        prev_event            <= 1'b0;
        short_event           <= 1'b0;
        key2_state            <= 1'b0;
        key2_long_fired       <= 1'b0;
        source_busy_seen      <= 1'b0;
        source_done_seen      <= 1'b0;
        write_finish_seen     <= 1'b0;
        display_valid         <= 1'b0;
        state_code            <= 4'd0;
        combo_event_count     <= 8'd0;
        combo_debug_active    <= 1'b0;
        combo_debug_timer     <= 32'd0;
    end else begin
        wrfin_tgl_sync   <= {wrfin_tgl_sync[1:0], write_finish_toggle};
        scan_start_pulse <= 1'b0;
        load_start_pulse <= 1'b0;
        key1_stable_d <= key1_stable;
        key2_stable_d <= key2_stable;
        prev_event    <= 1'b0;
        short_event   <= 1'b0;
        if (combo_press_event && combo_event_count != 8'hff)
            combo_event_count <= combo_event_count + 8'd1;
        if (combo_press_event) begin
            combo_debug_active <= 1'b1;
            combo_debug_timer  <= COMBO_DEBUG_CYCLES - 1;
        end else if (combo_debug_active) begin
            if (combo_debug_timer == 0)
                combo_debug_active <= 1'b0;
            else
                combo_debug_timer <= combo_debug_timer - 1'b1;
        end
        if (DIAG_DISPLAY != 0) begin
            if (!sd_init_done) state_code <= 4'd0;
            else if (!scan_done) state_code <= 4'd1;
            else if (!display_valid && !load_busy) state_code <= 4'd3;
            else if (load_busy && !write_started_seen) state_code <= 4'd4;
            else if (load_busy && !source_done_now) state_code <= 4'd6;
            else if (load_busy && !write_finish_now) state_code <= 4'd7;
            else if (load_busy) state_code <= 4'd5;
            else state_code <= 4'd8;
        end else begin
            state_code <= display_valid ? ({2'b00, img_idx} + 4'd1) : bmp_state_code;
        end

        if (!sd_init_done) begin
            scan_kicked           <= 1'b0;
            first_image_committed <= 1'b0;
            auto_play_en          <= 1'b0;
            auto_cnt              <= 32'd0;
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
            next_req_pending      <= 1'b0;
            prev_req_pending      <= 1'b0;
            load_busy             <= 1'b0;
            long_press_cnt        <= 32'd0;
            key1_stable_d         <= 1'b1;
            key2_stable_d         <= 1'b1;
            prev_event            <= 1'b0;
            short_event           <= 1'b0;
            key2_state            <= 1'b0;
            key2_long_fired       <= 1'b0;
            source_busy_seen      <= 1'b0;
            source_done_seen      <= 1'b0;
            write_finish_seen     <= 1'b0;
            display_valid         <= 1'b0;
        end else begin
            // 统一按键事件边界：KEY1 按下产生 next，KEY2 在释放时区分短按，跨阈值时产生 prev。
            if (key2_state == KEY2_IDLE) begin
                if (key2_single_press_event) begin
                    key2_state      <= KEY2_HELD;
                    key2_long_fired <= 1'b0;
                    long_press_cnt  <= 32'd0;
                end
            end else if (!key2_stable) begin
                if (long_press_cnt < LONG_PRESS_CYCLES)
                    long_press_cnt <= long_press_cnt + 32'd1;
                if (key2_long_due) begin
                    prev_event      <= 1'b1;
                    key2_long_fired <= 1'b1;
                end
            end else if (key2_single_release_event) begin
                if (!key2_long_fired)
                    short_event <= 1'b1;
                key2_state      <= KEY2_IDLE;
                key2_long_fired <= 1'b0;
                long_press_cnt  <= 32'd0;
            end

            // 扫描阶段缓存前 4 张图的起始 sector
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

            if (load_busy && source_busy_seen && bmp_ready)
                source_done_seen <= 1'b1;

            if (load_busy && write_finish_pulse)
                write_finish_seen <= 1'b1;

            // 源端返回空闲且 SDRAM 整帧写完后，才原子提交新图
            if (load_busy && source_done_now && !write_started_seen && !write_req) begin
                // bmp_read 忙过后返回空闲，但未发写请求：图头被拒绝。
                // 释放加载任务，保持已显示图片和挂起请求；首图失败会再次尝试加载。
                load_busy             <= 1'b0;
                source_busy_seen      <= 1'b0;
                source_done_seen      <= 1'b0;
                write_finish_seen     <= 1'b0;
            end else if (load_busy && source_done_now && write_finish_now) begin
                load_busy             <= 1'b0;
                source_busy_seen      <= 1'b0;
                source_done_seen      <= 1'b0;
                write_finish_seen     <= 1'b0;
                disp_buf_idx          <= pending_buf_idx;
                img_idx               <= load_idx;
                display_valid         <= 1'b1;
                first_image_committed <= 1'b1;
            end

            // 上电后自动发起一次“扫描前 4 张 BMP”
            if (!scan_kicked && bmp_ready) begin
                scan_start_pulse      <= 1'b1;
                scan_kicked           <= 1'b1;
                first_image_committed <= 1'b0;
                auto_play_en          <= 1'b0;
                auto_cnt              <= 32'd0;
                img_found_count       <= 3'd0;
                img_idx               <= 2'd0;
                load_idx              <= 2'd0;
                pending_buf_idx       <= 2'd0;
                write_buf_idx         <= 2'd0;
                disp_buf_idx          <= 2'd0;
                next_req_pending      <= 1'b0;
                prev_req_pending      <= 1'b0;
                display_valid         <= 1'b0;
                load_busy             <= 1'b0;
                long_press_cnt        <= 32'd0;
                key1_stable_d         <= 1'b1;
                key2_stable_d         <= 1'b1;
                prev_event            <= 1'b0;
                short_event           <= 1'b0;
                key2_state            <= 1'b0;
                key2_long_fired       <= 1'b0;
                source_busy_seen      <= 1'b0;
                source_done_seen      <= 1'b0;
                write_finish_seen     <= 1'b0;
            end else begin
                // 忙的时候也只记 1 次“下一张”请求，不会累积成连跳两张
                if (short_event && scan_done && (img_found_count > 3'd1)) begin
                    auto_play_en <= ~auto_play_en;
                    auto_cnt     <= 32'd0;
                end

                // 自动播放计数：只有当前没有写图任务时才计时
                if (scan_done && auto_play_en && display_valid && !load_busy && first_image_committed &&
                    (img_found_count > 3'd1) && !short_event &&
                    !key1_single_press_event && !prev_event &&
                    !key2_single_press_event && !key2_single_release_event && !key2_long_due &&
                    !next_req_pending && !prev_req_pending) begin
                    if (auto_tick)
                        auto_cnt <= 32'd0;
                    else
                        auto_cnt <= auto_cnt + 32'd1;
                end else begin
                    auto_cnt <= 32'd0;
                end

                // 首图自动加载到 buffer0
                if (scan_done && !first_image_committed && bmp_ready && !load_busy && (img_found_count != 3'd0)) begin
                    load_idx         <= 2'd0;
                    load_sector      <= img_sector0;
                    pending_buf_idx  <= 2'd0;
                    write_buf_idx    <= 2'd0;
                    load_start_pulse <= 1'b1;
                    load_busy        <= 1'b1;
                    source_busy_seen <= 1'b0;
                    source_done_seen <= 1'b0;
                    write_finish_seen <= 1'b0;
                    auto_cnt         <= 32'd0;
                end
                // 手动下一张优先：写到“非当前显示”的另一块 buffer
                else if (scan_done && bmp_ready && display_valid && !load_busy &&
                         next_req_pending && (img_found_count != 3'd0)) begin
                    load_idx         <= next_from_current;
                    load_sector      <= sector_lut(next_from_current);
                    pending_buf_idx  <= next_buf_lut(disp_buf_idx, display_valid);
                    write_buf_idx    <= next_buf_lut(disp_buf_idx, display_valid);
                    load_start_pulse <= 1'b1;
                    load_busy        <= 1'b1;
                    source_busy_seen <= 1'b0;
                    source_done_seen <= 1'b0;
                    write_finish_seen <= 1'b0;
                    next_req_pending <= 1'b0;
                    auto_cnt         <= 32'd0;
                end
                // 手动上一张次优先：同样写到“非当前显示”的另一块 buffer
                else if (scan_done && bmp_ready && display_valid && !load_busy &&
                         prev_req_pending && (img_found_count != 3'd0)) begin
                    load_idx         <= prev_from_current;
                    load_sector      <= sector_lut(prev_from_current);
                    pending_buf_idx  <= next_buf_lut(disp_buf_idx, display_valid);
                    write_buf_idx    <= next_buf_lut(disp_buf_idx, display_valid);
                    load_start_pulse <= 1'b1;
                    load_busy        <= 1'b1;
                    source_busy_seen <= 1'b0;
                    source_done_seen <= 1'b0;
                    write_finish_seen <= 1'b0;
                    prev_req_pending <= 1'b0;
                    auto_cnt         <= 32'd0;
                end
                // 自动播放下一张：同样写到“非当前显示”的另一块 buffer
                else if (scan_done && bmp_ready && display_valid && !load_busy && auto_play_en && auto_tick &&
                         (img_found_count > 3'd1) && !short_event &&
                         !key1_single_press_event && !prev_event &&
                         !key2_single_press_event && !key2_single_release_event && !key2_long_due &&
                         !next_req_pending && !prev_req_pending) begin
                    load_idx         <= next_from_current;
                    load_sector      <= sector_lut(next_from_current);
                    pending_buf_idx  <= next_buf_lut(disp_buf_idx, display_valid);
                    write_buf_idx    <= next_buf_lut(disp_buf_idx, display_valid);
                    load_start_pulse <= 1'b1;
                    load_busy        <= 1'b1;
                    source_busy_seen <= 1'b0;
                    source_done_seen <= 1'b0;
                    write_finish_seen <= 1'b0;
                    auto_cnt         <= 32'd0;
                end
                // Capture after consumption: a new event on the consumption cycle survives.
                if (scan_done && (img_found_count != 3'd0)) begin
                    if (key1_single_press_event) next_req_pending <= 1'b1;
                    if (prev_event) prev_req_pending <= 1'b1;
                end
            end
        end
    end
end

bmp_read bmp_read_m0(
    .clk                    (clk),
    .rst                    (rst),
    .ready                  (bmp_ready),

    .scan_start             (scan_start_pulse),
    .scan_start_sector      (SCAN_START_SECTOR),
    .scan_max_sector        (SCAN_MAX_SECTOR),
    .scan_target_count      (SCAN_TARGET_COUNT),
    .scan_done              (scan_done),
    .scan_found_valid       (scan_found_valid),
    .scan_found_sector      (scan_found_sector),
    .scan_found_total       (scan_found_total),

    .load_start             (load_start_pulse),
    .load_sector            (load_sector),

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
    .sd_sec_read_end        (sd_sec_read_end),
    .bmp_data_wr_en         (bmp_data_wr_en),
    .bmp_data               (bmp_data)
);

sd_card_top sd_card_top_m0(
    .clk                    (clk),
    .rst                    (rst),
    .SD_nCS                 (SD_nCS),
    .SD_DCLK                (SD_DCLK),
    .SD_MOSI                (SD_MOSI),
    .SD_MISO                (SD_MISO),
    .sd_init_done           (sd_init_done),
    .sd_sec_read            (sd_sec_read),
    .sd_sec_read_addr       (sd_sec_read_addr),
    .sd_sec_read_data       (sd_sec_read_data),
    .sd_sec_read_data_valid (sd_sec_read_data_valid),
    .sd_sec_read_end        (sd_sec_read_end),
    .sd_sec_write           (1'b0),
    .sd_sec_write_addr      (32'd0),
    .sd_sec_write_data      (),
    .sd_sec_write_data_req  (),
    .sd_sec_write_end       ()
);

endmodule

module key_press_debounce #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer DEBOUNCE_MS = 20
)(
    input  wire clk,
    input  wire rst,
    input  wire button_in,    // 默认：松开=1，按下=0
    output reg  press_pulse,
    output wire button_stable_out
);

localparam integer DEBOUNCE_CYCLES = (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;

reg button_sync0;
reg button_sync1;
reg button_stable;
reg [31:0] cnt;

assign button_stable_out = button_stable;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        button_sync0  <= 1'b1;
        button_sync1  <= 1'b1;
        button_stable <= 1'b1;
        cnt           <= 32'd0;
        press_pulse   <= 1'b0;
    end else begin
        button_sync0 <= button_in;
        button_sync1 <= button_sync0;
        press_pulse  <= 1'b0;

        if (button_sync1 == button_stable) begin
            cnt <= 32'd0;
        end else begin
            if (cnt >= DEBOUNCE_CYCLES - 1) begin
                if (button_stable && !button_sync1)
                    press_pulse <= 1'b1;
                button_stable <= button_sync1;
                cnt           <= 32'd0;
            end else begin
                cnt <= cnt + 32'd1;
            end
        end
    end
end

endmodule
