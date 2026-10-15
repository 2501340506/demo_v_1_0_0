// Six-digit display panel policy for the finished image-player design.
// Segment and digit enables are active low, matching seg_scan/seg_decoder.
module seg7_panel #(
    parameter integer CLK_FREQ  = 50_000_000,
    parameter integer SCAN_FREQ = 200, SCENE_ENABLE=0
)(
    input        clk,
    input        rst_n,
    input  [1:0] mode,
    input scene_enable,scene_warn,input [1:0] scene_stage,
    input  [3:0] state_code,
    input [63:0] sd_debug,
    input  [7:0] combo_event_count,
    input        combo_debug_active,
    input        auto_play_indicator,
    output [5:0] seg_sel,
    output [7:0] seg_data
);
    wire [7:0] blank_digit = 8'hff;
    wire show_sd_failure = state_code == 4'hf;
    // debug_timer never passes 2*CLK_FREQ-1.
    localparam integer DEBUG_BITS = $clog2(2*CLK_FREQ);
    reg [DEBUG_BITS-1:0] debug_timer;
    reg [1:0] debug_page;
    wire [15:0] debug_word = (debug_page==0) ? sd_debug[15:0] :
                            (debug_page==1) ? sd_debug[31:16] :
                            (debug_page==2) ? sd_debug[47:32] : sd_debug[63:48];
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin debug_timer<=0;debug_page<=0;end
        else if(!show_sd_failure) begin debug_timer<=0;debug_page<=0;end
        else if(debug_timer==2*CLK_FREQ-1) begin debug_timer<=0;debug_page<=debug_page+1'b1;end
        else debug_timer<=debug_timer+1'b1;
    end
    // seg_scan latches input scan_index each edge, so only the digit at that
    // position is formed: one nibble select feeds one shared decoder.
    wire [3:0] scan_index;
    reg [3:0] digit_nibble;
    always @* begin
        case (scan_index)
            4'd0: digit_nibble = debug_word[15:12];
            4'd1: digit_nibble = debug_word[11:8];
            4'd2: digit_nibble = debug_word[7:4];
            4'd3: digit_nibble = debug_word[3:0];
            4'd4: digit_nibble = show_sd_failure ? {2'b00,debug_page} : {2'b00,mode};
            default: digit_nibble = SCENE_ENABLE && scene_enable && !show_sd_failure ? (scene_warn?4'ha:{2'd0,scene_stage}+4'd1) : combo_debug_active ? combo_event_count[3:0] : state_code;
        endcase
    end
    wire [6:0] digit_seg;
    seg_decoder u_digit_decoder(.bin_data(digit_nibble), .seg_data(digit_seg));
    wire digit_blank = scan_index < 4'd4 && !show_sd_failure;
    wire digit_point = (scan_index == 4'd5 && !combo_debug_active) ? (SCENE_ENABLE && scene_enable ? 1'b1 : ~auto_play_indicator) : 1'b1;
    wire [7:0] digit = digit_blank ? blank_digit : {digit_point, digit_seg};
    seg_scan #(.CLK_FREQ(CLK_FREQ), .SCAN_FREQ(SCAN_FREQ)) u_scan(
        .clk(clk), .rst_n(rst_n), .seg_sel(seg_sel), .seg_data(seg_data),
        .seg_data_0(digit), .seg_data_1(digit), .seg_data_2(digit),
        .seg_data_3(digit), .seg_data_4(digit), .seg_data_5(digit),
        .scan_index(scan_index)
    );
endmodule
