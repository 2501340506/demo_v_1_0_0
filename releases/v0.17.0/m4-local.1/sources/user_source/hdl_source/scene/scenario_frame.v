// State arrives through media_adjust_cdc's bundled handshake. First-pixel mux
// makes the whole active frame, including pixel zero, use one parameter set.
module scenario_frame(
 input clk,rst,first_active,input [12:0] scene_state,
 output [1:0] stage,output [7:0] t_now,output enable,blink_fast,blink_slow
);
 reg [12:0] held;
 reg [7:0] fast_q,slow_q;
 wire [12:0] visible=first_active?scene_state:held;
 wire [8:0] fast_sum={1'b0,fast_q}+({7'd0,visible[11:10]}+1'b1)*9'd8;
 wire [8:0] slow_sum={1'b0,slow_q}+9'd4;
 wire restart=!visible[12] || visible[9:8]!=held[9:8];
 wire [7:0] fast_next=restart?8'd0:fast_sum>=240?fast_sum-9'd240:fast_sum[7:0];
 wire [7:0] slow_next=restart?8'd0:slow_sum>=240?slow_sum-9'd240:slow_sum[7:0];
 // {enable,alert[1:0],stage[1:0],time[7:0]}.
 assign stage=visible[9:8];assign t_now=visible[7:0];assign enable=visible[12];
 assign blink_fast=(first_active?fast_next:fast_q)<120;
 assign blink_slow=(first_active?slow_next:slow_q)<120;
 always @(posedge clk or posedge rst)begin
  if(rst)begin held<=0;fast_q<=0;slow_q<=0;end
  else if(first_active)begin held<=scene_state;fast_q<=fast_next;slow_q<=slow_next;end
 end
endmodule
