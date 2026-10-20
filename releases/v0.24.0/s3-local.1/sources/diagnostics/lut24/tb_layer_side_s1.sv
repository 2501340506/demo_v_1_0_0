`timescale 1ns/1ps
// v0.24 S1: production layer + picture-adjust chain with the original 62-bit
// sideband and the reduced 47-bit sideband (descriptor bits 24..8 only).
// RGB and every consumed sideband bit must match on every cycle.
module tb_layer_side_s1;
 parameter integer SEED=7, CYCLES=400000, DESC_LSB=8; // DESC_LSB!=8 is the mutant probe
 reg clk=0; always #5 clk=~clk;
 reg rst=1;
 integer seed=SEED;
 function integer urand(input integer n); begin urand=$unsigned($random(seed))%n; end endfunction
 reg [23:0] rgb_in=0; reg [7:0] arrival=0,t_now=0,kind=0; reg [1:0] stage=0;
 reg enable=0,thumbnail=0,blink_fast=0,blink_slow=0,de=0,frame_start=0;
 reg [9:0] frame_cnt=0,video_x=0; reg [8:0] ring_y=0; reg [31:0] descriptor=0;
 reg [4:0] level=0; reg wipe=0,hs=0,vs=0,display_valid=0,audio_enable=0;
 reg [7:0] brightness=128,contrast=128;
 wire [61:0] wide_in={hs,vs,de,video_x,ring_y,descriptor,level,wipe,display_valid,audio_enable};
 wire [46:0] narrow_in={hs,vs,de,video_x,ring_y,descriptor[DESC_LSB+16:DESC_LSB],level,wipe,display_valid,audio_enable};
 wire [23:0] r_layer,n_layer,r_rgb,n_rgb; wire [61:0] r_mid,r_side; wire [46:0] n_mid,n_side;
 disaster_layer_reference #(.SIDE_WIDTH(62)) ref_layer(.clk(clk),.rst(rst),.rgb_in(rgb_in),.arrival(arrival),
  .kind(kind),.de(de),.frame_start(frame_start),.frame_cnt(frame_cnt),.stage(stage),.t_now(t_now),.enable(enable),
  .thumbnail(thumbnail),.blink_fast(blink_fast),.blink_slow(blink_slow),.side_in(wide_in),.rgb_out(r_layer),.side_out(r_mid));
 brightness_contrast_adjust #(.SIDE_WIDTH(62)) ref_adjust(.clk(clk),.rst(rst),.rgb_in(r_layer),.brightness(brightness),
  .contrast(contrast),.side_in(r_mid),.rgb_out(r_rgb),.side_out(r_side));
 disaster_layer #(.SIDE_WIDTH(47)) new_layer(.clk(clk),.rst(rst),.rgb_in(rgb_in),.arrival(arrival),
  .kind(kind),.de(de),.frame_start(frame_start),.frame_cnt(frame_cnt),.stage(stage),.t_now(t_now),.enable(enable),
  .thumbnail(thumbnail),.blink_fast(blink_fast),.blink_slow(blink_slow),.side_in(narrow_in),.rgb_out(n_layer),.side_out(n_mid));
 brightness_contrast_adjust #(.SIDE_WIDTH(47)) new_adjust(.clk(clk),.rst(rst),.rgb_in(n_layer),.brightness(brightness),
  .contrast(contrast),.side_in(n_mid),.rgb_out(n_rgb),.side_out(n_side));
 // Reference outputs reduced to the bits consumed after the adjust stage.
 wire [46:0] r_used={r_side[61:40],r_side[32:16],r_side[7:0]};
 integer cycles=0,bad=0,typed=0,legacy=0;
 always @(negedge clk) if(!rst) begin
  cycles=cycles+1;
  if(r_rgb!==n_rgb || r_used!==n_side)begin bad=bad+1;if(bad<=5)$display("MISMATCH t=%0t rgb %h/%h side %h/%h",$time,r_rgb,n_rgb,r_used,n_side);end
  if(enable && kind!=0)typed=typed+1;
  if(enable && kind==0)legacy=legacy+1;
 end
 initial begin
  repeat(3)@(posedge clk);rst<=0;
  repeat(CYCLES)begin
   @(posedge clk);
   rgb_in<=$random(seed);arrival<=$random(seed);descriptor<=$random(seed);
   video_x<=$random(seed);ring_y<=$random(seed);level<=$random(seed);
   {hs,vs,de,wipe,display_valid,audio_enable}<=$random(seed);
   frame_start<=urand(800)==0;if(frame_start)frame_cnt<=frame_cnt+1;
   if(urand(500)==0)begin
    kind<=urand(3)==0?8'd0:{1'b0,3'd1+urand(4),1'b0,3'd1+urand(4)};
    stage<=urand(4);t_now<=$random(seed);enable<=urand(4)!=0;thumbnail<=urand(3)==0;
    blink_fast<=urand(2);blink_slow<=urand(2);brightness<=$random(seed);contrast<=$random(seed);
   end
  end
  $display("COVERAGE cycles=%0d typed=%0d legacy=%0d",cycles,typed,legacy);
  if(bad!=0)$display("FAIL layer side mismatches=%0d",bad);
  else if(typed<1000 || legacy<1000)$display("FAIL layer side coverage");
  else $display("PASS layer side S1");
  $finish;
 end
endmodule
