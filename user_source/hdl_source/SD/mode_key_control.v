// Three independent active-low keys. Mode gates new picture events only.
module mode_key_control #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer RESCAN_HOLD_MS = 2000
)(
    input wire clk, rst, enable,
    input wire key1, key2, key4,
    input wire [1:0] mode,
    output reg next_event, rescan_event,
    output wire previous_event, auto_toggle_event,
    output wire manual_activity
);
    wire press1, press2, press4;
    wire stable1, stable2, stable4;
    key_press_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) u_key1 (
        .clk(clk), .rst(rst), .button_in(key1),
        .press_pulse(press1), .button_stable_out(stable1)
    );
    key_press_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) u_key2 (
        .clk(clk), .rst(rst), .button_in(key2),
        .press_pulse(press2), .button_stable_out(stable2)
    );
    key_press_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) u_key4 (
        .clk(clk), .rst(rst), .button_in(key4),
        .press_pulse(press4), .button_stable_out(stable4)
    );
    // Capture the mode at the debounced press edge, even if mode changes on
    // that same clock. Holding a key across a mode change never creates a press.
    reg [1:0] press_mode;
    always @(posedge clk or posedge rst) begin
        if (rst) press_mode <= 0;
        else press_mode <= mode;
    end
    assign previous_event = enable && (press_mode == 0) && press1;
    localparam integer HOLD_CYCLES = (CLK_FREQ_HZ / 1000) * RESCAN_HOLD_MS;
    localparam integer HOLD_BITS = $clog2(HOLD_CYCLES + 1);
    reg [HOLD_BITS-1:0] held_cycles;
    reg stable2_d, long_fired, short_allowed;
    // Track KEY2 independently of media readiness. Only release re-arms it.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            stable2_d <= 1; held_cycles <= 0; long_fired <= 0;
            short_allowed <= 0; next_event <= 0; rescan_event <= 0;
        end else begin
            stable2_d <= stable2;
            next_event <= 0; rescan_event <= 0;
            if (stable2_d && !stable2) begin
                short_allowed <= enable && (mode == 0);
                held_cycles <= 1;
            end else if (!stable2) begin
                if (!enable || mode != 0) short_allowed <= 0;
                if (!long_fired) begin
                    if (held_cycles >= HOLD_CYCLES - 1) begin
                        rescan_event <= 1;
                        long_fired <= 1;
                        short_allowed <= 0;
                    end else held_cycles <= held_cycles + 1'b1;
                end
            end else begin
                if (!stable2_d && !long_fired && short_allowed && enable && mode == 0)
                    next_event <= 1;
                held_cycles <= 0; long_fired <= 0; short_allowed <= 0;
            end
        end
    end
    assign auto_toggle_event = enable && press4;
    assign manual_activity = enable &&
        (!stable1 || !stable2 || !stable4 || press1 || press2 || press4);
endmodule
