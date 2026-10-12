`timescale 1ns/1ps
module tb_audio_ring;
 reg clk=0,rst=1,frame=0,valid=0;
 always #5 clk=~clk;
 reg signed [15:0] l=0,r=0;
 reg [6:0] index=0;
 wire [4:0] height;
 audio_ring_levels levels(clk,rst,frame,valid,l,r,index,height);
 task sample(input integer a,input integer b);
  begin @(negedge clk);valid=1;l=a;r=b;@(negedge clk);valid=0;end
 endtask
 task group_samples(input integer a,input integer b);
  integer n;begin for(n=0;n<32;n=n+1)sample(a,b);end
 endtask
 task snapshot;
  begin @(negedge clk);frame=1;@(negedge clk);frame=0;repeat(100)@(negedge clk);end
 endtask
 task check_all(input integer expected);
  integer n;begin for(n=0;n<96;n=n+1)begin index=n;#1;if(height!==expected)$fatal(1,"height[%0d]=%0d expected %0d",n,height,expected);end end
 endtask
 integer n,k;
 initial begin
  repeat(3)@(negedge clk);rst=0;
  // Invalid bus changes must not enter the history.
  l=32767;r=-32768;repeat(80)@(negedge clk);snapshot();check_all(0);
  for(n=0;n<96;n=n+1)group_samples(0,-32768);
  snapshot();check_all(28);
  // Display must remain fixed until the next frame.
  for(n=0;n<96;n=n+1)group_samples(2048,-1024);
  check_all(28);snapshot();check_all(25);
  for(k=22;k>=4;k=k-3)begin sample(2048,0);snapshot();check_all(k);end
  // Full silence refreshes all history, then releases to zero.
  for(n=0;n<97;n=n+1)group_samples(0,0);
  snapshot();check_all(1);snapshot();check_all(0);
  // Reinitialize, known chronological ramp and ring wrap.
  @(negedge clk);rst=1;@(negedge clk);rst=0;
  for(n=0;n<160;n=n+1)group_samples((n%29)*512,0);
  snapshot();
  for(n=0;n<96;n=n+1)begin index=n;#1;if(height!==(n+64)%29)$fatal(1,"history order %0d height %0d",n,height);end
  snapshot();
  for(n=0;n<96;n=n+1)begin index=n;#1;if(height!==(((n+64)%29>3)?(n+64)%29-3:0))$fatal(1,"missing sample release");end
  $display("PASS levels: handshake, signed peak, saturation, attack/release, silence, wrap, frame stability");
  $finish;
 end
 initial begin #5000000;$fatal(1,"timeout");end
endmodule
