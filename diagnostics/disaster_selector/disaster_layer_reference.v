// One ten-clock contract for legacy and typed scene pixels and all sidebands.
module disaster_layer_reference #(parameter SIDE_WIDTH=1)(
 input clk,rst,input [23:0] rgb_in,input [7:0] arrival,t_now,kind,
 input [1:0] stage,input enable,thumbnail,blink_fast,blink_slow,
 input de,frame_start,input [9:0] frame_cnt,
 input [SIDE_WIDTH-1:0] side_in,
 output [23:0] rgb_out,output [SIDE_WIDTH-1:0] side_out
);
 wire typed=kind[7:4]>=1 && kind[7:4]<=4 && kind[3:0]>=1 && kind[3:0]<=4;
 wire [23:0] old_rgb,new_rgb;
 wire unused_side;
 hazard_layer #(.SIDE_WIDTH(1)) legacy(.clk(clk),.rst(rst),.rgb_in(rgb_in),
  .arrival(arrival),.t_now(t_now),.stage(stage),.enable(enable && kind==0),
  .thumbnail(thumbnail),.blink_fast(blink_fast),.blink_slow(blink_slow),
  .side_in(1'b0),.rgb_out(old_rgb),.side_out(unused_side));
 hazard_layer_v3 modern(.clk(clk),.rst(rst),.rgb_in(rgb_in),.t_in(arrival),
  .de(de),.frame_start(frame_start),.t_now(t_now),.hazard(kind[6:4]),.role(kind[2:0]),
  .enable(enable && typed),.thumbnail(thumbnail),.frame_cnt(frame_cnt),.rgb_out(new_rgb));
 reg [23:0] old_delay[0:7];
 reg [SIDE_WIDTH-1:0] side_delay[0:9];
 reg [9:0] select_delay;
 integer i;
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   select_delay<=0;
   for(i=0;i<8;i=i+1)old_delay[i]<=0;
   for(i=0;i<10;i=i+1)side_delay[i]<=0;
  end else begin
   select_delay<={select_delay[8:0],typed};
   old_delay[0]<=old_rgb;
   for(i=1;i<8;i=i+1)old_delay[i]<=old_delay[i-1];
   side_delay[0]<=side_in;
   for(i=1;i<10;i=i+1)side_delay[i]<=side_delay[i-1];
  end
 end
 assign rgb_out=select_delay[9]?new_rgb:old_delay[7];
 assign side_out=side_delay[9];
endmodule
