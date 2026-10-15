// M2 reference v1. Two clocks for RGB and every sideband; no DSP or RAM.
module hazard_layer #(parameter SIDE_WIDTH=1)(
 input clk,rst,input [23:0] rgb_in,input [7:0] arrival,t_now,
 input [1:0] stage,input enable,thumbnail,blink_fast,blink_slow,
 input [SIDE_WIDTH-1:0] side_in,
 output reg [23:0] rgb_out,output reg [SIDE_WIDTH-1:0] side_out
);
 reg [23:0] color,front_color;
 always @* begin
  case(stage)
   2'd1:begin color=24'h603010;front_color=24'hffe000;end
   2'd2:begin color=24'h0060e0;front_color=24'hffffff;end
   2'd3:begin color=24'h00c040;front_color=24'h00ff00;end
   default:begin color=0;front_color=0;end
  endcase
 end
 wire covered=stage!=0 && arrival<240 && arrival<=t_now;
 wire [8:0] age={1'b0,t_now}-{1'b0,arrival};
 wire front=covered && age<9'd6;
 reg [23:0] original_q,front_q;
 reg [9:0] mix_q[0:2];
 reg [SIDE_WIDTH-1:0] side_q;
 reg tint_q,front_on_q,spot_q,half_q;
 integer c;
 always @(posedge clk or posedge rst) begin
  if(rst)begin
   original_q<=0;front_q<=0;side_q<=0;side_out<=0;rgb_out<=0;
   tint_q<=0;front_on_q<=0;spot_q<=0;half_q<=0;
   for(c=0;c<3;c=c+1)mix_q[c]<=0;
  end else begin
   original_q<=rgb_in;front_q<=front_color;side_q<=side_in;side_out<=side_q;
   tint_q<=enable && !thumbnail && covered;
   front_on_q<=front && blink_fast;
   spot_q<=enable && !thumbnail && arrival==250 && blink_slow;
   half_q<=stage==2 && !front;
   for(c=0;c<3;c=c+1)begin
    if(stage==2 && !front)
     mix_q[c]<={2'b0,rgb_in[c*8+:8]}+{2'b0,color[c*8+:8]};
    else
     mix_q[c]<={2'b0,rgb_in[c*8+:8]}+{2'b0,color[c*8+:8]}+{1'b0,color[c*8+:8],1'b0};
    rgb_out[c*8+:8]<=spot_q ? (c==1 ? 8'hff : 8'h00) :
     !tint_q ? original_q[c*8+:8] : front_on_q ? front_q[c*8+:8] :
     half_q ? mix_q[c][8:1] : mix_q[c][9:2];
   end
  end
 end
endmodule
