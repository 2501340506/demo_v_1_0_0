`timescale 1ns/1ps
module tb_pcm_stream_player;
 reg wr=0,rd=0;always #5 wr=~wr;always #19 rd=~rd;
 reg rst=1,en=0,v=0,ready=1;reg [7:0] b=0;
 wire fr,sv,active,permit,low,stopped,overrun;wire signed [15:0] l,r;wire [31:0] uf;wire [9:0] level;
 pcm_stream_player #(.ADDR_WIDTH(9),.CLOCK_HZ(1000000),.SAMPLE_HZ(48000),.PREFILL(256),.LOW_WATER(128),.HIGH_WATER(384)) dut(
 .wr_clk(wr),.wr_rst_n(!rst),.play_enable(en),.file_valid(v),.file_byte(b),.file_ready(fr),
 .sector_permit(permit),.buffer_low(low),.stopped(stopped),.write_level(level),
 .rd_clk(rd),.rd_rst_n(!rst),.sample_ready(ready),.sample_valid(sv),.sample_left(l),.sample_right(r),
 .active(active),.underflow_count(uf),.output_overrun(overrun));
 reg signed [15:0] expected[0:20000];integer sent=0,received=0,silence=0;
 reg check_samples=1,held=0;reg signed [15:0] held_data;
 integer clocks=0,ticks=0;reg count_rate=0;
 always @(posedge rd)if(!rst)begin
  if(held && (!sv || l!==held_data || r!==held_data))$fatal(1,"stalled sample changed");
  held=sv && !ready;held_data=l;
  if(sv && ready && check_samples)begin
   if(received<sent)begin
    if(l!==expected[received] || r!==expected[received])$fatal(1,"sample %0d got %0d expected %0d",received,l,expected[received]);
    received++;
   end else begin
    if(l!==0 || r!==0)$fatal(1,"nonzero underflow");silence++;
   end
  end
  if(count_rate)begin clocks++;if(dut.tick)ticks++;end
 end
 task put(input integer value);
 reg signed [15:0] s;
 begin
  s=value;
  @(negedge wr);while(!fr)@(negedge wr);v=1;b=s[7:0];
  @(negedge wr);while(!fr)@(negedge wr);b=s[15:8];
  expected[sent]=s>>>1;sent++;
  @(negedge wr);v=0;
 end endtask
 integer i,old_received;reg signed [15:0] hold_value;
 initial begin
  repeat(5)@(negedge wr);rst=0;wait(stopped);@(negedge wr);en=1;
  for(i=0;i<255;i++)put((i*514)^16'h8000);
  repeat(100)@(negedge rd);if(active || sv)$fatal(1,"started before prefill");
  put(16'h7fff);wait(active);
  // More than nine complete pointer wraps; every signed sample is checked.
  for(i=256;i<5000;i++)put((i*514)^16'h8000);
  wait(received==sent);repeat(80)@(negedge rd);
  if(uf==0 || silence==0 || overrun)$fatal(1,"underflow/normal queue status");
  count_rate=1;repeat(100000)@(negedge rd);count_rate=0;
  if(ticks<4799 || ticks>4801)$fatal(1,"rate clocks=%0d ticks=%0d",clocks,ticks);
  // Stop while downstream stalls: preserve presented sample, then clear.
  @(negedge rd);ready=0;check_samples=0;
  for(i=0;i<20;i++)put(i+1200);
  repeat(200)@(negedge rd);if(!overrun)$fatal(1,"backpressure not exercised");
  @(negedge wr);en=0;repeat(30)@(negedge rd);
  if(stopped)$fatal(1,"stop acknowledged before output drained");
  @(negedge rd);ready=1;wait(stopped);
  if(active || level!=0)$fatal(1,"stop left old pointers");
  sent=0;received=0;check_samples=1;
  @(negedge wr);en=1;
  for(i=0;i<300;i++)put(10000+i*2);
  wait(received==300);
  @(negedge wr);en=0;wait(stopped);
  // Immediate stop before reader acknowledgement cannot reset just one side.
  @(negedge wr);en=1;repeat(5)@(negedge wr);en=0;wait(stopped);
  $display("PASS PCM player: 5300 exact signed samples, pointer wraps, prefill, underflow, 4800 ticks/100000 clocks, stalled stop/restart");$finish;
 end
 initial begin #30000000;$fatal(1,"player watchdog sent=%0d received=%0d",sent,received);end
endmodule
