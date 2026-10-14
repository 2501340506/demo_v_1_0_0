`timescale 1ns/1ps
// S2 batch5: v0.15.0-structured vs new hdmi_audio_symbol_core on a 800x525 raster with
// audio, ACR (shortened interval) and InfoFrame packets; all outputs every cycle.
module tb_batch5_equiv;
 reg clk=0, rst_n=0;
 always #20 clk=~clk;
 integer cycle=0, errors=0, frames=0, resets=0, audio_islands=0, acr_islands=0, info_islands=0;
 reg [9:0] x=0, y=0; reg [23:0] rgb=0; reg sample_valid=0; reg signed [15:0] left=0, right=0;
 wire hs = !(x>=656 && x<752), vs = !(y>=490 && y<492), de = (x<640 && y<480);
 wire r_ready,n_ready,r_err,n_err; wire [9:0] r0,r1,r2,n0,n1,n2;
 hdmi_audio_symbol_core_v015 #(.ACR_INTERVAL_CYCLES(3000)) ref_core(.pixel_clk(clk),.rst_n(rst_n),.video_hsync(hs),.video_vsync(vs),
  .video_de(de),.video_x(x),.video_rgb(de?rgb:24'd0),.sample_valid(sample_valid),.sample_ready(r_ready),.sample_left(left),.sample_right(right),
  .channel0_symbol(r0),.channel1_symbol(r1),.channel2_symbol(r2),.sequence_error(r_err));
 hdmi_audio_symbol_core #(.ACR_INTERVAL_CYCLES(3000)) new_core(.pixel_clk(clk),.rst_n(rst_n),.video_hsync(hs),.video_vsync(vs),
  .video_de(de),.video_x(x),.video_rgb(de?rgb:24'd0),.sample_valid(sample_valid),.sample_ready(n_ready),.sample_left(left),.sample_right(right),
  .channel0_symbol(n0),.channel1_symbol(n1),.channel2_symbol(n2),.sequence_error(n_err));
 always @(negedge clk) begin
  if({r_ready,r_err,r0,r1,r2}!=={n_ready,n_err,n0,n1,n2}) begin
   errors=errors+1; if(errors<10) $display("MISMATCH cycle=%0d x=%0d y=%0d",cycle,x,y);
  end
  if(rst_n && ref_core.packet_claim) case(new_core.packet_source)
   2'd0: acr_islands=acr_islands+1; 2'd1: info_islands=info_islands+1; default: audio_islands=audio_islands+1; endcase
 end
 always @(posedge clk) begin
  cycle<=cycle+1;
  #1;
  if(x==799) begin x=0; if(y==524) begin y=0; frames=frames+1; end else y=y+1; end else x=x+1;
  rgb=($urandom%4==0) ? {3{8'($urandom%2 ? 8'hff : 8'h00)}} : $urandom;
  if(sample_valid && r_ready) sample_valid=0;
  if(!sample_valid && $urandom%300==0) begin sample_valid=1; left=$urandom; right=$urandom; end
  if(cycle==5) rst_n=1;
  else if(cycle>1000 && $urandom%600000==0) begin rst_n=0; resets=resets+1; end
  else if(!rst_n && cycle>5 && $urandom%3==0) rst_n=1;
 end
 initial begin
  wait(frames==5);
  $display("coverage audio=%0d acr=%0d info=%0d resets=%0d",audio_islands,acr_islands,info_islands,resets);
  if(audio_islands<1000 || acr_islands<300 || info_islands<3 || resets<1) $display("** Error: insufficient coverage");
  else if(errors) $display("** Error: %0d mismatches",errors);
  else $display("PASS batch5 equivalence cycles=%0d frames=%0d",cycle,frames);
  $finish;
 end
endmodule
