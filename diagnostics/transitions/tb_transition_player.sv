`timescale 1ns/1ps
module tb_transition_player;
 reg clk=0,pix_clk=0,rst=1;always #5 clk=~clk;always #20 pix_clk=~pix_clk;
 reg next_event=0,previous_event=0,auto_toggle_event=0;
 wire auto_play_en,next_pending,previous_pending,auto_tick,load_request;
 wire next_load_request,previous_load_request,auto_load_request;
 wire [1:0] target_image;
 reg [1:0] current_image=0,held_target;
 reg display_request=0,commit_done=0;
 wire transition_busy,transition_active,permit_commit;wire [4:0] transition_level;
 wire request_accept=load_request && !transition_busy && !display_request;
 media_player_control #(.AUTO_PLAY_CYCLES(100)) player(.clk(clk),.rst(rst),
 .enable(1'b1),.scan_done(1'b1),.display_valid(1'b1),.load_busy(transition_busy || display_request),
 .first_image_committed(1'b1),.manual_activity(1'b0),.request_accept(request_accept),
 .image_count(3'd4),.current_image(current_image),.mode(2'd0),
 .next_event(next_event),.previous_event(previous_event),.auto_toggle_event(auto_toggle_event),
 .auto_play_en(auto_play_en),.next_pending(next_pending),.previous_pending(previous_pending),
 .auto_tick(auto_tick),.load_request(load_request),.next_load_request(next_load_request),
 .previous_load_request(previous_load_request),.auto_load_request(auto_load_request),.target_image(target_image));
 reg [4:0] frame_div=0;wire frame_start=frame_div==15;
 always @(posedge pix_clk) if(rst)frame_div<=0;else frame_div<=frame_div==15?0:frame_div+1;
 video_transition_sd_control fade(.clk(clk),.rst(rst),.pix_clk(pix_clk),.pix_rst(rst),
 .display_request(display_request),.display_valid(1'b1),.frame_start(frame_start),.commit_done(commit_done),
 .transition_busy(transition_busy),.transition_active(transition_active),.transition_level(transition_level),.permit_commit(permit_commit));
 integer accepted=0,commits=0;reg [1:0] targets[0:15];
 always @(posedge clk) if(!rst && request_accept) begin
  if(transition_busy)$fatal(1,"accepted during fade");
  targets[accepted]=target_image;accepted=accepted+1;held_target<=target_image;display_request<=1;
 end
 // Model only the reader's frame-boundary ack; the full-system test uses real SDRAM.
 reg committed=0;
 always @(posedge pix_clk) begin
  commit_done<=0;
  if(!rst && frame_start && display_request && permit_commit && !committed) begin
   if(transition_level!=0)$fatal(1,"commit before black");
   current_image<=held_target;commits=commits+1;commit_done<=1;display_request<=0;committed<=1;
  end
  if(!transition_busy)committed<=0;
 end
 task pulse_next;begin @(negedge clk);next_event=1;@(negedge clk);next_event=0;end endtask
 task pulse_prev;begin @(negedge clk);previous_event=1;@(negedge clk);previous_event=0;end endtask
 initial begin
  repeat(4)@(negedge pix_clk);rst=0;
  pulse_next();wait(transition_busy);pulse_next();pulse_next();pulse_prev();
  wait(commits==3 && !transition_busy);repeat(10)@(negedge clk);
  if(accepted!=3 || targets[0]!=1 || targets[1]!=2 || targets[2]!=1)
   $fatal(1,"busy pending/direction semantics: accepted=%0d",accepted);
  @(negedge clk);auto_toggle_event=1;@(negedge clk);auto_toggle_event=0;
  wait(transition_busy);
  repeat(400) begin @(negedge clk);if(player.auto_count!=0)$fatal(1,"AUTO counted during fade");end
  wait(!transition_busy);repeat(90)@(negedge clk);
  if(accepted!=4)$fatal(1,"AUTO interval not restarted after fade");
  wait(accepted==5);@(negedge clk);auto_toggle_event=1;@(negedge clk);auto_toggle_event=0;
  wait(!transition_busy);
  $display("PASS transition player: pending next/previous, coalesced repeated key, relative target, AUTO full interval; commits=%0d",commits);$finish;
 end
 initial begin #500000;$fatal(1,"player timeout");end
endmodule
