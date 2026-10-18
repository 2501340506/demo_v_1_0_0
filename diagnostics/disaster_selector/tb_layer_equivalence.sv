`timescale 1ns/1ps
module tb_layer_equivalence;
 reg clk=0,rst=1; always #5 clk=~clk;
 reg [23:0] rgb=0;
 reg [7:0] arrival=0,t_now=0,kind=0;
 reg [1:0] stage=0;
 reg enable=0,thumbnail=0,fast=0,slow=0,de=0,frame_start=0;
 reg [9:0] frame_cnt=0;
 reg [61:0] side=0;
 integer checks=0,resets=0;
 wire [23:0] got,want;
 wire [61:0] got_side,want_side;
 disaster_layer #(.SIDE_WIDTH(62)) dut(
 .clk(clk),.rst(rst),.rgb_in(rgb),.arrival(arrival),.t_now(t_now),.kind(kind),
 .stage(stage),.enable(enable),.thumbnail(thumbnail),.blink_fast(fast),.blink_slow(slow),
 .de(de),.frame_start(frame_start),.frame_cnt(frame_cnt),.side_in(side),.rgb_out(got),.side_out(got_side));
 disaster_layer_reference #(.SIDE_WIDTH(62)) reference(
 .clk(clk),.rst(rst),.rgb_in(rgb),.arrival(arrival),.t_now(t_now),.kind(kind),
 .stage(stage),.enable(enable),.thumbnail(thumbnail),.blink_fast(fast),.blink_slow(slow),
 .de(de),.frame_start(frame_start),.frame_cnt(frame_cnt),.side_in(side),.rgb_out(want),.side_out(want_side));
 task compare;
 begin
  if(got!==want || got_side!==want_side)
   $fatal(1,"delay equivalence t=%0t rst=%b rgb=%h/%h side=%h/%h",$time,rst,got,want,got_side,want_side);
  checks=checks+1;
 end endtask
 always @(posedge clk)begin #1;compare();end
 initial begin
  repeat(3)@(negedge clk);rst=0;
  for(integer n=0;n<100000;n=n+1)begin
   @(negedge clk);
   rgb=$random;arrival=$random;t_now=$random;stage=$random;
   enable=$random;thumbnail=$random;fast=$random;slow=$random;de=$random;
   frame_start=(n%307200)==0;frame_cnt=$random;side={$random,$random};
   case(n%7)
    0:kind=0;1:kind=8'hff;2:kind=8'h11;3:kind=8'h22;
    4:kind=8'h33;5:kind=8'h44;6:kind=$random;
   endcase
   // Include resets between edges, before and after both BRAMs are primed.
   if(n%997==0 || n%997==4 || n%997==12)begin
    #2;rst=1;resets=resets+1;#1;compare();#1;rst=0;
   end
  end
  $display("PASS layer equivalence %0d comparisons %0d asynchronous resets",checks,resets);
  $finish;
 end
endmodule
