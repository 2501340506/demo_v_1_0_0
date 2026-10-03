// Raw keys -> synchronized/debounced gestures -> media events.
// Long duration starts at the stable falling edge, not chord classification.
module key_gesture_control #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer LONG_PRESS_MS = 1000,
    parameter integer COMBO_WINDOW_MS = 100
)(
    input wire clk, rst, enable,
    input wire key_next, key_auto,
    output wire next_event,
    output reg previous_event, auto_toggle_event,
    output wire combo_event,
    output wire manual_activity
);
    localparam integer LONG_PRESS_CYCLES = (CLK_FREQ_HZ / 1000) * LONG_PRESS_MS;
    localparam integer COMBO_WINDOW_CYCLES = (CLK_FREQ_HZ / 1000) * COMBO_WINDOW_MS;
    wire key1_stable, key2_stable;
    reg key1_stable_d, key2_stable_d;
    wire key1_press_event = key1_stable_d && !key1_stable;
    wire key2_press_event = key2_stable_d && !key2_stable;
    wire key1_release_event = !key1_stable_d && key1_stable;
    wire key2_release_event = !key2_stable_d && key2_stable;
    wire key2_single_press_event, key2_single_release_event;
    wire gesture_active;
    wire event_reset = rst || !enable;
    reg [31:0] long_press_count;
    reg key2_held, key2_long_fired;
    wire key2_long_due = (key2_held || key2_single_press_event) &&
        !key2_stable && !key2_long_fired &&
        (long_press_count >= LONG_PRESS_CYCLES - 1);

    // Stable levels and event pipeline keep autoplay blocked through handoff.
    assign manual_activity = enable && (!key1_stable || !key2_stable ||
        gesture_active || previous_event || auto_toggle_event);

    key_press_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .DEBOUNCE_MS(20)) u_key_next (
        .clk(clk), .rst(rst), .button_in(key_next), .press_pulse(),
        .button_stable_out(key1_stable)
    );
    key_press_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .DEBOUNCE_MS(20)) u_key_auto (
        .clk(clk), .rst(rst), .button_in(key_auto), .press_pulse(),
        .button_stable_out(key2_stable)
    );
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            key1_stable_d <= 1'b1;
            key2_stable_d <= 1'b1;
        end else begin
            key1_stable_d <= key1_stable;
            key2_stable_d <= key2_stable;
        end
    end
    dual_key_event_router #(.COMBO_WINDOW_CYCLES(COMBO_WINDOW_CYCLES)) u_router (
        .clk(clk), .rst(event_reset),
        .key1_stable(key1_stable), .key2_stable(key2_stable),
        .key1_press_event(key1_press_event), .key2_press_event(key2_press_event),
        .key1_release_event(key1_release_event), .key2_release_event(key2_release_event),
        .combo_active(), .combo_press_event(combo_event), .combo_release_event(),
        .key1_single_press_event(next_event), .key1_single_release_event(),
        .key2_single_press_event(key2_single_press_event),
        .key2_single_release_event(key2_single_release_event),
        .gesture_active(gesture_active)
    );
    always @(posedge clk or posedge event_reset) begin
        if (event_reset) begin
            long_press_count <= 0;
            key2_held <= 0;
            key2_long_fired <= 0;
            previous_event <= 0;
            auto_toggle_event <= 0;
        end else begin
            previous_event <= 0;
            auto_toggle_event <= 0;
            if (key2_stable)
                long_press_count <= 0;
            else if (long_press_count < LONG_PRESS_CYCLES)
                long_press_count <= long_press_count + 1'b1;

            if (key2_single_release_event) begin
                if (!key2_long_fired && (key2_held || key2_single_press_event))
                    auto_toggle_event <= 1;
                key2_held <= 0;
                key2_long_fired <= 0;
            end else begin
                if (key2_single_press_event)
                    key2_held <= 1;
                if (key2_long_due) begin
                    previous_event <= 1;
                    key2_long_fired <= 1;
                end
            end
        end
    end
endmodule
