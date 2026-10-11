
module top(
    input                       clk,
    input                       rst_n,
    input                       key1,           // 图片模式：上一张
    input                       key2,           // 图片模式：下一张
    input                       key4,           // MAN/AUTO切换
    input                       sw1,            // C8，拨上=1
    input                       sw2,            // C7，拨上=1

    output [5:0]                seg_sel,
    output [7:0]                seg_data,

    // HDMI TMDS
    output                      HDMI_CLK_P,
    output                      HDMI_D2_P,
    output                      HDMI_D1_P,
    output                      HDMI_D0_P,

    // HDMI DDC
    inout                       HDMI_DDC_SCL,
    inout                       HDMI_DDC_SDA,

    // TF card SPI
    output                      sd_ncs,
    output                      sd_dclk,
    output                      sd_mosi,
    input                       sd_miso,
    input                       uart_rx, // F12, asynchronous 115200 8N1
    output                      uart_tx
);

parameter integer OSD_ENABLE = 1;
parameter integer SCROLL_ENABLE = 1;
parameter integer BAND_ENABLE = 1;
parameter integer TIMESTAMP_ENABLE = 1;
parameter MEM_DATA_BITS = 32;
parameter integer UART_CLK_FREQ_HZ = 100_000_000;
parameter integer UART_BAUD_RATE = 115200;
parameter ADDR_BITS     = 21;
parameter BUSRT_BITS    = 10;
parameter [ADDR_BITS-1:0] FRAME_PIXELS = 307200;   // 640*480
parameter [ADDR_BITS-1:0] BUF0_ADDR = 0;
parameter [ADDR_BITS-1:0] BUF1_ADDR = FRAME_PIXELS;
parameter [ADDR_BITS-1:0] BUF2_ADDR = FRAME_PIXELS * 2;
parameter [ADDR_BITS-1:0] BUF3_ADDR = FRAME_PIXELS * 3;

wire Sdr_init_done;
wire Sdr_init_ref_vld;
wire Sdr_busy;

wire sd_card_clk;
wire ext_mem_clk;
wire ext_mem_clk_sft;
wire video_clk;
wire hdmi_5x_clk;

wire hs;
wire vs;
wire de;
wire [9:0] video_x; // Aligned with hs/vs/de/vout_data for the HDMI core.

wire [23:0] vout_data_raw;
wire [23:0] vout_data;
// S1 transition pixel stage. Control remains bypassed until the display
// commit handshake is connected in the next integration step.
wire [23:0] transition_rgb;
wire [23:0] osd_rgb;
wire [23:0] scroll_rgb;
wire [23:0] timestamp_rgb;
wire [23:0] band_rgb;
wire status_glyph_active, scroll_glyph_active;
wire timestamp_glyph_active;
wire [7:0] osd_error_src, osd_error_pixel;
wire osd_auto_pixel;
wire        display_valid;
wire [1:0] committed_image, audio_image;
wire committed_valid, committed_ready, audio_update, audio_enable;

wire [3:0]  state_code;
wire [63:0] sd_debug;
reg [63:0] sd_debug_panel0, sd_debug_panel1;
reg [63:0] sd_debug_half;
wire [7:0]  combo_event_count;
wire        combo_debug_active;
wire        auto_play_indicator;
wire [57:0] uart_diagnostics;
reg [1:0]   auto_indicator_sync;

wire        video_read_req;
wire        video_read_req_ack;
wire        video_read_en;
wire [31:0] video_read_data;

wire        sd_card_write_en;
wire [31:0] sd_card_write_data;
wire write_cancel_req, write_cancel_ack;
wire        sd_card_write_req;
wire        sd_card_write_req_ack;
wire        frame_write_finish;
wire source_frame_done, source_frame_error;
wire frame_error_toggle;
wire [2:0] frame_memory_error, frame_reader_error;
wire frame_underflow;
wire frame_wr_busy, frame_rd_busy;
reg         frame_write_toggle_mem;

wire [1:0]  write_buf_idx;
wire [1:0]  disp_buf_idx;
wire        display_commit_request, display_commit_ack;
wire        transition_active_sd;
wire [4:0]  transition_level_sd;
reg  [4:0]  transition_level_v1, transition_level_v2;
reg         transition_active_v1, transition_active_v2;
reg         transition_frame_toggle;
wire App_rd_en;
wire [ADDR_BITS-1:0] App_rd_addr;
wire Sdr_rd_en;
wire [MEM_DATA_BITS-1:0] Sdr_rd_dout;
wire App_wr_en;
wire [ADDR_BITS-1:0] App_wr_addr;
wire [MEM_DATA_BITS-1:0] App_wr_din;
wire [3:0] App_wr_dm;

wire hs_0;
wire vs_0;
wire de_0;
wire [9:0] video_x_0;

wire [9:0]  tmds_ch0_data;
wire [9:0]  tmds_ch1_data;
wire [9:0]  tmds_ch2_data;
wire [9:0]  tmds_clk_data;

// Both clock trees must lock. Each consumer releases reset on its own clock.
wire sys_pll_lock;
wire reset_request = ~rst_n | ~sys_pll_lock;
wire rst_panel, rst_sd, rst_mem, rst_video, rst_serial;
// Half-cycle staging gives the observed bus margin at the 50 MHz capture edge.
// This path remains timed; no diagnostic CDC timing exception is introduced.
always @(negedge sd_card_clk or posedge rst_sd) begin
    if(rst_sd) sd_debug_half <= 0;
    else sd_debug_half <= sd_debug;
end
// Debug value settles before F; the panel consumes the retained result.
always @(posedge clk or posedge rst_panel) begin
    if(rst_panel) begin sd_debug_panel0 <= 0; sd_debug_panel1 <= 0; end
    else begin sd_debug_panel0 <= sd_debug_half; sd_debug_panel1 <= sd_debug_panel0; end
end
reset_sync u_reset_panel (.clk(clk), .async_rst(reset_request), .rst(rst_panel));
reset_sync u_reset_sd (.clk(sd_card_clk), .async_rst(reset_request), .rst(rst_sd));
reset_sync u_reset_mem (.clk(ext_mem_clk), .async_rst(reset_request), .rst(rst_mem));
reset_sync u_reset_video (.clk(video_clk), .async_rst(reset_request), .rst(rst_video));
reset_sync u_reset_serial (.clk(hdmi_5x_clk), .async_rst(reset_request), .rst(rst_serial));

// UART command state lives in the SD/control domain; renderer sees frame snapshots.
wire [7:0] sub_rx_data, sub_reply_data;
wire sub_rx_valid, sub_rx_error, sub_reply_valid, sub_reply_last, sub_reply_ready;
wire [119:0] sub_text_src, sub_text_pixel;
wire [3:0] sub_length_src, sub_length_pixel;
wire sub_enable_src, sub_enable_pixel, sub_text_changed, sub_frame_start;
uart_rx_byte #(.CLKS_PER_BIT((UART_CLK_FREQ_HZ+UART_BAUD_RATE/2)/UART_BAUD_RATE)) u_uart_rx (
 .clk(sd_card_clk),.rst_n(~rst_sd),.rx(uart_rx),.data(sub_rx_data),
 .valid(sub_rx_valid),.framing_error(sub_rx_error));
subtitle_uart_controller u_subtitle_control(
 .clk(sd_card_clk),.rst(rst_sd),.rx_data(sub_rx_data),.rx_valid(sub_rx_valid),
 .rx_framing_error(sub_rx_error),.cfg_text(sub_text_src),.cfg_length(sub_length_src),
 .cfg_enable(sub_enable_src),.cfg_update_valid(),.reply_valid(sub_reply_valid),
 .reply_data(sub_reply_data),.reply_last(sub_reply_last),.reply_ready(sub_reply_ready));
osd_pixel_position u_subtitle_position(.clk(video_clk),.rst(rst_video),.vs(vs),.de(de),
 .line_y(),.frame_start(sub_frame_start),.first_active());
always @(posedge video_clk or posedge rst_video) begin
    if (rst_video) transition_frame_toggle <= 1'b0;
    else if (sub_frame_start) transition_frame_toggle <= ~transition_frame_toggle;
end
always @(posedge video_clk or posedge rst_video) begin
    if (rst_video) begin
        transition_level_v1 <= 5'd16; transition_level_v2 <= 5'd16;
        transition_active_v1 <= 1'b0; transition_active_v2 <= 1'b0;
    end else begin
        transition_level_v1 <= transition_level_sd;
        transition_level_v2 <= transition_level_v1;
        transition_active_v1 <= transition_active_sd;
        transition_active_v2 <= transition_active_v1;
    end
end
subtitle_frame_commit u_subtitle_commit(
 .src_clk(sd_card_clk),.src_rst(rst_sd),.src_text(sub_text_src),
 .src_length(sub_length_src),.src_enable(sub_enable_src),
 .dst_clk(video_clk),.dst_rst(rst_video),.frame_start(sub_frame_start),
 .dst_text(sub_text_pixel),.dst_length(sub_length_pixel),.dst_enable(sub_enable_pixel),
 .text_changed(sub_text_changed));

uart_event_logger #(.CLK_FREQ_HZ(UART_CLK_FREQ_HZ), .BAUD_RATE(UART_BAUD_RATE), .REPLY_ENABLE(1)) u_uart_logger (
    .clk(sd_card_clk), .rst(rst_sd), .events(uart_diagnostics[57:42]),
    .image_index(uart_diagnostics[41:40]), .sector(uart_diagnostics[39:8]),
    .error_code(uart_diagnostics[7:5]), .phase(uart_diagnostics[4:1]),
    .auto_enabled(uart_diagnostics[0]), .sd_debug(sd_debug), .uart_tx(uart_tx),
    .reply_valid(sub_reply_valid), .reply_data(sub_reply_data),
    .reply_last(sub_reply_last), .reply_ready(sub_reply_ready)
);

// SDRAM and TF initialization run independently. Only the first scan waits
// for memory readiness; keep the SD controller out of this dependency loop.
(* ASYNC_REG = "TRUE" *) reg [1:0] sdram_ready_sync;
always @(posedge sd_card_clk or posedge rst_sd) begin
    if (rst_sd) sdram_ready_sync <= 2'b00;
    else sdram_ready_sync <= {sdram_ready_sync[0], Sdr_init_done};
end

// Mode and key routing share the SD control clock. Synchronize mode for panel display.
wire [1:0] switch_mode;
reg [1:0] mode_panel_sync0, mode_panel_sync1;
switch_mode_control #(.CLK_FREQ_HZ(100_000_000)) u_switch_mode_control (
    .clk(sd_card_clk), .rst(rst_sd), .switches({sw2, sw1}), .mode(switch_mode)
);
always @(posedge clk or posedge rst_panel) begin
    if (rst_panel) begin
        mode_panel_sync0 <= 0;
        mode_panel_sync1 <= 0;
    end else begin
        mode_panel_sync0 <= switch_mode;
        mode_panel_sync1 <= mode_panel_sync0;
    end
end

// The mode indicator crosses from SD control to the 50 MHz scan clock.
always @(posedge clk or posedge rst_panel) begin
    if (rst_panel)
        auto_indicator_sync <= 2'b00;
    else
        auto_indicator_sync <= {auto_indicator_sync[0], auto_play_indicator};
end

// 保持你原来的 TF / SDRAM / video 时钟
sys_pll_s3 sys_pll_m0(
    .refclk     (clk),
    .clk0_out   (sd_card_clk),
    .clk1_out   (ext_mem_clk),
    .clk2_out   (ext_mem_clk_sft),
    .clk3_out   (video_clk),
    .clk4_out   (hdmi_5x_clk),
    .extlock    (sys_pll_lock),
    .reset      (~rst_n) // External button only; never feed lock-derived reset back to PLL.
);


// mem_clk 域把 write_finish 单拍转成 toggle，供 sd_card_clk 域可靠同步
always @(posedge ext_mem_clk or posedge rst_mem) begin
    if (rst_mem)
        frame_write_toggle_mem <= 1'b0;
    else if (frame_write_finish)
        frame_write_toggle_mem <= ~frame_write_toggle_mem;
end

// ===================== TF 多图扫描与缓存（双缓冲） =====================
sd_card_bmp #(
    .CLK_FREQ_HZ       (100_000_000),
    .SCAN_START_SECTOR (32'd0),
    .SCAN_MAX_SECTOR   (32'd131071),
    .SCAN_TARGET_COUNT (3'd4), .USE_FRAME_RESULT(1)
) sd_card_bmp_m0(
    .clk               (sd_card_clk),
    .rst               (rst_sd),
    .sdram_ready       (sdram_ready_sync[1]),
    .key1              (key1),
    .key2              (key2),
    .key4              (key4),
    .mode              (switch_mode),
    .state_code        (state_code),
    .sd_debug(sd_debug), .diagnostics(uart_diagnostics),
    .combo_event_count (combo_event_count),
    .combo_debug_active(combo_debug_active),
    .auto_play_indicator(auto_play_indicator),
    .osd_error_code(osd_error_src),
    .bmp_width         (16'd640),
    .bmp_height        (16'd480),
    .display_valid     (display_valid),
    .committed_image(committed_image), .committed_valid(committed_valid),
    .committed_ready(committed_ready),

    .source_frame_done(source_frame_done), .source_frame_error(source_frame_error),
    .frame_error_toggle(frame_error_toggle), .frame_memory_error(frame_memory_error),
    .reader_error(frame_reader_error), .reader_underflow(frame_underflow),
    .write_finish_toggle(frame_write_toggle_mem),
    .display_commit_request(display_commit_request),
    .transition_frame_toggle(transition_frame_toggle),
    .transition_active(transition_active_sd),
    .transition_level(transition_level_sd),
    .display_commit_ack(display_commit_ack),
    .write_buf_idx     (write_buf_idx),
    .disp_buf_idx      (disp_buf_idx),

    .write_cancel_req(write_cancel_req), .write_cancel_ack(write_cancel_ack),
    .write_req         (sd_card_write_req),
    .write_req_ack     (sd_card_write_req_ack),
    .write_en          (sd_card_write_en),
    .write_data        (sd_card_write_data),
    .SD_nCS            (sd_ncs),
    .SD_DCLK           (sd_dclk),
    .SD_MOSI           (sd_mosi),
    .SD_MISO           (sd_miso)
);

seg7_panel seg7_panel_m0(
    .sd_debug(sd_debug_panel1),
    .clk               (clk),
    .rst_n             (~rst_panel),
    .mode              (mode_panel_sync1),
    .state_code        (state_code),
    .combo_event_count (combo_event_count),
    .combo_debug_active(combo_debug_active),
    .auto_play_indicator(auto_indicator_sync[1]),
    .seg_sel            (seg_sel),
    .seg_data           (seg_data)
);

// ===================== 原图像时序与帧缓存 =====================
video_timing_data video_timing_data_m0(
    .video_clk         (video_clk),
    .rst               (rst_video),
    .read_req          (video_read_req),
    .read_req_ack      (video_read_req_ack),
    .hs                (hs_0),
    .vs                (vs_0),
    .de                (de_0),
    .video_x           (video_x_0)
);

video_delay video_delay_m0(
    .video_clk         (video_clk),
    .rst               (rst_video),
    .read_en           (video_read_en),
    .read_data         (video_read_data[31:8]),
    .hs                (hs_0),
    .vs                (vs_0),
    .de                (de_0),
    .video_x           (video_x_0),
    .hs_r              (hs),
    .vs_r              (vs),
    .de_r              (de),
    .vout_data         (vout_data_raw),
    .video_x_r         (video_x)
);

// 首图提交前黑屏；提交后一直显示当前显示缓冲区内容
assign vout_data = display_valid ? vout_data_raw : 24'd0;

video_transition_pixels u_video_transition_pixels(
    .clk(video_clk), .rst(rst_video), .frame_start(sub_frame_start),
    .active(transition_active_v2), .level(transition_level_v2),
    .rgb_in(vout_data), .rgb_out(transition_rgb)
);

// S1 separates ownership of each FIFO; the established burst interlock stays.
media_frame_loader #(.WRITE_V_FLIP(1),.FRAME_WIDTH(640),.FRAME_HEIGHT(480)) u_frame_loader(
    .rst(rst_mem),.mem_clk(ext_mem_clk),.write_clk(sd_card_clk),.write_rst(rst_sd),
    .Sdr_init_done(Sdr_init_done),.Sdr_init_ref_vld(Sdr_init_ref_vld),.Sdr_busy(Sdr_busy),
    .App_rd_busy(frame_rd_busy),.O_wr_busy(frame_wr_busy),
    .App_wr_en(App_wr_en),.App_wr_addr(App_wr_addr),.App_wr_din(App_wr_din),.App_wr_dm(App_wr_dm),
    .write_req(sd_card_write_req),.write_req_ack(sd_card_write_req_ack),
    .write_cancel_req(write_cancel_req),.write_cancel_ack(write_cancel_ack),
    .write_finish(frame_write_finish),.source_done(source_frame_done),.source_error(source_frame_error),
    .error_toggle(frame_error_toggle),.memory_error(frame_memory_error),
    .write_addr_0(BUF0_ADDR),.write_addr_1(BUF1_ADDR),.write_addr_2(BUF2_ADDR),.write_addr_3(BUF3_ADDR),
    .write_addr_index(write_buf_idx),.write_len(FRAME_PIXELS),
    .write_en(sd_card_write_en),.write_data(sd_card_write_data)
);
media_frame_reader u_frame_reader(
    .rst(rst_mem),.mem_clk(ext_mem_clk),.read_clk(video_clk),.read_rst(rst_video),
    .Sdr_init_done(Sdr_init_done),.Sdr_init_ref_vld(Sdr_init_ref_vld),.Sdr_busy(Sdr_busy),
    .App_wr_busy(frame_wr_busy),.O_rd_busy(frame_rd_busy),
    .App_rd_en(App_rd_en),.App_rd_addr(App_rd_addr),.Sdr_rd_en(Sdr_rd_en),.Sdr_rd_dout(Sdr_rd_dout),
    .read_req(video_read_req),.read_req_ack(video_read_req_ack),.read_finish(),
    .display_commit_request(display_commit_request),.display_commit_ack(display_commit_ack),
    .read_addr_0(BUF0_ADDR),.read_addr_1(BUF1_ADDR),.read_addr_2(BUF2_ADDR),.read_addr_3(BUF3_ADDR),
    .read_addr_index(disp_buf_idx),.read_len(FRAME_PIXELS),
    .read_en(video_read_en),.display_valid(display_valid),.read_data(video_read_data),
    .underflow(frame_underflow),.reader_error(frame_reader_error)
);

sdram U3(
    .Clk               (ext_mem_clk),
    .Clk_sft           (ext_mem_clk_sft),
    .Rst               (rst_mem),
    .Sdr_init_done     (Sdr_init_done),
    .Sdr_init_ref_vld  (Sdr_init_ref_vld),
    .Sdr_busy          (Sdr_busy),
    .App_wr_en         (App_wr_en),
    .App_wr_addr       (App_wr_addr),
    .App_wr_dm         (App_wr_dm),
    .App_wr_din        (App_wr_din),
    .App_rd_en         (App_rd_en),
    .App_rd_addr       (App_rd_addr),
    .Sdr_rd_en         (Sdr_rd_en),
    .Sdr_rd_dout       (Sdr_rd_dout)
);

// S8: melody changes only after the display handoff has completed.
media_commit_cdc u_media_commit_cdc (
 .src_clk(sd_card_clk), .dst_clk(video_clk), .src_rst(rst_sd), .dst_rst(rst_video),
 .src_image(committed_image), .src_valid(committed_valid), .src_ready(committed_ready),
 .media_id(audio_image), .media_update(audio_update), .media_enable(audio_enable)
);
osd_status_cdc u_osd_status_cdc (
    .src_clk(sd_card_clk), .src_rst(rst_sd),
    .src_auto(auto_play_indicator), .src_error(osd_error_src),
    .dst_clk(video_clk), .dst_rst(rst_video),
    .dst_auto(osd_auto_pixel), .dst_error(osd_error_pixel)
);
// AUTO/error: acknowledged SD-domain mailbox. Image ID/valid: existing pixel
// domain media commit. Status snapshots at first active pixel after blanking.
// RGB layers are combinational; final HS/VS/DE/X pass directly to HDMI.
status_osd_overlay #(.OSD_ENABLE(OSD_ENABLE)) u_status_osd (
    .clk(video_clk), .rst(rst_video), .vs(vs), .de(de), .pixel_x(video_x),
    .rgb_in(transition_rgb), .image_index(audio_image), .image_valid(audio_enable),
    .auto_enabled(osd_auto_pixel), .error_code(osd_error_pixel), .rgb_out(osd_rgb),
    .active(status_glyph_active)
);
scroll_text_overlay #(.ENABLE(OSD_ENABLE && SCROLL_ENABLE), .CN_ENABLE(1), .RUNTIME_ENABLE(1)) u_scroll_osd (
 .clk(video_clk),.rst(rst_video),.vs(vs),.de(de),.pixel_x(video_x),.image_valid(audio_enable),
 .rgb_in(osd_rgb),.rgb_out(scroll_rgb),.active(scroll_glyph_active),
 .runtime_text(sub_text_pixel),.runtime_length(sub_length_pixel),
 .runtime_enable(sub_enable_pixel),.runtime_text_changed(sub_text_changed)
);
timestamp_osd #(.ENABLE(OSD_ENABLE && TIMESTAMP_ENABLE)) u_timestamp_osd(
 .clk(video_clk),.rst(rst_video),.vs(vs),.de(de),.pixel_x(video_x),
 .rgb_in(scroll_rgb),.rgb_out(timestamp_rgb),.active(timestamp_glyph_active));
osd_alpha_band #(.ENABLE(OSD_ENABLE && BAND_ENABLE), .RUNTIME_ENABLE(1)) u_osd_band(
 .clk(video_clk),.rst(rst_video),.vs(vs),.de(de),.pixel_x(video_x),
 .rgb_in(timestamp_rgb),.glyph_active(status_glyph_active || scroll_glyph_active || timestamp_glyph_active),
 .rgb_out(band_rgb),.active(),.subtitle_enable(sub_enable_pixel && sub_length_pixel!=0)
);
wire pcm_valid, pcm_ready, pcm_overflow, hdmi_sequence_error;
wire signed [15:0] pcm_left, pcm_right;
pcm_media_tone u_pcm_clock (
    .clk(video_clk), .rst_n(~rst_video), .enable(audio_enable),
    .media_id(audio_image), .media_update(audio_update), .volume(8'd128),
    .sample_valid(pcm_valid), .sample_ready(pcm_ready),
    .sample_left(pcm_left), .sample_right(pcm_right), .blip_active(), .overflow(pcm_overflow)
);
media_hdmi_audio_bridge u_media_hdmi_audio_bridge (
    .pixel_clk(video_clk), .pixel_rst_n(~rst_video),
    .video_hsync(hs), .video_vsync(vs), .video_de(de),
    .video_x(video_x), .video_rgb(band_rgb),
    .select_media(1'b1), .test_valid(1'b0), .test_ready(),
    .test_left(16'sd0), .test_right(16'sd0),
    .media_valid(pcm_valid), .media_ready(pcm_ready),
    .media_left(pcm_left), .media_right(pcm_right),
    .channel0_symbol(tmds_ch0_data), .channel1_symbol(tmds_ch1_data),
    .channel2_symbol(tmds_ch2_data), .sequence_error(hdmi_sequence_error),
    .pcm_tap_valid(), .pcm_tap_left(), .pcm_tap_right()
);
assign tmds_clk_data = 10'b1111100000; // Serialized bit 0 first by existing PHY.
assign HDMI_DDC_SCL = 1'bz;
assign HDMI_DDC_SDA = 1'bz;

hdmi_phy_wrapper #(
    .DEVICE ( "EG" )
) u_hdmi2phy_wrapper(
    .I_pixel_clk        (video_clk),
    .I_serial_clk       (hdmi_5x_clk),
    .I_rst              (rst_video),
    .I_serial_rst       (rst_serial),
    .I_tmds_channel_0   (tmds_ch0_data),
    .I_tmds_channel_1   (tmds_ch1_data),
    .I_tmds_channel_2   (tmds_ch2_data),
    .I_tmds_channel_clk (tmds_clk_data),
    .O_tmds_ch0_p       (HDMI_D0_P),
    .O_tmds_ch1_p       (HDMI_D1_P),
    .O_tmds_ch2_p       (HDMI_D2_P),
    .O_tmds_clk_p       (HDMI_CLK_P)
);

endmodule
