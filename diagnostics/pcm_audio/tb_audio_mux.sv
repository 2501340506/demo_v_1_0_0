`timescale 1ns/1ps
module tb_audio_mux;
 reg clk=0;always #5 clk=~clk;reg rst=1,wv=1,av=1,wa=0,ready=0;
 reg signed [15:0] wl=123,wr=-123,al=456,ar=-456;
 wire wready,aready,valid;wire signed [15:0] l,r;
 audio_source_mux dut(.clk(clk),.rst_n(!rst),.wav_valid(wv),.wav_ready(wready),.wav_left(wl),.wav_right(wr),.wav_active(wa),
 .arp_valid(av),.arp_ready(aready),.arp_left(al),.arp_right(ar),.out_ready(ready),.out_valid(valid),.out_left(l),.out_right(r));
 initial begin
  repeat(3)@(negedge clk);rst=0;
  @(negedge clk);wa=1;repeat(4)@(negedge clk);
  if(!valid || l!=456 || r!=-456 || wready || aready)$fatal(1,"tone stall selection changed");
  ready=1;@(negedge clk);
  if(l!=123 || r!=-123 || !aready || !wready)$fatal(1,"music selection/drain");
  ready=0;@(negedge clk);wa=0;repeat(4)@(negedge clk);
  if(l!=123 || r!=-123 || !valid || !aready || wready)$fatal(1,"music stall selection changed");
  ready=1;@(negedge clk);
  if(l!=456 || r!=-456 || wready || !aready)$fatal(1,"fallback");
  rst=1;#1;if(valid || wready || aready)$fatal(1,"reset outputs");
  $display("PASS audio mux: stalled tone/music boundaries, unselected tone drain, fallback, reset");$finish;
 end
endmodule
