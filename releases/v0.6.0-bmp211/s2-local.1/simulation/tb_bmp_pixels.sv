`timescale 1ns/1ps
module tb_bmp_pixels;
    reg clk=0;always #5 clk=~clk;
    reg rst=1,start=0,dv=0,ending=0;
    reg [7:0] data=0;
    wire ready,req,sd_req,we,done,error;
    wire [2:0] code;
    wire [31:0] addr;
    wire [23:0] rgb;
    reg [2:0] ack=0;
    integer offset=54,file_size=66,pixels=0,successes=0,errors=0,reads=0;
    reg old_done=0,old_error=0;
    bmp_read dut(.clk(clk),.rst(rst),.ready(ready),.scan_start(1'b0),
      `ifndef STABILITY_S2
      .scan_pause_request(1'b0),.scan_resume(1'b0),.scan_paused(),.scan_resume_sector(),
`endif
      .scan_start_sector(32'd0),.scan_max_sector(32'd0),.scan_target_count(3'd1),
      .scan_error(),
      .scan_done(),.scan_found_valid(),.scan_found_sector(),.scan_found_total(),
      .load_start(start),.load_sector(32'd0),.load_done(done),.load_error(error),.bmp_error(code),
      .sd_init_done(!rst),.state_code(),.bmp_width(16'd4),.bmp_height(16'd1),
      .write_req(req),.write_req_ack(ack[2]),.sd_sec_read(sd_req),.sd_sec_read_addr(addr),
      .sd_sec_read_data(data),.sd_sec_read_data_valid(dv),.sd_sec_read_failed(1'b0),.sd_sec_read_end(ending),
      .bmp_data_wr_en(we),.bmp_data(rgb));wire [0:0] ref_ready;
wire [0:0] ref_load_done;
wire [0:0] ref_load_error;
wire [2:0] ref_bmp_error;
wire [0:0] ref_write_req;
wire [0:0] ref_sd_sec_read;
wire [31:0] ref_sd_sec_read_addr;
wire [0:0] ref_bmp_data_wr_en;
wire [23:0] ref_bmp_data;
bmp_read #(.USE_DECODER(0)) reference(.clk(clk),.rst(rst),.ready(ref_ready),.scan_start(1'b0),
      `ifndef STABILITY_S2
      .scan_pause_request(1'b0),.scan_resume(1'b0),.scan_paused(),.scan_resume_sector(),
`endif
      .scan_start_sector(32'd0),.scan_max_sector(32'd0),.scan_target_count(3'd1),
      .scan_error(),
      .scan_done(),.scan_found_valid(),.scan_found_sector(),.scan_found_total(),
      .load_start(start),.load_sector(32'd0),.load_done(ref_load_done),.load_error(ref_load_error),.bmp_error(ref_bmp_error),
      .sd_init_done(!rst),.state_code(),.bmp_width(16'd4),.bmp_height(16'd1),
      .write_req(ref_write_req),.write_req_ack(ack[2]),.sd_sec_read(ref_sd_sec_read),.sd_sec_read_addr(ref_sd_sec_read_addr),
      .sd_sec_read_data(data),.sd_sec_read_data_valid(dv),.sd_sec_read_failed(1'b0),.sd_sec_read_end(ending),
      .bmp_data_wr_en(ref_bmp_data_wr_en),.bmp_data(ref_bmp_data));
always @(negedge clk) if(!rst) begin
if(ref_ready !== ready) $fatal(1,"A/B ready");
if(ref_load_done !== done) $fatal(1,"A/B load_done");
if(ref_load_error !== error) $fatal(1,"A/B load_error");
if(ref_bmp_error !== code) $fatal(1,"A/B bmp_error");
if(ref_write_req !== req) $fatal(1,"A/B write_req");
if(ref_sd_sec_read !== sd_req) $fatal(1,"A/B sd_sec_read");
if(ref_sd_sec_read_addr !== addr) $fatal(1,"A/B sd_sec_read_addr");
if(ref_bmp_data_wr_en !== we) $fatal(1,"A/B bmp_data_wr_en");
if(dut.bmp_data_wr_en && ref_bmp_data !== rgb) $fatal(1,"A/B RGB");
end

    always @(posedge clk) begin
      ack<=rst?0:{ack[1:0],req};
      if(!rst)begin
        if(we)begin
          if(rgb!==24'hc35a17)$fatal(1,"RGB or trailing data mismatch");
          pixels=pixels+1;
          if(pixels>4)$fatal(1,"excess pixels from trailing file data");
        end
        if(done)begin successes=successes+1;if(pixels!=4)$fatal(1,"success before last write");end
        if(error)begin errors=errors+1;if(code!=3)$fatal(1,"expected truncated code");end
        if((done&&error)||(done&&old_done)||(error&&old_error))$fatal(1,"result pulse");
        old_done=done;old_error=error;
      end
    end
    function [7:0] byte_at(input integer n);
      begin
        byte_at=8'hee;
        if(n<offset)begin
          byte_at=0;
          case(n)
            0:byte_at="B";1:byte_at="M";
            2,3,4,5:byte_at=file_size>>(8*(n-2));
            10,11,12,13:byte_at=offset>>(8*(n-10));
            14:byte_at=40;18:byte_at=4;22:byte_at=1;26:byte_at=1;28:byte_at=24;
          endcase
        end else if(n<offset+12)case((n-offset)%3)
          0:byte_at=8'h17;1:byte_at=8'h5a;2:byte_at=8'hc3;
        endcase
      end
    endfunction
    task tick(input integer n);repeat(n)@(negedge clk);endtask
    task begin_load(input integer off,len);
      begin
        wait(ready);offset=off;file_size=len;pixels=0;successes=0;errors=0;reads=0;
        start=1;tick(1);start=0;
      end
    endtask
    task sector(input integer expected, count, gap,input same_end);
      integer b,k;
      begin
        wait(sd_req);if(addr!=expected)$fatal(1,"unexpected sector address");reads=reads+1;
        @(negedge clk);
        for(b=0;b<count;b=b+1)begin
          data=byte_at(expected*512+b);dv=1;ending=same_end&&(b==count-1);tick(1);
          dv=0;ending=0;
          for(k=1;k<gap;k=k+1)tick(1);
        end
        if(!same_end)begin ending=1;tick(1);ending=0;end
        tick(6);
      end
    endtask
    task good(input [511:0] name,input integer expected_reads);
      begin
        tick(8);
        if(!ready||successes!=1||errors!=0||pixels!=4||reads!=expected_reads||sd_req)$fatal(1,"good case %0s",name);
        $display("PASS %0s",name);
      end
    endtask
    task bad(input [511:0] name,input integer expected_pixels);
      begin
        tick(8);
        if(!ready||successes!=0||errors!=1||pixels!=expected_pixels||sd_req)$fatal(1,"bad case %0s",name);
        $display("PASS %0s",name);
      end
    endtask
    initial begin
      tick(5);rst=0;tick(4);
      begin_load(54,4096);sector(0,512,1,0);sector(0,512,1,0);
      good("trailing file bytes ignored; no extra tail-sector reads",2);
      begin_load(500,512);sector(0,512,1,1);sector(0,512,1,1);
      good("last RGB byte and sector end same cycle at byte 512",2);
      begin_load(510,522);sector(0,512,1,0);sector(0,512,2,1);sector(1,512,1,1);
      good("RGB triplet spans sector boundary with valid gaps",3);
      begin_load(54,66);sector(0,512,1,0);sector(0,65,1,1);
      bad("short pixel sector rejects partial final RGB",3);
      begin_load(54,66);sector(0,512,1,0);sector(0,66,1,0);
      bad("full pixel count cannot excuse short sector",4);
      begin_load(510,522);sector(0,512,1,0);sector(0,511,1,0);
      bad("short middle sector aborts before requesting next",0);
      begin_load(54,66);sector(0,33,1,0);
      bad("short header never opens write request",0);
      begin_load(54,66);sector(0,512,1,0);sector(0,512,2,0);
      good("normal reload after errors without reset",2);
      $finish;
    end
    initial begin #1000000;$fatal(1,"pixel watchdog");end
endmodule
