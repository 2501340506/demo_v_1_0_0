`timescale 1ns/1ps
// Old/new audio_ring_levels: same stimulus, bar_height compared every cycle.
module tb_ring_levels_equiv;
 reg clk=0, rst=1, frame_start=0, pcm_valid=0;
 reg signed [15:0] pcm_left=0, pcm_right=0;
 reg [6:0] bar_index=0;
 wire [4:0] ref_height, new_height;
 integer cycle=0, errors=0, frames=0, restarts=0, resets=0, nonzero=0, gap=0, mode=0;
 always #5 clk=~clk;
 audio_ring_levels_ref ref_dut(.clk(clk),.rst(rst),.frame_start(frame_start),.pcm_valid(pcm_valid),
  .pcm_left(pcm_left),.pcm_right(pcm_right),.bar_index(bar_index),.bar_height(ref_height));
 audio_ring_levels new_dut(.clk(clk),.rst(rst),.frame_start(frame_start),.pcm_valid(pcm_valid),
  .pcm_left(pcm_left),.pcm_right(pcm_right),.bar_index(bar_index),.bar_height(new_height));
 function automatic signed [15:0] sample(input integer m);
  case($urandom%6)
   0: sample=16'sh8000; 1: sample=16'sh7fff; 2: sample=0;
   default: sample=m ? $urandom : ($urandom%4096)-2048;
  endcase
 endfunction
 // Compare after combinational settle on both clock phases.
 always @(negedge clk) begin
  if(ref_height!==new_height) begin
   errors=errors+1;
   if(errors<10) $display("MISMATCH cycle=%0d idx=%0d ref=%0d new=%0d rst=%0b",cycle,bar_index,ref_height,new_height,rst);
  end
  if(ref_height!=0) nonzero=nonzero+1;
 end
 always @(posedge clk) begin
  cycle<=cycle+1;
  #1;
  bar_index=$urandom;
  // Phases: dense audio, sparse audio, silence; frames from very short to normal.
  mode=(cycle/40000)%4;
  pcm_valid = mode==2 ? 0 : mode==1 ? ($urandom%16==0) : ($urandom%3!=0);
  pcm_left=sample(mode); pcm_right=sample(mode);
  if(gap==0) begin
   frame_start=1; frames=frames+1;
   gap = ($urandom%8==0) ? 20+$urandom%80 : 150+$urandom%1500;
   if(gap<100) restarts=restarts+1;
  end else begin frame_start=0; gap=gap-1; end
  if(cycle>1000 && $urandom%60000==0) begin rst=1; resets=resets+1; end
  else if(cycle==20) rst=0;
  else if(rst && cycle>20 && $urandom%4==0) rst=0;
 end
 initial begin
  wait(cycle==400000);
  if(frames<300 || restarts<20 || resets<2 || nonzero<1000) begin
   $display("** Error: insufficient coverage frames=%0d restarts=%0d resets=%0d nonzero=%0d",frames,restarts,resets,nonzero);
   $finish;
  end
  if(errors) $display("** Error: %0d mismatches",errors);
  else $display("PASS ring levels equivalence cycles=%0d frames=%0d mid_copy_restarts=%0d resets=%0d nonzero_reads=%0d",cycle,frames,restarts,resets,nonzero);
  $finish;
 end
endmodule
