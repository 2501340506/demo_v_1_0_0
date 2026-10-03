// Six-digit display panel policy for the finished image-player design.
// Segment and digit enables are active low, matching seg_scan/seg_decoder.
module seg7_panel #(
    parameter integer CLK_FREQ  = 50_000_000,
    parameter integer SCAN_FREQ = 200
)(
    input        clk,
    input        rst_n,
    input  [1:0] mode,
    input  [3:0] state_code,
    input  [7:0] combo_event_count,
    input        combo_debug_active,
    input        auto_play_indicator,
    output [5:0] seg_sel,
    output [7:0] seg_data
);
    wire [6:0] number_seg;
    wire [6:0] combo_count_seg;
    wire [6:0] mode_seg;
    wire [7:0] count_digit = {1'b1, combo_count_seg};
    wire [7:0] normal_digit = {~auto_play_indicator, number_seg};
    wire [7:0] blank_digit = 8'hff;

    seg_decoder u_number_decoder(.bin_data(state_code), .seg_data(number_seg));
    seg_decoder u_count_decoder(.bin_data(combo_event_count[3:0]), .seg_data(combo_count_seg));
    seg_decoder u_mode_decoder(.bin_data({2'b00, mode}), .seg_data(mode_seg));

    seg_scan #(.CLK_FREQ(CLK_FREQ), .SCAN_FREQ(SCAN_FREQ)) u_scan(
        .clk(clk), .rst_n(rst_n), .seg_sel(seg_sel), .seg_data(seg_data),
        .seg_data_0(blank_digit), .seg_data_1(blank_digit),
        .seg_data_2(blank_digit), .seg_data_3(blank_digit),
        .seg_data_4({1'b1, mode_seg}),
        .seg_data_5(combo_debug_active ? count_digit : normal_digit)
    );
endmodule
