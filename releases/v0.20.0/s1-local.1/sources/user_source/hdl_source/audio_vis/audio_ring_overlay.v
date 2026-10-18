// Bottom PCM history bars. Preserve the established two-clock video latency
// and module interface; no geometry ROM or opaque background is needed.
module audio_ring_overlay #(
 parameter integer ENABLE=1
)(
 input wire clk,rst,hs,vs,de,enable,
 input wire [9:0] pixel_x,
 input wire [8:0] pixel_y,
 input wire [23:0] rgb_in,
 input wire [4:0] bar_height,
 output wire [6:0] bar_index,
 output reg hs_out,vs_out,de_out,
 output reg [9:0] x_out,
 output reg [23:0] rgb_out
);
 // Full-width 80-bar history, 3px ink per 8px slot. The publicity subtitle
 // band ends at y=444, leaving an 8px gap above the maximum bar height.
 reg [6:0] index_q;
 reg [4:0] distance_q;
 reg visible_q,hs_q,vs_q,de_q;
 reg [9:0] x_q;
 reg [23:0] rgb_q;
 wire [4:0] limited_height=bar_height>28 ? 5'd28 : bar_height;
 assign bar_index=index_q;
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   index_q<=0;distance_q<=0;visible_q<=0;
   hs_q<=1;vs_q<=1;de_q<=0;x_q<=0;rgb_q<=0;
   hs_out<=1;vs_out<=1;de_out<=0;x_out<=0;rgb_out<=0;
  end else begin
   index_q<=pixel_x[9:3];distance_q<=9'd479-pixel_y;
   visible_q<=ENABLE && enable && de && pixel_x<640 &&
              pixel_y>=452 && pixel_y<480 && pixel_x[2:0]>=2 && pixel_x[2:0]<5;
   hs_q<=hs;vs_q<=vs;de_q<=de;x_q<=pixel_x;rgb_q<=rgb_in;
   hs_out<=hs_q;vs_out<=vs_q;de_out<=de_q;x_out<=x_q;
   if(visible_q && distance_q<limited_height) rgb_out<=24'hb45ac8;
   else rgb_out<=rgb_q;
  end
 end
endmodule
