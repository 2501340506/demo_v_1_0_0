`timescale 1ns/1ps
module tb_scene_fade;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,fade=0,iv=0,ready=1;reg [3:0] level=10;
 wire ir,ov,muted;wire signed [15:0] ol,orr;
 pcm_master_volume dut(.clk(clk),.rst(rst),.volume_level(level),.fade_mute(fade),.muted(muted),
 .in_valid(iv),.in_ready(ir),.in_left(16'sd30000),.in_right(-16'sd30000),
 .out_valid(ov),.out_ready(ready),.out_left(ol),.out_right(orr));
 task step;begin @(posedge clk);#1;end endtask
 integer i,prior,expected,count;
 initial begin
  repeat(3)step();rst=0;iv=1;step();fade=1;prior=65536;count=0;
  while(!muted)begin
   expected=prior>14?prior-14:0;step();count++;
   if(dut.gain!=expected)$fatal(1,"fade out %d %d",dut.gain,expected);
   prior=expected;
   if(count==77)begin ready=0;repeat(20)begin step();if(dut.gain!=prior)$fatal(1,"gain under backpressure");end ready=1;end
  end
  if(count!=4682 || ol!=0 || orr!=0)$fatal(1,"fade duration %d",count);
  fade=0;prior=0;repeat(4682)begin
   expected=prior<65522?prior+14:65536;step();if(dut.gain!=expected)$fatal(1,"fade in %d %d",dut.gain,expected);prior=expected;
  end
  step();level=5;step();if(dut.gain!=65280)$fatal(1,"ordinary volume step");
  fade=1;repeat(100)step();level=7;fade=0;
  prior=dut.gain;step();if(dut.gain!=prior-14)$fatal(1,"interrupted fade");
  $display("PASS M4 fade: 4682 samples each direction, monotonic exact 14, backpressure hold, normal 256, interrupted fade");$finish;
 end
 initial begin #1000000;$fatal(1,"watchdog");end
endmodule
