`timescale 1ns/1ps
// Fault injection checks the production diagnostic association and priorities.
// Transport/decoder failures are exercised separately by selector case 18.
module tb_page_error_detail;
 reg clk=0,rst=1;always #5 clk=~clk;
 wire [7:0] osd;
 reg scan=0,offer=0,ready=0,failed=0,parser_fail=0,mem_fail=0;
 reg result_valid=0,result_ready=0,success=0,commit_req=0,commit_ack=0;
 reg [1:0] image=0,target=0;reg [7:0] fat=0;reg [2:0] bmp=0,mem=0;
 sd_card_bmp #(.MENU_ENABLE(1),.PUBLICITY_ENABLE(1),.SCENE_ENABLE(1)) dut(
  .clk(clk),.rst(rst),.sdram_ready(1'b0),.SD_MISO(1'b1),.osd_error_code(osd));
 task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
 task expect_code(input [7:0] expected);
  begin #1;if(osd!==expected)$fatal(1,"OSD %h expected %h",osd,expected);end
 endtask
 task select_page(input [1:0] page);
  begin target=page;offer=1;ready=1;tick();offer=0;ready=0;end
 endtask
 task report_parser(input [1:0] page,input [7:0] code,input [2:0] decoder);
  begin image=page;fat=code;bmp=decoder;parser_fail=1;tick();parser_fail=0;end
 endtask
 task request_failure;begin failed=1;tick();failed=0;end endtask
 initial begin
  force dut.scan_accept=scan;force dut.cache_offer=offer;force dut.ctrl_request_ready=ready;
  force dut.cache_target=target;force dut.load_idx=image;force dut.request_failed=failed;
  force dut.parser_load_error=parser_fail;force dut.parser_fat_error=fat;force dut.parser_error=bmp;
  force dut.memory_failure=mem_fail;force dut.memory_code=mem;
  force dut.load_result_valid=result_valid;force dut.load_result_ready=result_ready;force dut.load_success=success;
  force dut.cache_display_request=commit_req;force dut.cache_display_ack=commit_ack;
  force dut.scan_state=0;force dut.menu_owner=0;force dut.menu_discard=0;
  force dut.application_error=0;force dut.app_rejected=0;force dut.scan_busy=0;
  force dut.load_fault=0;force dut.timeout_stopped=0;force dut.scan_result_valid=0;
  repeat(3)tick();rst=0;tick();
  select_page(1);report_parser(1,8'h25,3);
  report_parser(3,8'h10,2);request_failure();expect_code(8'h25);
  // Failed target remains stable while another page fails in background.
  report_parser(2,8'h24,3);expect_code(8'h25);
  select_page(3);request_failure();expect_code(8'h10);
  // Decoder cause only applies when no sector/FAT cause was reported.
  select_page(2);report_parser(2,0,3);request_failure();expect_code(8'h43);
  // Memory wins when both endpoints report the same aborted frame.
  image=2;parser_fail=1;fat=8'h25;mem_fail=1;mem=2;tick();
  parser_fail=0;mem_fail=0;request_failure();expect_code(8'h82);
  // Successful retry clears only that image's saved cause.
  image=2;result_valid=1;result_ready=1;success=1;tick();
  result_valid=0;result_ready=0;success=0;request_failure();expect_code(3);
  select_page(1);request_failure();expect_code(8'h25);
  commit_req=1;commit_ack=1;tick();commit_req=0;commit_ack=0;expect_code(0);
  // New resource epoch discards every old image's diagnostic.
  scan=1;tick();scan=0;expect_code(0);
  select_page(1);request_failure();expect_code(3);
  // Application-level errors retain their existing higher priority.
  force dut.application_error=1;expect_code(5);release dut.application_error;
  $display("PASS page error detail: per-image retention, target association, FAT/decoder/memory priority, retry, commit and scan clear");
  $finish;
 end
 initial begin #100000;$fatal(1,"watchdog");end
endmodule
