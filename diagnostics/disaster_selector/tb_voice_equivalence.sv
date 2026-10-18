`timescale 1ns/1ps
module tb_voice_equivalence;
 reg clk=0,rst=1;
 always #5 clk=~clk;
 reg [15:0] control=0;
 reg [1:0] commit_page=0;
 reg [7:0] stream_error=0;
 reg [15:0] session_id=0,done_id=0;
 wire [10:0] result[0:3],reference[0:3];
 integer offered[0:3];
 genvar g;
 generate for(g=0;g<4;g=g+1)begin:pair
  publicity_voice_control #(.MENU_ENABLE(g%2),.MIN_FRAMES(g<2?3:300)) dut(
   .clk(clk),.rst(rst),.pause(control[0]),.restart(control[1]),.enable(control[2]),.commit(control[3]),
   .commit_page(commit_page),.page_pending(control[4]),.busy(control[5]),.ui_play(control[6]),
   .frame_tick(control[7]),.toggle_auto(control[8]),.manual(control[9]),.offer_ready(control[10]),
   .audio_ready(control[11]),.selected_publicity(control[12]),.selected_found(control[13]),
   .stream_error(stream_error),.session_id(session_id),.done_id(done_id),.done(control[14]),
   .voice_request(result[g][0]),.page(result[g][2:1]),.fade(result[g][3]),.auto_enable(result[g][4]),
   .auto_offer(result[g][5]),.auto_accept(result[g][6]),.status(result[g][9:7]));
  publicity_voice_control_reference #(.MENU_ENABLE(g%2),.MIN_FRAMES(g<2?3:300)) ref_dut(
   .clk(clk),.rst(rst),.pause(control[0]),.restart(control[1]),.enable(control[2]),.commit(control[3]),
   .commit_page(commit_page),.page_pending(control[4]),.busy(control[5]),.ui_play(control[6]),
   .frame_tick(control[7]),.toggle_auto(control[8]),.manual(control[9]),.offer_ready(control[10]),
   .audio_ready(control[11]),.selected_publicity(control[12]),.selected_found(control[13]),
   .stream_error(stream_error),.session_id(session_id),.done_id(done_id),.done(control[14]),
   .voice_request(reference[g][0]),.page(reference[g][2:1]),.fade(reference[g][3]),.auto_enable(reference[g][4]),
   .auto_offer(reference[g][5]),.auto_accept(reference[g][6]),.status(reference[g][9:7]));
  always @(negedge clk)begin
   if({result[g],dut.state,dut.identity,dut.dwell,dut.tail_frames,dut.advanced} !==
      {reference[g],ref_dut.state,ref_dut.identity,ref_dut.dwell,ref_dut.tail_frames,ref_dut.advanced})
     $fatal(1,"Voice equivalence mismatch config=%0d cycle=%0d result=%h ref=%h",g,n,result[g],reference[g]);
   if(result[g][5])offered[g]=offered[g]+1;
  end
 end endgenerate
 integer n,j;
 initial begin
  for(j=0;j<4;j=j+1)offered[j]=0;
  repeat(3)@(negedge clk);#1;rst=0;
  for(n=0;n<200000;n=n+1)begin
   @(negedge clk);#1;
   control=$urandom;commit_page=$urandom;stream_error=$urandom;session_id=$urandom;done_id=$urandom;
   // Long no-audio sessions reach both dwell thresholds; hold ready low
   // to exercise offer gating and subsequent acceptance at the boundary.
   if(n%2048<510)begin
    control=16'h00c4;session_id=16'd37;done_id=37;stream_error=0;
    if(n%2048==0)control[3]=1;
    if(n%2048==2)control[8]=1;
    if(n%2048>=4)control[11]=1;
    if(n%2048==505)control[10]=1;
   end
   rst=n%10007==10006;
  end
  @(negedge clk);
  for(j=0;j<4;j=j+1)if(offered[j]==0)$fatal(1,"Offer never exercised config=%0d",j);
  $display("PASS voice equivalence: 200000 cycles x 4 configurations, all outputs/internal state, dwell 3/300, MENU 0/1, offer acceptance and async reset");
  $finish;
 end
endmodule
