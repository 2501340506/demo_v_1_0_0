`timescale 1ns/1ps
module tb_cache_equivalence;
 reg clk=0,rst=1; always #5 clk=~clk;
 reg  pause=0;
 reg  rescan_event=0;
 wire  scan_request[0:3];
 reg  scan_accept=0;
 reg  scan_result_valid=0;
 reg  scan_success=0;
 reg [2:0] scan_image_count=0;
 wire  scan_result_ready[0:3];
 wire  scan_busy[0:3];
 reg  request_valid=0;
 reg [1:0] request_image=0;
 reg  request_manual=0;
 wire  request_ready[0:3];
 wire  foreground_busy[0:3];
 wire  load_request[0:3];
 reg  load_accept=0;
 wire [1:0] load_image[0:3];
 wire [1:0] load_bank[0:3];
 reg  load_result_valid=0;
 reg  load_success=0;
 reg  load_timeout=0;
 wire  load_result_ready[0:3];
 wire  cancel_request[0:3];
 reg  cancel_ack=0;
 reg  communication_fault=0;
 wire  storage_busy[0:3];
 wire  storage_stopped[0:3];
 wire  display_request[0:3];
 wire [1:0] display_image[0:3];
 wire [1:0] display_bank[0:3];
 reg  display_ack=0;
 wire  display_valid[0:3];
 wire [1:0] current_image[0:3];
 wire [1:0] current_bank[0:3];
 wire  first_image_committed[0:3];
 wire  committed_valid[0:3];
 wire [1:0] committed_image[0:3];
 reg  committed_ready=0;
 wire [2:0] image_count[0:3];
 wire [3:0] cache_valid[0:3];
 wire [3:0] cache_failed[0:3];
 wire [7:0] cache_banks[0:3];
 wire  cache_complete[0:3];
 wire  cache_hit[0:3];
 wire  request_failed[0:3];
 wire  load_failed[0:3];
 wire  retry_event[0:3];
 wire [1:0] cache_complete_image[0:3];
 wire [1:0] cache_hit_image[0:3];
 wire [1:0] failed_image[0:3];
 reg [3:0] phase_seen[0:1],load_seen[0:1];
 genvar g;
 generate for(g=0;g<2;g=g+1)begin:pair
 media_frame_cache_control #(.PAUSE_ENABLE(g)) dut(
  .pause(pause),
  .clk(clk),
  .rst(rst),
  .rescan_event(rescan_event),
  .scan_request(scan_request[g+0]),
  .scan_accept(scan_accept),
  .scan_result_valid(scan_result_valid),
  .scan_success(scan_success),
  .scan_image_count(scan_image_count),
  .scan_result_ready(scan_result_ready[g+0]),
  .scan_busy(scan_busy[g+0]),
  .request_valid(request_valid),
  .request_image(request_image),
  .request_manual(request_manual),
  .request_ready(request_ready[g+0]),
  .foreground_busy(foreground_busy[g+0]),
  .load_request(load_request[g+0]),
  .load_accept(load_accept),
  .load_image(load_image[g+0]),
  .load_bank(load_bank[g+0]),
  .load_result_valid(load_result_valid),
  .load_success(load_success),
  .load_timeout(load_timeout),
  .load_result_ready(load_result_ready[g+0]),
  .cancel_request(cancel_request[g+0]),
  .cancel_ack(cancel_ack),
  .communication_fault(communication_fault),
  .storage_busy(storage_busy[g+0]),
  .storage_stopped(storage_stopped[g+0]),
  .display_request(display_request[g+0]),
  .display_image(display_image[g+0]),
  .display_bank(display_bank[g+0]),
  .display_ack(display_ack),
  .display_valid(display_valid[g+0]),
  .current_image(current_image[g+0]),
  .current_bank(current_bank[g+0]),
  .first_image_committed(first_image_committed[g+0]),
  .committed_valid(committed_valid[g+0]),
  .committed_image(committed_image[g+0]),
  .committed_ready(committed_ready),
  .image_count(image_count[g+0]),
  .cache_valid(cache_valid[g+0]),
  .cache_failed(cache_failed[g+0]),
  .cache_banks(cache_banks[g+0]),
  .cache_complete(cache_complete[g+0]),
  .cache_hit(cache_hit[g+0]),
  .request_failed(request_failed[g+0]),
  .load_failed(load_failed[g+0]),
  .retry_event(retry_event[g+0]),
  .cache_complete_image(cache_complete_image[g+0]),
  .cache_hit_image(cache_hit_image[g+0]),
  .failed_image(failed_image[g+0]));
 media_frame_cache_control_reference #(.PAUSE_ENABLE(g)) ref_dut(
  .pause(pause),
  .clk(clk),
  .rst(rst),
  .rescan_event(rescan_event),
  .scan_request(scan_request[g+2]),
  .scan_accept(scan_accept),
  .scan_result_valid(scan_result_valid),
  .scan_success(scan_success),
  .scan_image_count(scan_image_count),
  .scan_result_ready(scan_result_ready[g+2]),
  .scan_busy(scan_busy[g+2]),
  .request_valid(request_valid),
  .request_image(request_image),
  .request_manual(request_manual),
  .request_ready(request_ready[g+2]),
  .foreground_busy(foreground_busy[g+2]),
  .load_request(load_request[g+2]),
  .load_accept(load_accept),
  .load_image(load_image[g+2]),
  .load_bank(load_bank[g+2]),
  .load_result_valid(load_result_valid),
  .load_success(load_success),
  .load_timeout(load_timeout),
  .load_result_ready(load_result_ready[g+2]),
  .cancel_request(cancel_request[g+2]),
  .cancel_ack(cancel_ack),
  .communication_fault(communication_fault),
  .storage_busy(storage_busy[g+2]),
  .storage_stopped(storage_stopped[g+2]),
  .display_request(display_request[g+2]),
  .display_image(display_image[g+2]),
  .display_bank(display_bank[g+2]),
  .display_ack(display_ack),
  .display_valid(display_valid[g+2]),
  .current_image(current_image[g+2]),
  .current_bank(current_bank[g+2]),
  .first_image_committed(first_image_committed[g+2]),
  .committed_valid(committed_valid[g+2]),
  .committed_image(committed_image[g+2]),
  .committed_ready(committed_ready),
  .image_count(image_count[g+2]),
  .cache_valid(cache_valid[g+2]),
  .cache_failed(cache_failed[g+2]),
  .cache_banks(cache_banks[g+2]),
  .cache_complete(cache_complete[g+2]),
  .cache_hit(cache_hit[g+2]),
  .request_failed(request_failed[g+2]),
  .load_failed(load_failed[g+2]),
  .retry_event(retry_event[g+2]),
  .cache_complete_image(cache_complete_image[g+2]),
  .cache_hit_image(cache_hit_image[g+2]),
  .failed_image(failed_image[g+2]));
 always @(negedge clk)begin
  if({scan_request[g],scan_result_ready[g],scan_busy[g],request_ready[g],foreground_busy[g],load_request[g],load_image[g],load_bank[g],load_result_ready[g],cancel_request[g],storage_busy[g],storage_stopped[g],display_request[g],display_image[g],display_bank[g],display_valid[g],current_image[g],current_bank[g],first_image_committed[g],committed_valid[g],committed_image[g],image_count[g],cache_valid[g],cache_failed[g],cache_banks[g],cache_complete[g],cache_hit[g],request_failed[g],load_failed[g],retry_event[g],cache_complete_image[g],cache_hit_image[g],failed_image[g]} !== {scan_request[g+2],scan_result_ready[g+2],scan_busy[g+2],request_ready[g+2],foreground_busy[g+2],load_request[g+2],load_image[g+2],load_bank[g+2],load_result_ready[g+2],cancel_request[g+2],storage_busy[g+2],storage_stopped[g+2],display_request[g+2],display_image[g+2],display_bank[g+2],display_valid[g+2],current_image[g+2],current_bank[g+2],first_image_committed[g+2],committed_valid[g+2],committed_image[g+2],image_count[g+2],cache_valid[g+2],cache_failed[g+2],cache_banks[g+2],cache_complete[g+2],cache_hit[g+2],request_failed[g+2],load_failed[g+2],retry_event[g+2],cache_complete_image[g+2],cache_hit_image[g+2],failed_image[g+2]})
   $fatal(1,"cache boundary equivalence mismatch pause=%0d",g);
  if(dut.occupied !== ref_dut.occupied || dut.free_bank !== ref_dut.free_bank || dut.free_found !== ref_dut.free_found)
   $fatal(1,"cache allocation mismatch pause=%0d",g);
  phase_seen[g][dut.phase]=1;load_seen[g][dut.load_state]=1;
 end
 end endgenerate
 integer n;
 initial begin
  phase_seen[0]=0;phase_seen[1]=0;load_seen[0]=0;load_seen[1]=0;
  repeat(3)@(negedge clk);#1;rst=0;
  for(n=0;n<200000;n=n+1)begin
   @(negedge clk);#1;
   pause=$urandom;
   rescan_event=($urandom_range(0,199)==0);
   scan_accept=$urandom;
   scan_result_valid=$urandom;
   scan_success=($urandom_range(0,9)!=0);
   scan_image_count=$urandom_range(0,4);
   request_valid=$urandom;
   request_image=$urandom;
   request_manual=$urandom;
   load_accept=$urandom;
   load_result_valid=$urandom;
   load_success=$urandom;
   load_timeout=$urandom;
   cancel_ack=$urandom;
   communication_fault=($urandom_range(0,199)==0);
   display_ack=$urandom;
   committed_ready=$urandom;
   rst=(n%10007)==10006;
  end
  @(negedge clk);
  if(phase_seen[0]!=15 || phase_seen[1]!=15 || load_seen[0]!=15 || load_seen[1]!=15)
   $fatal(1,"cache state coverage incomplete %h %h %h %h",phase_seen[0],phase_seen[1],load_seen[0],load_seen[1]);
  $display("PASS cache equivalence: 200000 cycles x 2 PAUSE configurations; all phase/load states, bank allocation, every boundary output and asynchronous reset");
  $finish;
 end
endmodule
