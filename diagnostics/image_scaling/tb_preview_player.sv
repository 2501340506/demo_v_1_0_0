`timescale 1ns/1ps
module tb_preview_player;
 reg clk=0,rst=1;always #5 clk=~clk;
 reg [1:0] mode=0;reg toggle=0,next_key=0;
 wire auto_en,load_request;wire [1:0] target;
 media_player_control #(.AUTO_PLAY_CYCLES(12)) dut(
 .clk(clk),.rst(rst),.enable(1'b1),.scan_done(1'b1),.display_valid(1'b1),.load_busy(1'b0),
 .first_image_committed(1'b1),.manual_activity(1'b0),.request_accept(load_request),
 .image_count(3'd4),.current_image(2'd2),.mode(mode),.next_event(next_key),.previous_event(1'b0),
 .auto_toggle_event(toggle),.auto_play_en(auto_en),.next_pending(),.previous_pending(),.auto_tick(),
 .load_request(load_request),.next_load_request(),.previous_load_request(),.auto_load_request(),.target_image(target));
 initial begin
  repeat(3)@(negedge clk);rst=0;toggle=1;@(negedge clk);toggle=0;
  if(!auto_en)$fatal(1,"AUTO did not start");
  mode=3;repeat(30)@(negedge clk);
  if(auto_en || load_request)$fatal(1,"AUTO survived mode 11");
  next_key=1;@(negedge clk);next_key=0;
  if(!load_request || target!=3)$fatal(1,"11 fullscreen manual selection");
  repeat(3)@(negedge clk);mode=0;repeat(30)@(negedge clk);
  if(auto_en || load_request)$fatal(1,"return to 00 restarted AUTO");
  $display("PASS preview player: AUTO exit, 11 fullscreen manual request, return to MAN");$finish;
 end
endmodule
