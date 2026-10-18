`timescale 1ns/1ps
module tb_application_equivalence;
 reg clk=0,rst=1;
 always #5 clk=~clk;
 reg [21:0] stimulus=0;
 wire [1:0] app[0:1],target[0:1],ref_app[0:1],ref_target[0:1];
 wire [8:0] outputs[0:1],reference[0:1];
 reg [9:0] visited[0:1];
 genvar g;
 generate for(g=0;g<2;g=g+1)begin:pair
  publicity_app_control #(.MENU_ENABLE(g)) dut(
   .clk(clk),.rst(rst),.force_target(2'd2),.initial_display(),.force_request(stimulus[0]),.toggle_request(stimulus[1]),
   .retry_request(stimulus[2]),.rescan_request(stimulus[3]),
   .pic_complete(stimulus[4]),.pic_any(stimulus[5]),.edu_complete(stimulus[6]),
   .scan_valid(stimulus[7]),.scan_success(stimulus[8]),.scan_application(stimulus[10:9]),
   .idle(stimulus[11]),.black(stimulus[12]),.muted(stimulus[13]),
   .audio_stopped(stimulus[14]),.committed(stimulus[15]),.failed(stimulus[16]),
   .scene_ready(stimulus[17]),.frame_tick(stimulus[18]),.fade_busy(stimulus[19]),
   .app(app[g]),.target(target[g]),.busy(outputs[g][0]),.error(outputs[g][1]),
   .rejected(outputs[g][2]),.physical(outputs[g][3]),.reload(outputs[g][4]),
   .stop_audio(outputs[g][5]),.scene_enable(outputs[g][6]),
   .fade_request(outputs[g][7]),.release_fade(outputs[g][8]));
  publicity_app_control_reference #(.MENU_ENABLE(g)) ref_dut(
   .clk(clk),.rst(rst),.force_request(stimulus[0]),.toggle_request(stimulus[1]),
   .retry_request(stimulus[2]),.rescan_request(stimulus[3]),
   .pic_complete(stimulus[4]),.pic_any(stimulus[5]),.edu_complete(stimulus[6]),
   .scan_valid(stimulus[7]),.scan_success(stimulus[8]),.scan_application(stimulus[10:9]),
   .idle(stimulus[11]),.black(stimulus[12]),.muted(stimulus[13]),
   .audio_stopped(stimulus[14]),.committed(stimulus[15]),.failed(stimulus[16]),
   .scene_ready(stimulus[17]),.frame_tick(stimulus[18]),.fade_busy(stimulus[19]),
   .app(ref_app[g]),.target(ref_target[g]),.busy(reference[g][0]),.error(reference[g][1]),
   .rejected(reference[g][2]),.physical(reference[g][3]),.reload(reference[g][4]),
   .stop_audio(reference[g][5]),.scene_enable(reference[g][6]),
   .fade_request(reference[g][7]),.release_fade(reference[g][8]));
  always @(negedge clk)begin
   if({app[g],target[g],outputs[g],dut.state,dut.settle} !==
      {ref_app[g],ref_target[g],reference[g],ref_dut.state,ref_dut.settle})
    $fatal(1,"Application equivalence mismatch menu=%0d",g);
   visited[g][dut.state]=1;
  end
 end endgenerate
 integer n;
 initial begin
  visited[0]=0;visited[1]=0;
  repeat(3)@(negedge clk);
  #1;rst=0;
  for(n=0;n<200000;n=n+1)begin
   @(negedge clk);#1;stimulus=$urandom;
   // Exercise asynchronous reset alongside normal transactions.
   rst=(n%10007)==10006;
  end
  @(negedge clk);
  if(visited[0]!=10'h3ff || visited[1]!=10'h3ff)$fatal(1,"Missing states %h/%h",visited[0],visited[1]);
  $display("PASS application equivalence: 200000 cycles x 2 MENU configurations, all 10 states, reset and all boundary outputs");
  $finish;
 end
endmodule
