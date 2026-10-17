`timescale 1ns/1ps
module tb_disaster_layer;
 parameter VEC_DIR=".";
 reg clk=0,rst=1;always #5 clk=~clk;
 reg [23:0] rgb=0;reg [7:0] a=0,t=0,kind=0;
 reg [1:0] stage=0;reg en=0,thumb=0,fast=0,slow=0;
 reg [47:0] side=0;wire [23:0] out,legacy;wire [47:0] out_side;wire dummy;
 disaster_layer #(.SIDE_WIDTH(48)) dut(.clk(clk),.rst(rst),.rgb_in(rgb),.arrival(a),.t_now(t),.kind(kind),
 .stage(stage),.enable(en),.thumbnail(thumb),.blink_fast(fast),.blink_slow(slow),.de(1'b1),
 .frame_start(1'b0),.frame_cnt(10'd0),.side_in(side),.rgb_out(out),.side_out(out_side));
 hazard_layer ref_old(.clk(clk),.rst(rst),.rgb_in(rgb),.arrival(a),.t_now(t),.stage(stage),
 .enable(en && kind==0),.thumbnail(thumb),.blink_fast(fast),.blink_slow(slow),.side_in(1'b0),.rgb_out(legacy),.side_out(dummy));
 reg [23:0] expected[0:7];reg [47:0] sides[0:9];
 integer checks=0;
 always @(posedge clk)begin
  if(!rst)begin
   for(integer i=7;i>0;i--)expected[i]=expected[i-1];expected[0]=legacy;
   for(integer i=9;i>0;i--)sides[i]=sides[i-1];sides[0]=side;
   #1;
   if(checks>12 && (out!==expected[7] || out_side!==sides[9]))
    $fatal(1,"legacy/side alignment pixel=%0d got=%h expected=%h side=%h/%h",checks,out,expected[7],out_side,sides[9]);
   checks++;
  end
 end
 initial begin
  repeat(3)@(negedge clk);rst=0;
  repeat(10000)begin
   @(negedge clk);rgb=$random;a=$random;t=$urandom_range(0,239);stage=$random;
   en=$random;thumb=$random;fast=$random;slow=$random;side={$random,$random};
   kind=$urandom_range(0,1)?0:8'hff;
  end
  $display("PASS legacy, ordinary and all sidebands: %0d pixels",checks);$finish;
 end
endmodule
