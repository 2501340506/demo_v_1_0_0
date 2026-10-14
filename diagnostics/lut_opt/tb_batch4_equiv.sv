`timescale 1ns/1ps
// S2 batch4: v0.15.0 vs new hdmi_audio_sample_packetizer; every output every cycle.
module tb_batch4_equiv;
 reg clk=0, rst_n=0;
 always #5 clk=~clk;
 integer cycle=0, errors=0, packets=0, status_packets=0, resets=0;
 reg sample_valid=0, packet_ready=0; reg signed [15:0] left=0, right=0;
 wire r_ready,n_ready,r_valid,n_valid; wire [23:0] r_h,n_h; wire [7:0] r_he,n_he,r_base,n_base;
 wire [223:0] r_b,n_b; wire [31:0] r_be,n_be;
 hdmi_audio_sample_packetizer_v015 ref_pk(.clk(clk),.rst_n(rst_n),.sample_valid(sample_valid),.sample_ready(r_ready),
  .sample_left(left),.sample_right(right),.packet_valid(r_valid),.packet_ready(packet_ready),.packet_header(r_h),
  .packet_header_ecc(r_he),.packet_body(r_b),.packet_body_ecc(r_be),.packet_frame_base(r_base));
 hdmi_audio_sample_packetizer new_pk(.clk(clk),.rst_n(rst_n),.sample_valid(sample_valid),.sample_ready(n_ready),
  .sample_left(left),.sample_right(right),.packet_valid(n_valid),.packet_ready(packet_ready),.packet_header(n_h),
  .packet_header_ecc(n_he),.packet_body(n_b),.packet_body_ecc(n_be),.packet_frame_base(n_base));
 always @(negedge clk) begin
  if({r_ready,r_valid,r_h,r_he,r_b,r_be,r_base}!=={n_ready,n_valid,n_h,n_he,n_b,n_be,n_base}) begin
   errors=errors+1; if(errors<10) $display("MISMATCH cycle=%0d base=%0d",cycle,r_base);
  end
  if(r_valid && packet_ready) begin packets=packets+1; if(r_base==24 || r_base==32) status_packets=status_packets+1; end
 end
 function automatic signed [15:0] pick;
  case($urandom%6) 0: pick=16'sh7fff; 1: pick=-16'sh8000; 2: pick=0; 3: pick=-1; default: pick=$urandom; endcase
 endfunction
 always @(posedge clk) begin
  cycle<=cycle+1;
  #1;
  sample_valid=($urandom%3!=0); left=pick(); right=pick(); packet_ready=($urandom%4!=0);
  if(cycle==5) rst_n=1;
  else if(cycle>100 && $urandom%300000==0) begin rst_n=0; resets=resets+1; end
  else if(!rst_n && cycle>5 && $urandom%3==0) rst_n=1;
 end
 initial begin
  wait(cycle==2000000);
  if(packets<100000 || status_packets<4000 || resets<2) $display("** Error: insufficient coverage packets=%0d status=%0d resets=%0d",packets,status_packets,resets);
  else if(errors) $display("** Error: %0d mismatches",errors);
  else $display("PASS batch4 equivalence cycles=%0d packets=%0d status_packets=%0d resets=%0d",cycle,packets,status_packets,resets);
  $finish;
 end
endmodule
