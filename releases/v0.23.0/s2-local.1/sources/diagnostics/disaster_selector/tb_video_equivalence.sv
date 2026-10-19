`timescale 1ns/1ps
// All video outputs vs the original resettable 21-clock shift chain.
module tb_video_equivalence;
 reg clk=0,rst=0,hs=0,vs=0,de=0;
 reg [9:0] x=0;
 reg [23:0] data=0;
 always #5 clk=~clk;
 wire [37:0] expected,actual;
 video_delay_ref reference(.video_clk(clk),.rst(rst),.read_data(data),.hs(hs),.vs(vs),.de(de),.video_x(x),
  .read_en(expected[37]),.hs_r(expected[36]),.vs_r(expected[35]),.de_r(expected[34]),
  .vout_data(expected[33:10]),.video_x_r(expected[9:0]));
 video_delay dut(.video_clk(clk),.rst(rst),.read_data(data),.hs(hs),.vs(vs),.de(de),.video_x(x),
  .read_en(actual[37]),.hs_r(actual[36]),.vs_r(actual[35]),.de_r(actual[34]),
  .vout_data(actual[33:10]),.video_x_r(actual[9:0]));
 integer cycle=0,resets=0,nonzero=0;
 initial begin
  #1 rst=1;
  repeat(300000)begin
   @(negedge clk);
   if(actual!==expected)$fatal(1,"video mismatch cycle=%0d expected=%h actual=%h",cycle,expected,actual);
   if(actual[9:0]!=0)nonzero++;
   // Off-edge resets exercise ring priming without clock races.
   #2;
   if(cycle%997==0)begin rst=1;resets++;end
   else if(cycle%997==1)rst=0;
   {hs,vs,de,x}=$urandom;data=$urandom;
   cycle++;
  end
  if(resets<300 || nonzero<200000)$fatal(1,"insufficient coverage");
  $display("PASS video equivalence cycles=%0d async_resets=%0d nonzero_x=%0d",cycle,resets,nonzero);
  $finish;
 end
endmodule
