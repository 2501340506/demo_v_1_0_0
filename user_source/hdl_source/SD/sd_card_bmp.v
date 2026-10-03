
module sd_card_bmp #(
    parameter integer CLK_FREQ_HZ       = 100_000_000,
    parameter [31:0]  SCAN_START_SECTOR = 32'd0,
    parameter [31:0]  SCAN_MAX_SECTOR   = 32'd131071,
    parameter [2:0]   SCAN_TARGET_COUNT = 3'd4,
    parameter integer LONG_PRESS_MS      = 1000,
    parameter integer AUTO_PLAY_MS       = 3000,
    parameter integer COMBO_WINDOW_MS    = 100,
    parameter integer DIAG_DISPLAY       = 0
)(
    input                       clk,
    input                       rst,
    input                       key_next,
    input                       key_auto,
    output     [3:0]            state_code,
    output     [7:0]            combo_event_count,
    output                      combo_debug_active,
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

wire key1_single_press_event, prev_event, short_event, combo_press_event;
wire manual_activity;
wire media_next_request, media_previous_request, media_auto_toggle_request, media_combo_request;
wire ctrl_auto_play_en, ctrl_next_pending, ctrl_prev_pending, ctrl_auto_tick, ctrl_load_request;
wire [1:0] ctrl_target_image;
wire ctrl_request_accept;

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
reg [2:0]        img_found_count;
reg [1:0]        img_idx;              // 当前真正显示中的图片编号
reg [1:0]        load_idx;             // 当前正在写入的图片编号
reg [1:0]        pending_buf_idx;      // 当前正在写入的目标缓冲区
reg [31:0]       img_sector0;
reg [31:0]       img_sector1;
reg [31:0]       img_sector2;
reg [31:0]       img_sector3;
reg              load_busy;

// 一次加载必须先观察到 bmp_read 进入忙态，之后返回 ready 才算源端完成
reg              source_busy_seen;
reg              source_done_seen;
reg              write_finish_seen;
reg              write_started_seen;

// 同步 mem_clk 域的 write_finish_toggle
reg [2:0]        wrfin_tgl_sync;
wire             write_finish_pulse;

wire source_done_now;
wire write_finish_now;

localparam integer AUTO_PLAY_CYCLES  = (CLK_FREQ_HZ / 1000) * AUTO_PLAY_MS;

assign ctrl_request_accept = ctrl_load_request && bmp_ready;
assign write_en   = bmp_data_wr_en;
assign write_data = {bmp_data[23:16], bmp_data[15:8], bmp_data[7:0], 8'b0};
assign write_finish_pulse = wrfin_tgl_sync[2] ^ wrfin_tgl_sync[1];
assign source_done_now = source_done_seen || (source_busy_seen && bmp_ready);
assign write_finish_now = write_finish_seen || write_finish_pulse;
assign write_req_ack_sync = write_req_ack_pipe[1];

always @(posedge clk or posedge rst) begin
    if (rst)
        write_req_ack_pipe <= 2'b00;
    else
        write_req_ack_pipe <= {write_req_ack_pipe[0], write_req_ack};
end

key_gesture_control #(
    .CLK_FREQ_HZ(CLK_FREQ_HZ), .LONG_PRESS_MS(LONG_PRESS_MS),
    .COMBO_WINDOW_MS(COMBO_WINDOW_MS)
) u_key_gesture_control (
    .clk(clk), .rst(rst), .enable(sd_init_done && scan_kicked),
    .key_next(key_next), .key_auto(key_auto),
    .next_event(key1_single_press_event), .previous_event(prev_event),
    .auto_toggle_event(short_event), .combo_event(combo_press_event),
    .manual_activity(manual_activity)
);

media_policy u_media_policy (
    .clk(clk), .rst(rst),
    .next_event(key1_single_press_event), .previous_event(prev_event),
    .auto_toggle_event(short_event), .combo_event(combo_press_event),
    .next_request(media_next_request), .previous_request(media_previous_request),
    .auto_toggle_request(media_auto_toggle_request), .combo_request(media_combo_request)
);

media_display_control #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .DIAG_DISPLAY(DIAG_DISPLAY)) u_media_display_control (
 .clk(clk), .rst(rst), .combo_request(media_combo_request),
 .sd_init_done(sd_init_done), .scan_done(scan_done), .display_valid(display_valid),
 .load_busy(load_busy), .write_started_seen(write_started_seen),
 .source_done_now(source_done_now), .write_finish_now(write_finish_now),
 .img_idx(img_idx), .bmp_state_code(bmp_state_code), .state_code(state_code),
 .combo_event_count(combo_event_count), .combo_debug_active(combo_debug_active)
);

media_player_control #(
    .AUTO_PLAY_CYCLES(AUTO_PLAY_CYCLES)
) u_media_player_control (
    .clk(clk), .rst(rst), .enable(sd_init_done && (scan_kicked || !bmp_ready)), .scan_done(scan_done),
    .display_valid(display_valid), .load_busy(load_busy),
    .first_image_committed(first_image_committed), .image_count(img_found_count),
    .current_image(img_idx), .next_event(media_next_request),
    .previous_event(media_previous_request), .auto_toggle_event(media_auto_toggle_request),
    .request_accept(ctrl_request_accept),
    .manual_activity(manual_activity),
    .next_load_request(), .previous_load_request(), .auto_load_request(),
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
        source_busy_seen      <= 1'b0;
        source_done_seen      <= 1'b0;
        write_finish_seen     <= 1'b0;
        display_valid         <= 1'b0;
    end else begin
        wrfin_tgl_sync   <= {wrfin_tgl_sync[1:0], write_finish_toggle};
        scan_start_pulse <= 1'b0;
        load_start_pulse <= 1'b0;

        if (!sd_init_done) begin
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
            source_busy_seen      <= 1'b0;
            source_done_seen      <= 1'b0;
            write_finish_seen     <= 1'b0;
            display_valid         <= 1'b0;
        end else begin
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

                img_found_count       <= 3'd0;
                img_idx               <= 2'd0;
                load_idx              <= 2'd0;
                pending_buf_idx       <= 2'd0;
                write_buf_idx         <= 2'd0;
                disp_buf_idx          <= 2'd0;

                display_valid         <= 1'b0;
                load_busy             <= 1'b0;
                source_busy_seen      <= 1'b0;
                source_done_seen      <= 1'b0;
                write_finish_seen     <= 1'b0;
            end else begin
                // First image loading stays local.
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

                end
                // Accept request and index together; write to the inactive buffer.
                else if (ctrl_request_accept) begin
                    load_idx <= ctrl_target_image;
                    load_sector <= sector_lut(ctrl_target_image);
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
