`timescale 1ns/1ps
module tb_cache_equivalence;
 reg clk=0,rst=1; always #5 clk=~clk;
 reg  pause=0;
 reg  rescan_event=0;
 wire  scan_request[0:7];
 reg  scan_accept=0;
 reg  scan_result_valid=0;
 reg  scan_success=0;
 reg [2:0] scan_image_count=0;
 wire  scan_result_ready[0:7];
 wire  scan_busy[0:7];
 reg  request_valid=0;
 reg [1:0] request_image=0;
 reg  request_manual=0;
 wire  request_ready[0:7];
 wire  foreground_busy[0:7];
 wire  load_request[0:7];
 reg  load_accept=0;
 wire [1:0] load_image[0:7];
 wire [1:0] load_bank[0:7];
 reg  load_result_valid=0;
 reg  load_success=0;
 reg  load_timeout=0;
 wire  load_result_ready[0:7];
 wire  cancel_request[0:7];
 reg  cancel_ack=0;
 reg  communication_fault=0;
 wire  storage_busy[0:7];
 wire  storage_stopped[0:7];
 wire  display_request[0:7];
 wire [1:0] display_image[0:7];
 wire [1:0] display_bank[0:7];
 reg  display_ack=0;
 wire  display_valid[0:7];
 wire [1:0] current_image[0:7];
 wire [1:0] current_bank[0:7];
 wire  first_image_committed[0:7];
 wire  committed_valid[0:7];
 wire [1:0] committed_image[0:7];
 reg  committed_ready=0;
 wire [2:0] image_count[0:7];
 wire [3:0] cache_valid[0:7];
 wire [3:0] cache_failed[0:7];
 wire [7:0] cache_banks[0:7];
 wire  cache_complete[0:7];
 wire  cache_hit[0:7];
 wire  request_failed[0:7];
 wire  load_failed[0:7];
 wire  retry_event[0:7];
 wire [1:0] cache_complete_image[0:7];
 wire [1:0] cache_hit_image[0:7];
 wire [1:0] failed_image[0:7];
 reg [3:0] phase_seen[0:3],load_seen[0:3];
 genvar g;
 generate for(g=0;g<4;g=g+1)begin:pair
 media_frame_cache_control #(.PAUSE_ENABLE(g%2),.STRICT_FIRST_ENABLE(g/2)) dut(
  .pause(pause),.strict_first(1'b1),
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
 media_frame_cache_control_reference #(.PAUSE_ENABLE(g%2),.STRICT_FIRST_ENABLE(g/2)) ref_dut(
  .pause(pause),.strict_first(1'b1),
  .clk(clk),
  .rst(rst),
  .rescan_event(rescan_event),
  .scan_request(scan_request[g+4]),
  .scan_accept(scan_accept),
  .scan_result_valid(scan_result_valid),
  .scan_success(scan_success),
  .scan_image_count(scan_image_count),
  .scan_result_ready(scan_result_ready[g+4]),
  .scan_busy(scan_busy[g+4]),
  .request_valid(request_valid),
  .request_image(request_image),
  .request_manual(request_manual),
  .request_ready(request_ready[g+4]),
  .foreground_busy(foreground_busy[g+4]),
  .load_request(load_request[g+4]),
  .load_accept(load_accept),
  .load_image(load_image[g+4]),
  .load_bank(load_bank[g+4]),
  .load_result_valid(load_result_valid),
  .load_success(load_success),
  .load_timeout(load_timeout),
  .load_result_ready(load_result_ready[g+4]),
  .cancel_request(cancel_request[g+4]),
  .cancel_ack(cancel_ack),
  .communication_fault(communication_fault),
  .storage_busy(storage_busy[g+4]),
  .storage_stopped(storage_stopped[g+4]),
  .display_request(display_request[g+4]),
  .display_image(display_image[g+4]),
  .display_bank(display_bank[g+4]),
  .display_ack(display_ack),
  .display_valid(display_valid[g+4]),
  .current_image(current_image[g+4]),
  .current_bank(current_bank[g+4]),
  .first_image_committed(first_image_committed[g+4]),
  .committed_valid(committed_valid[g+4]),
  .committed_image(committed_image[g+4]),
  .committed_ready(committed_ready),
  .image_count(image_count[g+4]),
  .cache_valid(cache_valid[g+4]),
  .cache_failed(cache_failed[g+4]),
  .cache_banks(cache_banks[g+4]),
  .cache_complete(cache_complete[g+4]),
  .cache_hit(cache_hit[g+4]),
  .request_failed(request_failed[g+4]),
  .load_failed(load_failed[g+4]),
  .retry_event(retry_event[g+4]),
  .cache_complete_image(cache_complete_image[g+4]),
  .cache_hit_image(cache_hit_image[g+4]),
  .failed_image(failed_image[g+4]));
 always @(negedge clk)begin
  if({scan_request[g],scan_result_ready[g],scan_busy[g],request_ready[g],foreground_busy[g],load_request[g],load_image[g],load_bank[g],load_result_ready[g],cancel_request[g],storage_busy[g],storage_stopped[g],display_request[g],display_image[g],display_bank[g],display_valid[g],current_image[g],current_bank[g],first_image_committed[g],committed_valid[g],committed_image[g],image_count[g],cache_valid[g],cache_failed[g],cache_banks[g],cache_complete[g],cache_hit[g],request_failed[g],load_failed[g],retry_event[g],cache_complete_image[g],cache_hit_image[g],failed_image[g]} !== {scan_request[g+4],scan_result_ready[g+4],scan_busy[g+4],request_ready[g+4],foreground_busy[g+4],load_request[g+4],load_image[g+4],load_bank[g+4],load_result_ready[g+4],cancel_request[g+4],storage_busy[g+4],storage_stopped[g+4],display_request[g+4],display_image[g+4],display_bank[g+4],display_valid[g+4],current_image[g+4],current_bank[g+4],first_image_committed[g+4],committed_valid[g+4],committed_image[g+4],image_count[g+4],cache_valid[g+4],cache_failed[g+4],cache_banks[g+4],cache_complete[g+4],cache_hit[g+4],request_failed[g+4],load_failed[g+4],retry_event[g+4],cache_complete_image[g+4],cache_hit_image[g+4],failed_image[g+4]})
   $fatal(1,"cache boundary equivalence mismatch pause=%0d",g);
  if(dut.occupied !== ref_dut.occupied || dut.free_bank !== ref_dut.free_bank || dut.free_found !== ref_dut.free_found)
   $fatal(1,"cache allocation mismatch pause=%0d",g);
  if(dut.busy_summary !== (dut.foreground_pending || dut.display_request || dut.committed_valid) ||
     dut.request_idle !== (dut.phase==2 && dut.first_image_committed && !dut.foreground_pending && !dut.display_request && !dut.committed_valid))
   $fatal(1,"cache summary invariant config=%0d",g);
  phase_seen[g][dut.phase]=1;load_seen[g][dut.load_state]=1;
 end
 end endgenerate
 integer n;
 initial begin
  for(n=0;n<4;n=n+1)begin phase_seen[n]=0;load_seen[n]=0;end
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
  for(n=0;n<4;n=n+1)if(phase_seen[n]!=15 || load_seen[n]!=15)$fatal(1,"cache state coverage incomplete config=%0d",n);
  $display("PASS cache equivalence: 200000 cycles x 4 PAUSE/STRICT_FIRST configurations; all phase/load states, bank allocation, every boundary output and asynchronous reset");
  $finish;
 end
endmodule
