// Diagnostic only (not in production): six-digit boot timer.
// Counts ms from panel reset release. A = first pixel load start
// (state_code 3), b = first visible frame (display_valid). Before the
// first frame the right four digits run; afterwards the panel alternates
// "A  nnnn" / "b  nnnn" every 2 s. Segment/digit enables are active low.
// Clock it from sd_card_clk: adding flops to the 50 MHz pad clock shifted
// placement and broke hold on existing sd->clk crossings (4/4 seeds).
module boot_time_seg #(
    parameter integer CLK_FREQ = 100_000_000
)(
    input        clk,
    input        rst_n,
    input  [3:0] state_code,       // already in clk domain
    input        display_valid,    // video domain level
    output [5:0] seg_sel,
    output [7:0] seg_data
);
    localparam integer MS_TICKS = CLK_FREQ / 1000;
    reg [1:0] valid_sync;
    reg [$clog2(MS_TICKS)-1:0] tick;
    reg [15:0] now_bcd, load_bcd, frame_bcd;
    reg load_seen, frame_seen;
    reg [$clog2(2*CLK_FREQ)-1:0] page_timer;
    reg page;
    // BCD increment of four digits, saturating at 9999.
    function [15:0] bcd_inc(input [15:0] v);
        integer i; reg carry; begin
            bcd_inc = v; carry = 1'b1;
            if (v == 16'h9999) carry = 1'b0;
            for (i = 0; i < 4; i = i + 1)
                if (carry) begin
                    if (v[4*i+:4] == 4'd9) bcd_inc[4*i+:4] = 4'd0;
                    else begin bcd_inc[4*i+:4] = v[4*i+:4] + 4'd1; carry = 1'b0; end
                end
        end
    endfunction
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_sync <= 0; tick <= 0; now_bcd <= 0; load_bcd <= 0; frame_bcd <= 0;
            load_seen <= 0; frame_seen <= 0; page_timer <= 0; page <= 0;
        end else begin
            valid_sync <= {valid_sync[0], display_valid};
            if (!frame_seen) begin
                if (tick == MS_TICKS-1) begin tick <= 0; now_bcd <= bcd_inc(now_bcd); end
                else tick <= tick + 1'b1;
            end
            if (!load_seen && state_code == 4'd3) begin load_seen <= 1'b1; load_bcd <= now_bcd; end
            if (!frame_seen && valid_sync[1]) begin frame_seen <= 1'b1; frame_bcd <= now_bcd; end
            if (frame_seen) begin
                if (page_timer == 2*CLK_FREQ-1) begin page_timer <= 0; page <= ~page; end
                else page_timer <= page_timer + 1'b1;
            end
        end
    end
    wire [15:0] shown = !frame_seen ? now_bcd : page ? frame_bcd : load_bcd;
    wire [3:0] scan_index;
    reg [3:0] nibble;
    reg blank;
    always @* begin
        blank = 1'b0;
        case (scan_index)
            4'd0: begin nibble = frame_seen ? (page ? 4'hb : 4'ha) : state_code; end
            4'd1: begin nibble = 4'd0; blank = 1'b1; end
            4'd2: nibble = shown[15:12];
            4'd3: nibble = shown[11:8];
            4'd4: nibble = shown[7:4];
            default: nibble = shown[3:0];
        endcase
    end
    wire [6:0] seg;
    seg_decoder u_dec(.bin_data(nibble), .seg_data(seg));
    // Decimal point on digit 0 marks "load already captured".
    wire [7:0] digit = blank ? 8'hff : {~(scan_index == 4'd0 && load_seen), seg};
    seg_scan #(.CLK_FREQ(CLK_FREQ), .SCAN_FREQ(200)) u_scan(
        .clk(clk), .rst_n(rst_n), .seg_sel(seg_sel), .seg_data(seg_data),
        .seg_data_0(digit), .seg_data_1(digit), .seg_data_2(digit),
        .seg_data_3(digit), .seg_data_4(digit), .seg_data_5(digit),
        .scan_index(scan_index)
    );
endmodule
