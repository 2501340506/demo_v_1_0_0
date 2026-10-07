`timescale 1ns/1ps
// Real parser, manually paced raw sectors; deadline is 32 clock cycles.
module tb_bmp_timeout;
    reg clk=0;always #5 clk=~clk;
    reg rst=1,init_done=1,scan=0,start=0,dv=0,ending=0,ack=0;
    reg [7:0] data=0;
    reg [31:0] max_sector=0;
    wire ready,req,sd_req,we,done,error,scan_error,scan_done;
    wire [2:0] code,found;
    wire [31:0] addr;
    integer pixels=0,successes=0,errors=0,scan_errors=0;
    bmp_read #(.CLK_FREQ_HZ(1000),.TIMEOUT_MS(32)) dut(
      .clk(clk),.rst(rst),.ready(ready),.scan_start(scan),
      `ifndef STABILITY_S2
      .scan_pause_request(1'b0),.scan_resume(1'b0),.scan_paused(),.scan_resume_sector(),
`endif
      .scan_start_sector(32'd0),.scan_max_sector(max_sector),.scan_target_count(3'd4),
      .scan_done(scan_done),.scan_error(scan_error),.scan_found_valid(),.scan_found_sector(),.scan_found_total(found),
      .load_start(start),.load_sector(32'd0),.load_done(done),.load_error(error),.bmp_error(code),
      .sd_init_done(init_done),.state_code(),.bmp_width(16'd4),.bmp_height(16'd1),
      .write_req(req),.write_req_ack(ack),.sd_sec_read(sd_req),.sd_sec_read_addr(addr),
      .sd_sec_read_data(data),.sd_sec_read_data_valid(dv),.sd_sec_read_failed(1'b0),.sd_sec_read_end(ending),
      .bmp_data_wr_en(we),.bmp_data());
    always @(posedge clk) if(!rst) begin
      if(we)pixels=pixels+1;
      if(done)successes=successes+1;
      if(error)errors=errors+1;
      if(scan_error)scan_errors=scan_errors+1;
      if((error||scan_error) && code!=2)$fatal(1,"wrong timeout code");
    end
    task tick(input integer n);repeat(n)@(negedge clk);endtask
    task boot;
      begin rst=1;scan=0;start=0;dv=0;ending=0;ack=0;init_done=1;tick(4);
        pixels=0;successes=0;errors=0;scan_errors=0;rst=0;tick(2);end
    endtask
    task begin_load;begin start=1;tick(1);start=0;wait(sd_req);@(negedge clk);end endtask
    function [7:0] byte_at(input integer n);
      begin byte_at=0;case(n)
        0:byte_at="B";1:byte_at="M";2:byte_at=66;10:byte_at=54;
        14:byte_at=40;18:byte_at=4;22:byte_at=1;26:byte_at=1;28:byte_at=24;
        default:byte_at=0;
      endcase end
    endfunction
    task bytes(input integer count,gap,input header);
      integer b;
      begin for(b=0;b<count;b=b+1)begin
        data=header?byte_at(b):0;dv=1;tick(1);dv=0;tick(gap-1);
      end end
    endtask
    task finish_sector;begin ending=1;tick(1);ending=0;end endtask
    task header_ok;begin bytes(512,2,1);finish_sector();wait(req);@(negedge clk);end endtask
    task accept_write;begin ack=1;tick(1);ack=0;wait(sd_req);@(negedge clk);end endtask
    task stopped(input scan_case);
      integer old_pixels;
      begin
        tick(40);
        if(ready||sd_req||req||successes||errors!=!scan_case||scan_errors!=scan_case)
          $fatal(1,"timeout result/stop contract");
        old_pixels=pixels;
        // Late SD bytes/end, write ack, new requests and init flapping do not restart.
        dv=1;data=8'hff;ending=1;ack=1;start=1;scan=1;init_done=0;tick(4);
        init_done=1;tick(4);dv=0;ending=0;ack=0;start=0;scan=0;tick(40);
        if(ready||sd_req||req||we||pixels!=old_pixels||successes||errors!=!scan_case||scan_errors!=scan_case)
          $fatal(1,"late input revived stopped parser");
      end
    endtask
    integer i;
    initial begin
      boot();scan=1;tick(1);scan=0;stopped(1);
      if(scan_done)$fatal(1,"scan timeout reported normal completion");
      $display("PASS scan wait uses scan_error only; late data and init changes cannot restart");
      boot();begin_load();stopped(0);
      $display("PASS header no-response times out once, stays stopped");
      boot();begin_load();header_ok();stopped(0);
      $display("PASS write acknowledgement wait times out and cancels request");
      boot();begin_load();header_ok();accept_write();bytes(60,2,1);stopped(0);
      $display("PASS stalled partial pixel transfer times out and masks late pixels");
      boot();begin_load();header_ok();accept_write();bytes(512,1,1);stopped(0);
      $display("PASS all bytes without sector end still time out without success");
      boot();max_sector=2;scan=1;tick(1);scan=0;
      for(i=0;i<3;i=i+1)begin
        wait(sd_req);@(negedge clk);if(addr!=i)$fatal(1,"scan address");
        bytes(512,16,0);finish_sector();tick(2);
      end
      if(!scan_done||found||errors||scan_errors)$fatal(1,"long active scan timed out");
      $display("PASS long multi-sector scan exceeds total deadline but byte progress keeps it alive");
      boot();begin_load();header_ok();accept_write();bytes(512,16,1);finish_sector();tick(8);
      if(!ready||successes!=1||errors||scan_errors||pixels!=4)$fatal(1,"slow active image");
      $display("PASS slow continuous image succeeds and reset recovers from stop");
      boot();begin_load();wait(dut.wait_cycles==31);@(negedge clk);dv=1;data="B";tick(1);dv=0;
      if(error||dut.wait_cycles!=0)$fatal(1,"deadline valid byte lost");
      tick(10);if(errors)$fatal(1,"valid failed to restart deadline");
      $display("PASS byte on deadline takes priority and restarts inactivity timer");
      $finish;
    end
    initial begin #2000000;$fatal(1,"timeout suite watchdog");end
endmodule
