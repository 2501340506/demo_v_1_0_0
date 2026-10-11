`timescale 1ns/1ps
// level is already a frame-stable register in this pixel clock domain.
// Combinational RGB leaves the existing HS/VS/DE/X alignment unchanged.
module video_transition_pixels (
 input wire [4:0] level,
 input wire [23:0] rgb_in,
 output wire [23:0] rgb_out
);
 wire [12:0] r_mix=rgb_in[23:16]*level;
 wire [12:0] g_mix=rgb_in[15:8]*level;
 wire [12:0] b_mix=rgb_in[7:0]*level;
 assign rgb_out={r_mix[11:4],g_mix[11:4],b_mix[11:4]};
endmodule
