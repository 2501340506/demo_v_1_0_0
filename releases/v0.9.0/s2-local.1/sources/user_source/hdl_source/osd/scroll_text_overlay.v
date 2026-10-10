// Fixed text, RGB888 combinational overlay; no video latency or text CDC.
module scroll_text_overlay #(
    parameter integer ENABLE = 1,
    parameter integer TEXT_LEN = 25,
    parameter [TEXT_LEN*8-1:0] TEXT = "ANLOGIC FPGA IMAGE PLAYER"
)(
    input clk, rst, vs, de,
    input [9:0] pixel_x,
    input image_valid,
    input [23:0] rgb_in,
    output wire [23:0] rgb_out,
    output wire active
);
    localparam integer TEXT_WIDTH = TEXT_LEN * 16;
    // Window [8,632): text starts at x=632 and ends at x=8-TEXT_WIDTH.
    // Retain one fully outside position at each end of the cycle.
    localparam integer LAST_STEP = 624 + TEXT_WIDTH;
    localparam integer STEP_BITS = $clog2(LAST_STEP + 1);
    reg [STEP_BITS-1:0] scroll;
    reg [8:0] line_y;
    reg vs_q, de_q, started;
    wire frame_start = vs_q && !vs;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            vs_q <= 1;
            de_q <= 0;
            line_y <= 0;
            scroll <= 0;
            started <= 0;
        end else begin
            vs_q <= vs;
            de_q <= de;
            if (!vs) line_y <= 0;
            else if (de_q && !de) line_y <= line_y + 1'b1;
            if (frame_start && ENABLE && image_valid) begin
                if (!started) begin
                    started <= 1;
                    scroll <= 0;
                end else
                    scroll <= (scroll == LAST_STEP) ? 0 : scroll + 1'b1;
            end
        end
    end

    // Use a signed local coordinate: negative means not yet inside the text.
    wire signed [STEP_BITS+1:0] text_x = $signed({2'b00,scroll}) +
                                                $signed({1'b0,pixel_x}) - 632;
    wire [8:0] dy = line_y - 9'd444;
    reg [7:0] character;
    always @* begin
        character = " ";
        if (text_x >= 0 && text_x < TEXT_WIDTH)
            character = TEXT[(TEXT_LEN-1-(text_x >> 4))*8 +: 8];
    end
    wire [4:0] glyph;
    osd_font_5x7 font(.character(character), .row(dy[3:1]), .pixels(glyph));
    wire in_region = ENABLE && started && de && pixel_x >= 8 && pixel_x < 632 &&
                     line_y >= 444 && line_y < 460 && text_x >= 0 && text_x < TEXT_WIDTH;
    wire hit = in_region && text_x[3:1] < 5 && dy[3:1] < 7 &&
               glyph[3'd4-text_x[3:1]];
    assign active = hit;
    assign rgb_out = hit ? 24'hffffff : rgb_in;
endmodule
