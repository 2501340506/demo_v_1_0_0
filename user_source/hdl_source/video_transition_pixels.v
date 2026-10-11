`timescale 1ns/1ps

// Frame-stable RGB fade used between the reader and the OSD layers.
// level is updated only at frame_start: 0=black, 16=full brightness.
module video_transition_pixels (
    input  wire        clk,
    input  wire        rst,
    input  wire        frame_start,
    input  wire        active,
    input  wire [4:0]  level,
    input  wire [23:0] rgb_in,
    output wire [23:0] rgb_out
);
    reg [4:0] level_latched;
    wire [4:0] level_clamped = (level > 5'd16) ? 5'd16 : level;
    wire [12:0] r_mix = rgb_in[23:16] * level_latched;
    wire [12:0] g_mix = rgb_in[15:8]  * level_latched;
    wire [12:0] b_mix = rgb_in[7:0]   * level_latched;
    always @(posedge clk or posedge rst) begin
        if (rst) level_latched <= 5'd16;
        else if (frame_start) level_latched <= active ? level_clamped : 5'd16;
    end
    assign rgb_out = (active || (level_latched != 5'd16)) ?
                     {r_mix[11:4], g_mix[11:4], b_mix[11:4]} : rgb_in;
endmodule
