`timescale 1ns/1ps
module tb_transition_wipe;
 reg clk=0,pix_clk=0,rst=1,pix_rst=1;
 always #5 clk=~clk;always #20 pix_clk=~pix_clk;
 reg display_request=0,display_valid=1,request_wipe=0,frame_start=0,commit_done=0;
 wire transition_busy,transition_active,permit_commit,wipe_active;
 wire [4:0] transition_level;
 video_transition_sd_control dut(.*);
 reg de=1;reg [9:0] pixel_x=0;reg [23:0] rgb_in=24'hfa7e03;wire [23:0] rgb_out;
 video_transition_pixels pixel(.level(transition_level),.*);
 // Exercise all mask boundaries, including zero and full width independently.
 reg [4:0] test_level=0;reg test_wipe=1;wire [23:0] mask_rgb;
 video_transition_pixels mask(.level(test_level),.wipe_active(test_wipe),.de(de),.pixel_x(pixel_x),.rgb_in(rgb_in),.rgb_out(mask_rgb));
 integer checks=0,n,x,t;
 task frame;begin @(negedge pix_clk);frame_start=1;@(negedge pix_clk);frame_start=0;end endtask
 task check_row(input integer level,input integer wipe);
 reg [23:0] expected;
 begin
  if(transition_level!==level || wipe_active!==wipe)$fatal(1,"wrong phase level=%d wipe=%d",transition_level,wipe_active);
  for(integer col=0;col<800;col=col+1)begin
   pixel_x=col;de=col<640;#1;
   expected=wipe?((col<level*40 && de)?rgb_in:24'd0):{8'(250*level/16),8'(126*level/16),8'(3*level/16)};
   if(rgb_out!==expected)$fatal(1,"pixel col=%d level=%d",col,level);
   checks=checks+1;
  end
 end endtask
 initial begin
  repeat(4)@(negedge pix_clk);rst=0;pix_rst=0;
  for(n=0;n<=16;n=n+1)begin
   test_level=n;
   for(x=0;x<800;x=x+1)begin
    pixel_x=x;de=x<640;#1;
    if(mask_rgb!==((de && x<n*40)?rgb_in:24'd0))$fatal(1,"mask boundary level=%d x=%d",n,x);
    checks=checks+1;
   end
  end
  // AUTO, manual, AUTO: held source survives later input changes.
  for(t=0;t<3;t=t+1)begin
   @(negedge clk);request_wipe=t!=1;display_request=1;
   wait(transition_busy);@(negedge clk);request_wipe=~request_wipe;
   repeat(8)@(negedge pix_clk);check_row(16,0);
   for(n=15;n>=0;n=n-1)begin frame;check_row(n,0);end
   wait(permit_commit);frame;check_row(0,0);
   display_request=0;@(negedge pix_clk);commit_done=1;@(negedge pix_clk);commit_done=0;
   for(n=1;n<=16;n=n+1)begin frame;check_row(n,(n<16 && t!=1));end
   wait(!transition_busy);repeat(8)@(negedge clk);
  end
  $display("PASS S2 wipe: AUTO/manual/AUTO, held source, boundaries 0..640, %0d pixel checks",checks);$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
