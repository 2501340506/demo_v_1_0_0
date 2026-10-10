// S1: zero-latency RGB888 status overlay. Timing is already aligned by
// video_delay. Coordinates are active-area coordinates, not porch counters.
module status_osd_overlay #(
    parameter integer OSD_ENABLE = 1
) (
    input clk, rst,
    input vs, de,
    input [9:0] pixel_x,
    input [23:0] rgb_in,
    input [1:0] image_index,
    input image_valid, auto_enabled,
    input [7:0] error_code,
    output wire [23:0] rgb_out
);
    reg [8:0] line_y;
    reg de_q, frame_pending;
    reg [1:0] image_frame;
    reg valid_frame, auto_frame;
    reg [7:0] error_frame;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            line_y <= 0;
            de_q <= 0;
            frame_pending <= 1;
            image_frame <= 0;
            valid_frame <= 0;
            auto_frame <= 0;
            error_frame <= 0;
        end else begin
            de_q <= de;
            if (!vs) begin
                line_y <= 0;
                frame_pending <= 1;
            end else if (de_q && !de)
                line_y <= line_y + 1'b1;
            // Reader commits during vertical blanking, after VS assertion.
            // Snapshot at the first active pixel; text starts on line eight.
            if (vs && de && frame_pending) begin
                image_frame <= image_index;
                valid_frame <= image_valid;
                auto_frame <= auto_enabled;
                error_frame <= error_code;
                frame_pending <= 0;
            end
        end
    end

    function [7:0] hex_char;
        input [3:0] nibble;
        begin hex_char = nibble < 10 ? 8'd48 + {4'b0,nibble} : 8'd55 + {4'b0,nibble}; end
    endfunction
    wire [9:0] dx = pixel_x - 10'd8;
    wire [8:0] dy = line_y - 9'd8;
    reg [7:0] character;
    always @* begin
        character = " ";
        case (dx[8:4])
            0: character = "P";
            1: character = "I";
            2: character = "C";
            3: character = ":";
            4: character = valid_frame ? 8'd49 + {6'b0,image_frame} : "-";
            6: character = auto_frame ? "A" : "M";
            7: character = auto_frame ? "U" : "A";
            8: character = auto_frame ? "T" : "N";
            9: character = auto_frame ? "O" : " ";
            11: character = "E";
            12: character = "R";
            13: character = "R";
            14: character = ":";
            15: character = hex_char(error_frame[7:4]);
            16: character = hex_char(error_frame[3:0]);
            default: character = " ";
        endcase
    end
    wire [4:0] glyph;
    osd_font_5x7 font(.character(character), .row(dy[3:1]), .pixels(glyph));
    wire in_region = OSD_ENABLE && de && pixel_x >= 8 && pixel_x < 280 &&
                     line_y >= 8 && line_y < 24;
    wire glyph_hit = in_region && dx[3:1] < 5 && dy[3:1] < 7 &&
                     glyph[3'd4 - dx[3:1]];
    assign rgb_out = glyph_hit ? (error_frame == 0 ? 24'hffff00 : 24'hff4444) : rgb_in;
endmodule
