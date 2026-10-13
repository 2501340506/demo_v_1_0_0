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
    input [63:0] sd_debug,
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
    wire [6:0] debug0,debug1,debug2,debug3;
    wire show_sd_failure = state_code == 4'hf;
    // debug_timer never passes 2*CLK_FREQ-1.
    localparam integer DEBUG_BITS = $clog2(2*CLK_FREQ);
    reg [DEBUG_BITS-1:0] debug_timer;
    reg [1:0] debug_page;
    wire [15:0] debug_word = (debug_page==0) ? sd_debug[15:0] :
                            (debug_page==1) ? sd_debug[31:16] :
                            (debug_page==2) ? sd_debug[47:32] : sd_debug[63:48];
    wire [6:0] debug_page_seg;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin debug_timer<=0;debug_page<=0;end
        else if(!show_sd_failure) begin debug_timer<=0;debug_page<=0;end
        else if(debug_timer==2*CLK_FREQ-1) begin debug_timer<=0;debug_page<=debug_page+1'b1;end
        else debug_timer<=debug_timer+1'b1;
    end
    seg_decoder u_debug0(.bin_data(debug_word[15:12]), .seg_data(debug0));
    seg_decoder u_debug1(.bin_data(debug_word[11:8]), .seg_data(debug1));
    seg_decoder u_debug2(.bin_data(debug_word[7:4]), .seg_data(debug2));
    seg_decoder u_debug3(.bin_data(debug_word[3:0]), .seg_data(debug3));
    seg_decoder u_debug_page(.bin_data({2'b00,debug_page}), .seg_data(debug_page_seg));

    seg_decoder u_number_decoder(.bin_data(state_code), .seg_data(number_seg));
    seg_decoder u_count_decoder(.bin_data(combo_event_count[3:0]), .seg_data(combo_count_seg));
    seg_decoder u_mode_decoder(.bin_data({2'b00, mode}), .seg_data(mode_seg));

    seg_scan #(.CLK_FREQ(CLK_FREQ), .SCAN_FREQ(SCAN_FREQ)) u_scan(
        .clk(clk), .rst_n(rst_n), .seg_sel(seg_sel), .seg_data(seg_data),
        .seg_data_0(show_sd_failure ? {1'b1,debug0} : blank_digit),
        .seg_data_1(show_sd_failure ? {1'b1,debug1} : blank_digit),
        .seg_data_2(show_sd_failure ? {1'b1,debug2} : blank_digit),
        .seg_data_3(show_sd_failure ? {1'b1,debug3} : blank_digit),
        .seg_data_4({1'b1, show_sd_failure ? debug_page_seg : mode_seg}),
        .seg_data_5(combo_debug_active ? count_digit : normal_digit)
    );
endmodule
