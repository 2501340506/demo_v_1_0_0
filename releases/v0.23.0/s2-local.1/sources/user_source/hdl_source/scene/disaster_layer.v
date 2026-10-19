// One ten-clock contract for legacy and typed scene pixels and all sidebands.
module disaster_layer #(parameter SIDE_WIDTH=1)(
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
 // Synchronous BRAM reads include the final delay clock. Separate rings
 // preserve the legacy eight-clock and sideband ten-clock contracts.
 reg [23:0] old_delay[0:31]; /* fehdl force_ram=1, ram_style="bram" */
 reg [SIDE_WIDTH-1:0] side_delay[0:31]; /* fehdl force_ram=1, ram_style="bram" */
 reg [23:0] old_q;
 reg [SIDE_WIDTH-1:0] side_q;
 reg [4:0] write_slot;
 // TD08 measured a direct register-to-BRAM address Hold violation on bit 4.
 wire [4:0] ram_write_slot;
 assign ram_write_slot[3:0]=write_slot[3:0];
 (* keep="true" *) AL_MAP_LUT1 #(.INIT(2'b10),.EQN("A"))
  u_address_hold4(.o(ram_write_slot[4]),.a(write_slot[4]));
 reg [3:0] fill_count;
 reg old_primed,side_primed;
 reg [9:0] select_delay;
 // Preserve delay on the measured short legacy BRAM input paths.
 wire [23:0] old_ram_input;
 // Multiple placements exposed different bits of this direct register/RAM
 // bus. Apply the same no-cycle delay to every bit, as for sidebands below.
 genvar rgb_bit;
 generate for(rgb_bit=0;rgb_bit<24;rgb_bit=rgb_bit+1)begin:g_old_rgb_hold
  (* keep="true" *) AL_MAP_LUT1 #(.INIT(2'b10),.EQN("A"))
   u_hold(.o(old_ram_input[rgb_bit]),.a(old_rgb[rgb_bit]));
 end endgenerate
 wire [SIDE_WIDTH-1:0] side_ram_input;
 genvar side_bit;
 // TD18/28/29 exposed different bits of the same direct sideband/BRAM bus.
 // Keep identical combinational delay on every bit; the ten-clock contract
 // and reset priming remain unchanged.
 generate for(side_bit=0;side_bit<SIDE_WIDTH;side_bit=side_bit+1)begin:g_side_hold
   (* keep="true" *) AL_MAP_LUT1 #(.INIT(2'b10),.EQN("A"))
    u_hold(.o(side_ram_input[side_bit]),.a(side_in[side_bit]));
 end endgenerate
 always @(posedge clk)begin
  old_delay[ram_write_slot]<=old_ram_input;
  old_q<=old_delay[ram_write_slot-5'd7];
  side_delay[ram_write_slot]<=side_ram_input;
  side_q<=side_delay[ram_write_slot-5'd9];
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   select_delay<=0;
   write_slot<=0;
   fill_count<=0;
   old_primed<=0;
   side_primed<=0;
  end else begin
   select_delay<={select_delay[8:0],typed};
   write_slot<=write_slot+1'b1;
   if(fill_count!=9)fill_count<=fill_count+1'b1;
   old_primed<=fill_count>=7;
   side_primed<=fill_count==9;
  end
 end
 assign rgb_out=select_delay[9]?new_rgb:(old_primed?old_q:24'd0);
 assign side_out=side_primed?side_q:{SIDE_WIDTH{1'b0}};
endmodule
