`timescale 1ns/1ps
module tb_media_player_control;
 reg clk=0, rst=1, enable=1, scan_done=1, display_valid=1, load_busy=0;
 reg first_image_committed=1, manual_activity=0, request_accept=0;
 reg [2:0] image_count=4;
 reg [1:0] current_image=0;
 reg next_event=0, previous_event=0, auto_toggle_event=0;
 wire auto_play_en, next_pending, previous_pending, auto_tick, load_request;
 wire next_load_request, previous_load_request, auto_load_request;
 wire [1:0] target_image;
 media_player_control #(.AUTO_PLAY_CYCLES(4)) dut(.*);
 always #5 clk=~clk;
 task step; begin @(posedge clk); #1; @(negedge clk); end endtask
 task check(input bit ok, input string msg); if (!ok) $fatal(1,"%s",msg); endtask
 initial begin
  step; check(!auto_play_en && !next_pending && !previous_pending,"reset"); rst=0;
  load_busy=1; next_event=1; previous_event=1; step; next_event=0; previous_event=0;
  step; check(!load_request && next_pending && previous_pending,"busy capture");
  current_image=1; load_busy=0; #1;
  check(next_load_request && target_image==2,"use committed index and next priority");
  step; check(next_pending && target_image==2,"wait for acceptance");
  request_accept=1; next_event=1; step; next_event=0;
  check(next_pending,"same-cycle capture survives");
  step; request_accept=0; current_image=2; #1;
  check(previous_load_request && target_image==1,"previous follows next");
  request_accept=1; step; request_accept=0;
  check(!load_request && !previous_pending,"consumed once");
  image_count=1; current_image=0; previous_event=1; step; previous_event=0;
  check(load_request && target_image==0,"single image wraps to zero");
  request_accept=1; step; request_accept=0; image_count=4;
  auto_toggle_event=1; step; auto_toggle_event=0;
  repeat(2) step;
  check(!auto_load_request,"timer not early"); step;
  check(auto_load_request && target_image==1,"timer expires exactly");
  next_event=1; #1; check(!auto_load_request,"manual wins at expiry");
  step; next_event=0; request_accept=1; step; request_accept=0;
  check(dut.auto_count==0,"manual resets timer");
  repeat(3) step; check(auto_load_request,"auto resumes after full interval");
  request_accept=1; step; request_accept=0; load_busy=1;
  repeat(6) step; check(!load_request && dut.auto_count==0,"no auto while busy");
  enable=0; step; check(!auto_play_en && !next_pending,"disable clears state");
  $display("PASS control handshake, committed index, priority, capture, single image and autoplay");
  $finish;
 end
 initial begin #10000; $fatal(1,"timeout"); end
endmodule
