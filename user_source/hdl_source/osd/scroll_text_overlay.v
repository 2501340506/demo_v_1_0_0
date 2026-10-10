// Fixed text, RGB888 combinational overlay; no video latency or text CDC.
module scroll_text_overlay #(
    parameter integer ENABLE = 1,
    parameter integer TEXT_LEN = 25,
    parameter [TEXT_LEN*8-1:0] TEXT = "ANLOGIC FPGA IMAGE PLAYER",
    parameter integer WINDOW_LEFT = 8,
    parameter integer WINDOW_RIGHT = 632,
    parameter integer TEXT_Y = 444,
    parameter integer PIXELS_PER_FRAME = 1
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
    localparam integer LAST_STEP = WINDOW_RIGHT - WINDOW_LEFT + TEXT_WIDTH;
    localparam integer STEP_BITS = $clog2(LAST_STEP + 1);
    reg [STEP_BITS-1:0] scroll;
    wire [8:0] line_y;
    reg started;
    wire frame_start;
    osd_pixel_position position(.clk(clk), .rst(rst), .vs(vs), .de(de),
        .line_y(line_y), .frame_start(frame_start), .first_active());
    // TEXT is a synthesis-time constant. No asynchronous text bus is sampled.
    // A future runtime source must hold a complete mailbox until acknowledged;
    // commit its text/length/enable together here at frame_start.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scroll <= 0;
            started <= 0;
        end else begin
            if (frame_start && ENABLE && image_valid) begin
                if (!started) begin
                    started <= 1;
                    scroll <= 0;
                end else
                    if (scroll == LAST_STEP) scroll <= 0;
                    else if (scroll + PIXELS_PER_FRAME >= LAST_STEP) scroll <= LAST_STEP;
                    else scroll <= scroll + PIXELS_PER_FRAME;
            end
        end
    end

    // Use a signed local coordinate: negative means not yet inside the text.
    wire signed [31:0] text_x = $signed({1'b0,scroll}) +
                                                $signed({1'b0,pixel_x}) - WINDOW_RIGHT;
    wire [8:0] dy = line_y - TEXT_Y;
    reg [7:0] character;
    always @* begin
        character = " ";
        if (text_x >= 0 && text_x < TEXT_WIDTH)
            character = TEXT[(TEXT_LEN-1-(text_x >> 4))*8 +: 8];
    end
    wire [4:0] glyph;
    osd_font_5x7 font(.character(character), .row(dy[3:1]), .pixels(glyph));
    wire in_region = ENABLE && started && de && pixel_x >= WINDOW_LEFT && pixel_x < WINDOW_RIGHT &&
                     line_y >= TEXT_Y && line_y < TEXT_Y + 16 && text_x >= 0 && text_x < TEXT_WIDTH;
    wire hit = in_region && text_x[3:1] < 5 && dy[3:1] < 7 &&
               glyph[3'd4-text_x[3:1]];
    assign active = hit;
    assign rgb_out = hit ? 24'hffffff : rgb_in;
endmodule
