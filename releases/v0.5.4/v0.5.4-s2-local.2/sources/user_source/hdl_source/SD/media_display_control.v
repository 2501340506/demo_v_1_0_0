// Registered display policy; preserves the original one-cycle status latency.
module media_display_control #(
 parameter integer CLK_FREQ_HZ = 100_000_000,
 parameter integer DIAG_DISPLAY = 0
)(
 input clk, rst, combo_request,
 input sd_init_done, scan_done, display_valid, load_busy,
 input auto_play_en,
 input write_started_seen, source_done_now, write_finish_now,
 input [1:0] img_idx,
 input [3:0] bmp_state_code,
 output reg [3:0] state_code,
 output reg [7:0] combo_event_count,
 output reg combo_debug_active,
 output reg auto_play_indicator
);
 localparam integer COMBO_DEBUG_CYCLES = CLK_FREQ_HZ;
 reg [31:0] combo_debug_timer;
 always @(posedge clk or posedge rst) begin
  if (rst) begin
   state_code <= 0;
   combo_event_count <= 0;
   combo_debug_active <= 0;
   combo_debug_timer <= 0;
   auto_play_indicator <= 0;
  end else begin
        auto_play_indicator <= (DIAG_DISPLAY == 0) && display_valid && auto_play_en;
        if (combo_request && combo_event_count != 8'hff)
            combo_event_count <= combo_event_count + 8'd1;
        if (combo_request) begin
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

  end
 end
endmodule
