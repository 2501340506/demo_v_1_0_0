`timescale 1ns/1ps
// Compare the registered metadata summary against the original availability
// check. File metadata is stable for a selected resource, as in the scanner.
module tb_audio_control_equivalence;
 reg clk=0,rst=1;always #5 clk=~clk;
 reg request=0,request_scene=0,request_publicity=0,stopped=0,sample_tick=0,session_enable=0;
 reg [1:0] request_stage=0;
 reg [7:0] stream_error=0;
 reg [15:0] files=0;
 wire [13:0] result[0:3];
 wire found[0:3];
 integer n,j,accepted=0,missing=0,available=0;
 genvar g;
 generate for(g=0;g<4;g=g+1)begin:pair
  assign found[g]=files[{result[g][0],result[g][9],result[g][11:10]}];
  scenario_audio_control #(.PUBLICITY_ENABLE(g/2),.PIPELINED_FOUND(g%2)) dut(
   .clk(clk),.rst(rst),.request(request),.request_scene(request_scene),.request_stage(request_stage),
   .request_publicity(request_publicity),.selected_publicity(result[g][0]),.session_version(result[g][8:1]),
   .stopped(stopped),.sample_tick(sample_tick),.session_enable(session_enable),.stream_error(stream_error),
   .selected_found(found[g]),.run_enable(result[g][12]),.selected_scene(result[g][9]),
   .selected_stage(result[g][11:10]),.ready(result[g][13]));
 end endgenerate
 always @(negedge clk)begin
  if(result[0]!==result[1] || result[2]!==result[3])
   $fatal(1,"audio control summary mismatch cycle=%0d",n);
  if(!rst && pair[3].dut.state==2 && pair[3].dut.guard==7)begin
   accepted++;if(found[3])available++;else missing++;
  end
 end
 initial begin
  repeat(3)@(negedge clk);#1;rst=0;
  for(n=0;n<80000;n++)begin
   @(negedge clk);#1;
   // New tables become visible between drained sessions, never halfway
   // through the eight-cycle START guard.
   if(n%64==0)begin files=$urandom;request=0;end
   if(n%64==4)begin request=1;request_scene=$urandom;request_publicity=$urandom;request_stage=$urandom;end
   if(n%64==48)request=0;
   stopped=n%64>=8;sample_tick=n%5==0;session_enable=n%64>=10;
   stream_error=n%211==210?8'h11:0;
   rst=n%4096==4095;
  end
  @(negedge clk);
  if(accepted<1000 || missing<400 || available<400)$fatal(1,"audio control coverage %d/%d/%d",accepted,missing,available);
  $display("PASS audio control equivalence: 80000 cycles, PUBLICITY 0/1, %0d selections (%0d missing/%0d available), stop/start guard, samples/errors/reset",accepted,missing,available);
  $finish;
 end
endmodule
