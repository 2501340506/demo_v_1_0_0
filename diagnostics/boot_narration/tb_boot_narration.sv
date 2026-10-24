`timescale 1ns/1ps
// v0.31 S1: first narration request waits for BOOT_FRAMES HDMI frames after
// reset; later commits and an early-committed first page are unaffected.
module tb_boot_narration;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,en=0,commit=0,busy=0,frame=0,ar=0;
 reg [1:0] cp=0;reg [15:0] id=16'h0101;
 wire request,fade,auto_en,offer,accept;wire [1:0] page;wire [2:0] status;
 publicity_voice_control #(.BOOT_FRAMES(240)) dut(.pause(1'b0),.restart(1'b0),.clk(clk),.rst(rst),.enable(en),.commit(commit),.commit_page(cp),
  .page_pending(1'b0),.busy(busy),.ui_play(1'b1),.frame_tick(frame),.toggle_auto(1'b0),.manual(1'b0),.offer_ready(1'b1),
  .audio_ready(ar),.selected_publicity(1'b1),.selected_found(1'b1),.stream_error(8'd0),.session_id(id),.done(1'b0),.done_id(16'd0),
  .voice_request(request),.page(page),.fade(fade),.auto_enable(auto_en),.auto_offer(offer),.auto_accept(accept),.status(status));
 task cyc(input integer n);repeat(n)@(negedge clk);endtask
 task tick;begin frame=1;cyc(1);frame=0;cyc(1);end endtask
 task frames(input integer n);repeat(n)tick();endtask
 task do_commit(input integer p);begin cp=p;commit=1;cyc(1);commit=0;cyc(2);end endtask
 task ack;begin id++;ar=1;cyc(1);ar=0;cyc(2);end endtask
 integer f;
 task boot(input integer pre);begin rst=1;en=0;cyc(4);rst=0;en=1;frames(pre);end endtask
 initial begin
  // Case 1: first page commits early (about frame 56, ~0.94 s), voice waits to frame 240.
  boot(56);do_commit(0);
  for(f=56;f<239;f++)begin tick();if(request)$fatal(1,"request before boot frames at %0d",f);end
  tick();cyc(2);if(!request)$fatal(1,"no request at boot frame 240");ack();if(status!=2)$fatal(1,"not RUN");
  // Later commit after boot: immediate request.
  do_commit(1);if(!request)$fatal(1,"later commit delayed");ack();
  // Case 2: first commit after boot window: immediate.
  boot(260);do_commit(2);if(!request)$fatal(1,"late first commit delayed");ack();
  // Case 3: busy (BIN loading) longer than boot window still dominates.
  boot(10);busy=1;do_commit(0);frames(260);if(request)$fatal(1,"busy ignored");busy=0;cyc(2);if(!request)$fatal(1,"no request after busy");ack();
  // Case 4: mode exit/re-entry after boot is not delayed again.
  en=0;cyc(2);en=1;do_commit(3);if(!request)$fatal(1,"re-entry delayed");ack();
  $display("PASS boot narration: early first page waits to frame 240, late first page/later commits/re-entry immediate, busy still gates");$finish;
 end
 initial begin #50000000;$fatal(1,"watchdog");end
endmodule
