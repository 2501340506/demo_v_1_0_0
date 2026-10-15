`timescale 1ns/1ps
module tb_scene_timing;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,first=0,ready=0,thumbnail=0;reg [1:0] image=0;
 wire [1:0] stage;wire [7:0] t;wire fast,slow,en;
 scene_demo_timing dut(.clk(clk),.rst(rst),.first_active(first),.ready(ready),.thumbnail(thumbnail),
  .image(image),.stage(stage),.t_now(t),.blink_fast(fast),.blink_slow(slow),.layer_enable(en));
 integer frames=0,fast_edges,slow_edges;reg old_fast,old_slow;reg [7:0] hold_t;reg [1:0] hold_stage;
 task frame(input integer expected_t,input integer expected_stage,input integer expected_enable);
  begin
   @(negedge clk);first=1;#1;
   if(t!==8'(expected_t) || stage!==2'(expected_stage) || en!==1'(expected_enable))
    $fatal(1,"first pixel frame=%0d t=%0d want=%0d stage=%0d enable=%0d",frames,t,expected_t,stage,en);
   @(posedge clk);#1;
   @(negedge clk);first=0;#1;hold_t=t;hold_stage=stage;
   if(hold_t!==8'(expected_t) || hold_stage!==2'(expected_stage))$fatal(1,"frame snapshot mismatch");
   repeat(7)begin @(posedge clk);#1;if(t!==hold_t || stage!==hold_stage)$fatal(1,"mid-frame state changed");end
   frames++;
  end
 endtask
 initial begin
  repeat(3)@(negedge clk);rst=0;frame(0,0,0);ready=1;
  for(integer s=0;s<4;s++)begin
   image=2'(s);fast_edges=0;slow_edges=0;
   frame(0,s,1);old_fast=fast;old_slow=slow;
   for(integer f=1;f<=480;f++)begin
    frame((f/2)%240,s,1);
    if(fast!=old_fast)fast_edges++;if(slow!=old_slow)slow_edges++;
    old_fast=fast;old_slow=slow;
   end
   if(fast_edges!=32*(s+1) || slow_edges!=16)$fatal(1,"blink rate stage=%0d fast=%0d slow=%0d",s,fast_edges,slow_edges);
  end
  // Incoming committed image is held until the next first-active boundary.
  image=1;repeat(8)@(negedge clk);if(stage!==3)$fatal(1,"midframe image leak");frame(0,1,1);
  thumbnail=1;frame(0,1,0);thumbnail=0;frame(0,1,1);
  ready=0;frame(0,1,0);ready=1;frame(0,1,1);
  @(negedge clk);rst=1;#1;if(t!==0 || en!==0)$fatal(1,"reset");
  $display("PASS scene timing: frames=%0d two-frame tick wrap stage commit preview ready reset rates=2/4/6/8Hz slow=1Hz",frames);$finish;
 end
endmodule
