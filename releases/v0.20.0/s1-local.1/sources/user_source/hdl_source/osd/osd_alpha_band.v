// Same-cycle RGB888 bands: protect glyphs by provenance, not by color.
module osd_alpha_band #(parameter integer ENABLE = 1, parameter integer RUNTIME_ENABLE = 0,
    parameter integer ALT_LAYOUT_ENABLE = 0)(
    input clk, rst, vs, de,
    input [9:0] pixel_x,
    input [23:0] rgb_in,
    input glyph_active,
    input subtitle_enable,
    output wire [23:0] rgb_out,
    output wire active,
    input alternate_layout
);
    wire [8:0] line_y;
    osd_pixel_position position(.clk(clk), .rst(rst), .vs(vs), .de(de),
        .line_y(line_y), .frame_start(), .first_active());
    wire status_band = de && pixel_x >= 4 && pixel_x < 284 &&
                       line_y >= 4 && line_y < 28;
    wire [8:0] band_y = ALT_LAYOUT_ENABLE && alternate_layout ? 9'd420 : 9'd440;
    wire scroll_band = (!RUNTIME_ENABLE || subtitle_enable) && de && pixel_x >= 8 && pixel_x < 632 &&
                       line_y >= band_y && line_y < band_y+9'd24;
    assign active = ENABLE && (status_band || scroll_band) && !glyph_active;
    assign rgb_out = active ?
        {1'b0, rgb_in[23:17], 1'b0, rgb_in[15:9], 1'b0, rgb_in[7:1]} : rgb_in;
endmodule
