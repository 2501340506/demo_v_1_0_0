`timescale 1ns/1ps
module tb_m4_player;
 reg wr=0,rd=0;always #5 wr=~wr;always #19 rd=~rd;
 reg rst=1,en=0,v=0,ready=1;reg [7:0] b=0;reg [30:0] total=0;
 reg [15:0] id=0;wire done;wire [15:0] done_id;
 wire fr,sv,active,permit,low,stopped,overrun;wire signed [15:0] l,r;wire [31:0] uf;wire [9:0] level;
 wire ir,ov;wire signed [15:0] ol,orr;reg [3:0] volume=10;
 pcm_stream_player #(.SINGLE_SUPPORT(1),.ADDR_WIDTH(9),.CLOCK_HZ(1000000),.SAMPLE_HZ(48000),.PREFILL(256),.LOW_WATER(128),.HIGH_WATER(384)) dut(
 .wr_clk(wr),.wr_rst_n(!rst),.play_enable(en),.single_play(1'b1),.sample_total(total),.session_id(id),.playback_done(done),.done_session(done_id),
 .file_valid(v),.file_byte(b),.file_ready(fr),.sector_permit(permit),.buffer_low(low),.stopped(stopped),.write_level(level),
 .rd_clk(rd),.rd_rst_n(!rst),.sample_ready(ir),.sample_valid(sv),.sample_left(l),.sample_right(r),.active(active),.underflow_count(uf),.output_overrun(overrun));
 pcm_master_volume vol(.clk(rd),.rst(rst),.volume_level(volume),.fade_mute(1'b0),.muted(),
 .in_valid(sv),.in_ready(ir),.in_left(l),.in_right(r),.out_valid(ov),.out_ready(ready),.out_left(ol),.out_right(orr));
 integer received=0,checked=0,real_outputs=0;reg checking=0,held=0;reg [15:0] held_data;
 function signed [15:0] value(input integer n);value=(n*514)^16'h8140;endfunction
 reg source_queue[0:65535];integer qw=0,qr=0;reg [15:0] expected_queue[0:65535];
 always @(posedge rd)if(!rst)begin
  if(held && (!sv || l!==held_data || r!==held_data))$fatal(1,"stalled PCM changed");
  held=sv && !ir;held_data=l;
  if(checking && sv && ir)begin
   source_queue[qw]=dut.source_tag[dut.rp];expected_queue[qw]=volume==0?0:(value(received)>>>1);
   if(dut.source_tag[dut.rp])begin
    if(received>=total || l!==(value(received)>>>1) || r!==l)$fatal(1,"source sample %d got %d",received,l);
    received++;checked++;
   end else if(l!==0 || r!==0)$fatal(1,"nonzero single-play filler");
   qw++;
  end
  if(checking && ov && ready)begin
   if(qr>=qw)$fatal(1,"volume output without input");
   if(source_queue[qr])begin
    if(ol!==expected_queue[qr] || orr!==ol)$fatal(1,"volume/output tail %d",real_outputs);
    real_outputs++;
   end
   qr++;
  end
 end
 task put(input integer n);reg [15:0] a;
 begin a=value(n);@(negedge wr);while(!fr)@(negedge wr);v=1;b=a[7:0];
 @(negedge wr);while(!fr)@(negedge wr);b=a[15:8];@(negedge wr);v=0;end endtask
 task start_session(input integer n,input integer identity);
 begin wait(stopped);@(negedge wr);total=n;id=identity;received=0;real_outputs=0;qw=0;qr=0;checking=1;en=1;end endtask
 task finish_session;
 begin wait(done);if(received!=total || done_id!=id)$fatal(1,"early/stale done");
 wait(real_outputs==total);repeat(40)@(negedge rd);
 if(!done || received!=total)$fatal(1,"completion not held/single looped");
 @(negedge wr);en=0;wait(stopped);checking=0;if(done)$fatal(1,"old done survived stop");end endtask
 integer i,n;reg [15:0] old_id;
 initial begin
  repeat(5)@(negedge wr);rst=0;
  start_session(1,16'h1101);put(0);finish_session();
  start_session(255,16'h1102);for(i=0;i<255;i++)put(i);finish_session();
  start_session(601,16'h1203);for(i=0;i<601;i++)put(i);finish_session();
  // Hold the final source sample inside the eight-entry output FIFO.
  start_session(19,16'h1304);for(i=0;i<19;i++)put(i);
  wait(received==17);@(negedge rd);ready=0;repeat(300)@(negedge rd);
  if(done || received==total)$fatal(1,"FIFO EOF ignored consumer backpressure");
  @(negedge rd);ready=1;finish_session();
  // Zero gain must still consume the exact final nonzero source sample.
  volume=0;start_session(1,16'h2400);checking=0;put(0);
  wait(done);repeat(13000)@(negedge rd);@(negedge wr);en=0;wait(stopped);
  start_session(33,16'h2405);for(i=0;i<33;i++)put(i);finish_session();
  // Cancellation drains visible data but must never create natural completion.
  start_session(400,16'h1406);for(i=0;i<270;i++)put(i);wait(received>8);
  @(negedge wr);en=0;wait(stopped);checking=0;if(done)$fatal(1,"cancel became EOF");
  start_session(7,16'h2407);for(i=0;i<7;i++)put(i);finish_session();
  $display("PASS M4 player: %0d exact source samples, signed/nonzero tails, short prefill, FIFO backpressure, zero-volume output, cancel and identity reuse",checked);$finish;
 end
 initial begin #50000000;$fatal(1,"M4 player watchdog received=%d total=%d",received,total);end
endmodule
