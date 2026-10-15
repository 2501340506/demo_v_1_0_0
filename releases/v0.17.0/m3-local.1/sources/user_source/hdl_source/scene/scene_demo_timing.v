// M3 temporary source, pixel domain only. Replace with scenario_fsm in M4.
// image/ready are already transferred by media_commit_cdc, not raw SD signals.
// Select the next frame state on first_active itself, so pixel zero agrees
// with the remainder of the frame even though the registers update that edge.
module scene_demo_timing(
 input clk,rst,first_active,ready,thumbnail,input [1:0] image,
 output [1:0] stage,output [7:0] t_now,
 output blink_fast,blink_slow,output layer_enable
);
 reg [1:0] stage_q;
 reg [7:0] time_q,fast_q,slow_q;
 reg half_q,enabled_q,preview_q;
 wire restart=!ready || thumbnail || !enabled_q || image!=stage_q || preview_q;
 wire [7:0] next_time=restart ? 8'd0 : half_q ? (time_q==239 ? 8'd0 : time_q+1'b1) : time_q;
 wire [8:0] fast_sum={1'b0,fast_q}+({7'd0,image}+9'd1)*9'd8;
 wire [8:0] slow_sum={1'b0,slow_q}+9'd4;
 wire [7:0] next_fast=restart ? 8'd0 : fast_sum>=240 ? fast_sum-9'd240 : fast_sum[7:0];
 wire [7:0] next_slow=restart ? 8'd0 : slow_sum>=240 ? slow_sum-9'd240 : slow_sum[7:0];
 assign stage=first_active ? image : stage_q;
 assign t_now=first_active ? next_time : time_q;
 assign blink_fast=(first_active ? next_fast : fast_q)<120;
 assign blink_slow=(first_active ? next_slow : slow_q)<120;
 assign layer_enable=ready && (first_active ? !thumbnail : enabled_q) && !thumbnail;
 always @(posedge clk or posedge rst)begin
  if(rst)begin stage_q<=0;time_q<=0;fast_q<=0;slow_q<=0;half_q<=0;enabled_q<=0;preview_q<=0;end
  else if(first_active)begin
   stage_q<=image;preview_q<=thumbnail;enabled_q<=ready && !thumbnail;
   if(!ready || thumbnail)begin time_q<=0;half_q<=0;fast_q<=0;slow_q<=0;end
   else begin
    time_q<=next_time;half_q<=restart ? 1'b0 : !half_q;
    fast_q<=next_fast;slow_q<=next_slow;
   end
  end
 end
endmodule
