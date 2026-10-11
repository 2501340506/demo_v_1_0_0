`timescale 1ns/1ps
module tb_transition_s1;
 reg clk=0,pix_clk=0,rst=1,pix_rst=1,display_request=0,display_valid=1;
 reg frame_start=0,commit_done=0;
 wire transition_busy,transition_active,permit_commit;
 wire [4:0] transition_level; reg [23:0] rgb_in;wire [23:0] rgb_out;
 always #5 clk=~clk;
 always #20 pix_clk=~pix_clk;
 video_transition_sd_control dut(.*);
 video_transition_pixels pixel(.level(transition_level),.rgb_in(rgb_in),.rgb_out(rgb_out));
 wire off_busy,off_active,off_permit;wire [4:0] off_level;
 video_transition_sd_control #(.ENABLE(0)) bypass(.clk(clk),.rst(rst),
 .pix_clk(pix_clk),.pix_rst(pix_rst),.display_request(display_request),.display_valid(display_valid),
 .frame_start(frame_start),.commit_done(commit_done),.transition_busy(off_busy),
 .transition_active(off_active),.transition_level(off_level),.permit_commit(off_permit));
 integer checked=0;
 task check_pixels(input integer level);
 integer c;reg [23:0] expected;
 begin
  if(transition_level!==level) $fatal(1,"level got %d expected %d",transition_level,level);
  for(c=0;c<256;c=c+1) begin
   rgb_in={8'(c),8'(255-c),8'(c^85)};#1;
   expected={8'((c*level)>>4),8'(((255-c)*level)>>4),8'(((c^85)*level)>>4)};
   if(rgb_out!==expected) $fatal(1,"RGB %h expected %h level=%d",rgb_out,expected,level);
   checked=checked+1;
  end
 end endtask
 task frame;
 begin @(negedge pix_clk);frame_start=1;@(negedge pix_clk);frame_start=0;end endtask
 task transition(input integer black_frames);
 integer n;
 begin
  @(negedge clk);display_request=1;
  repeat(8) @(negedge pix_clk);
  if(!transition_busy) $fatal(1,"missing local busy");
  check_pixels(16);
  for(n=15;n>=0;n=n-1) begin
   if(permit_commit) $fatal(1,"permit before black");
   frame;check_pixels(n);
  end
  repeat(8) @(negedge clk);
  if(!permit_commit) $fatal(1,"missing black permit");
  repeat(black_frames) begin frame;check_pixels(0);end
  // The source keeps the cache request through the actual reader commit.
  @(negedge clk);display_request=0;
  @(negedge pix_clk);commit_done=1;@(negedge pix_clk);commit_done=0;
  check_pixels(0);
  for(n=1;n<=16;n=n+1) begin frame;check_pixels(n);end
  repeat(8) @(negedge clk);
  if(transition_busy || permit_commit) $fatal(1,"transaction did not finish");
 end endtask
 reg [4:0] old_level=16;reg old_frame=0;
 always @(posedge pix_clk) begin
  #1;
  if(!pix_rst && transition_level!=old_level && !frame_start) $fatal(1,"mid-frame brightness change");
  old_level=transition_level;
  if(off_level!==16 || off_busy || off_active || !off_permit) $fatal(1,"bypass behavior");
 end
 initial begin
  rgb_in=0;repeat(4) @(negedge pix_clk);rst=0;pix_rst=0;
  // First-image/rescan bypass must not start a transition.
  display_valid=0;display_request=1;repeat(8) @(negedge pix_clk);
  if(transition_busy || transition_level!=16) $fatal(1,"first image faded");
  display_request=0;display_valid=1;
  transition(3);transition(1);
  // Reset an active transaction, then prove the toggles work again.
  display_request=1;repeat(8) @(negedge pix_clk);frame;
  rst=1;pix_rst=1;display_request=0;repeat(4) @(negedge pix_clk);
  rst=0;pix_rst=0;transition(2);
  $display("PASS transition S1: 3 async transactions, delayed commit, reset, bypass, %0d RGB checks",checked);$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
