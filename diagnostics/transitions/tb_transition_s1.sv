`timescale 1ns/1ps
module tb_transition_s1;
 reg clk=0,rst=1,request=0,request_ready=1,commit_done=0,frame_start=0;
 wire busy,permit_commit,active; wire [4:0] level;
 video_transition_control #(.FADE_FRAMES(4)) dut(.*);
 always #5 clk=~clk;
 task frame; begin @(negedge clk); frame_start=1; @(negedge clk); frame_start=0; end endtask
 initial begin
   repeat(2) @(negedge clk); rst=0;
   @(negedge clk); request=1; @(negedge clk); request=0;
   if (!busy || level !== 5'd4) $fatal(1,"fade did not start");
   frame; if(level!==5'd3) $fatal(1,"fade step 1");
   frame; frame; frame; frame;
   if (!permit_commit || level!==5'd0) $fatal(1,"black permit missing");
   @(negedge clk); commit_done=1; @(negedge clk); commit_done=0;
   frame; frame; frame; frame;
   if (busy) $fatal(1,"fade did not finish");
   $display("S1 transition control PASS"); $finish;
 end
endmodule
