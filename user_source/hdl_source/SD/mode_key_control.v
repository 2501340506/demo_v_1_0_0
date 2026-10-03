// Three independent active-low keys. Mode gates new picture events only.
module mode_key_control #(
    parameter integer CLK_FREQ_HZ = 100_000_000
)(
    input wire clk, rst, enable,
    input wire key1, key2, key4,
    input wire [1:0] mode,
    output wire next_event, previous_event, auto_toggle_event,
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
    assign next_event = enable && (press_mode == 0) && press2;
    assign auto_toggle_event = enable && press4;
    assign manual_activity = enable &&
        (!stable1 || !stable2 || !stable4 || press1 || press2 || press4);
endmodule
