`timescale 1ns/1ps
module tb_scan_resume;
reg clk=0; always #5 clk=~clk;
reg rst=1,start=0,resume_scan=0,pause_pulse=0,pause_on_found=0;
reg load=0,dv=0,ending=0,ack=0;
reg [7:0] data=0,bytes[0:511];
reg [31:0] first=0,last=6,load_sector=1;
reg [2:0] target=3;
wire req,done,found,ready,paused,write_req,load_done,load_error;
wire [31:0] addr,found_sector,cursor;
wire [2:0] total,error_code;
integer i,scan_reads=0,found_count=0,completed=0,failed=0,pixels=0;
integer trace[0:31],baseline[0:31],images[0:7];
wire pixel_valid;
bmp_read #(.CLK_FREQ_HZ(1000),.TIMEOUT_MS(1000),.ENABLE_SCAN_PAUSE(1)) dut(
 .clk(clk),.rst(rst),.ready(ready),.scan_start(start),
 .scan_start_sector(first),.scan_max_sector(last),.scan_target_count(target),
 .scan_pause_request(pause_pulse || (pause_on_found && found)),
 .scan_resume(resume_scan),.scan_paused(paused),.scan_resume_sector(cursor),
 .scan_done(done),.scan_error(),.scan_found_valid(found),.scan_found_sector(found_sector),.scan_found_total(total),
 .load_start(load),.load_sector(load_sector),.load_done(load_done),.load_error(load_error),.bmp_error(error_code),
 .sd_init_done(!rst),.state_code(),.bmp_width(16'd4),.bmp_height(16'd2),
 .write_req(write_req),.write_req_ack(ack),.sd_sec_read(req),.sd_sec_read_addr(addr),
 .sd_sec_read_data(data),.sd_sec_read_data_valid(dv),.sd_sec_read_end(ending),.sd_sec_read_failed(1'b0),
 .bmp_data_wr_en(pixel_valid),.bmp_data());
always @(posedge clk) if(!rst) begin
 if(found) begin images[found_count]=found_sector; found_count=found_count+1; end
 if(load_done) completed=completed+1;
 if(load_error) failed=failed+1;
 if(pixel_valid) pixels=pixels+1;
 if(paused && done) $fatal(1,"pause must not mean scan_done");
end
task tick(input integer n); repeat(n) @(negedge clk); endtask
task word32(input integer p,v); begin
 bytes[p]=v;bytes[p+1]=v>>8;bytes[p+2]=v>>16;bytes[p+3]=v>>24;
end endtask
task header(input integer width,height,length); begin
 for(i=0;i<512;i=i+1) bytes[i]=0;
 bytes[0]="B";bytes[1]="M";word32(2,length);word32(10,54);word32(14,40);
 word32(18,width);word32(22,height);bytes[26]=1;bytes[28]=24;
end endtask
task boot(input integer end_sector,wanted); begin
 rst=1;start=0;resume_scan=0;pause_pulse=0;pause_on_found=0;load=0;dv=0;ending=0;ack=0;
 first=0;last=end_sector;target=wanted;tick(4);rst=0;tick(4);
 scan_reads=0;found_count=0;completed=0;failed=0;pixels=0;
 start=1;tick(1);start=0;
end endtask
// A fixed raw-sector map: garbage, valid, unsupported two-sector BMP,
// valid, malformed, valid. Loading uses the identical header bytes.
task sector(input integer expected,input integer mid_pause,input integer corrupt);
 integer n;
 reg scanning;
 begin
  wait(req); if(addr!==expected) $fatal(1,"address %0d expected %0d",addr,expected);
  scanning=(dut.state==1);
  if(scanning) begin trace[scan_reads]=addr;scan_reads=scan_reads+1;end
  if(expected==2) header(8,40,1014); else header(4,2,78);
  if(expected==0 || expected==5 || corrupt) bytes[0]=0;
  @(negedge clk);
  for(n=0;n<512;n=n+1) begin
   data=bytes[n];dv=1;pause_pulse=mid_pause && n==100;tick(1);
   if(scanning && n<511 && paused) $fatal(1,"paused inside scan sector");
  end
  pause_pulse=0;dv=0;ending=1;tick(1);ending=0;tick(3);
 end
endtask
task check_pause(input integer expected,input integer count); begin
 if(!paused || !ready || done || req || cursor!=expected || total!=count)
  $fatal(1,"bad pause cursor=%0d total=%0d",cursor,total);
 // Longer than the no-progress deadline: an idle pause is not a read timeout.
 tick(1100);
 if(!paused || !ready || req || error_code!=0) $fatal(1,"idle pause timed out");
end endtask
task continue_scan; begin
 pause_on_found=0;resume_scan=1;tick(1);resume_scan=0;tick(1);
 if(paused) $fatal(1,"resume not accepted");
end endtask
task load_one(input integer corrupt); begin
 load_sector=1;load=1;tick(1);load=0;
 sector(1,0,corrupt);
 if(!corrupt) begin wait(write_req);ack=1;tick(1);ack=0;sector(1,0,0);tick(5);end
 if(!ready || !paused || cursor!=2 || total!=1 || done) $fatal(1,"load damaged scan context");
 if(corrupt) begin if(failed!=1 || error_code!=1)$fatal(1,"bad load not reported"); end
 else if(completed!=1 || pixels!=8) $fatal(1,"real load failed pixels=%0d",pixels);
end endtask
initial begin
 boot(6,3);sector(0,0,0);sector(1,0,0);sector(2,0,0);sector(4,0,0);sector(5,0,0);sector(6,0,0);
 if(!done || paused || scan_reads!=6 || found_count!=3 || total!=3) $fatal(1,"continuous reference");
 for(i=0;i<6;i=i+1) baseline[i]=trace[i];
 if(images[0]!=1 || images[1]!=4 || images[2]!=6) $fatal(1,"reference images");
 boot(6,3);sector(0,1,0);check_pause(1,0);continue_scan();
 pause_on_found=1;sector(1,0,0);check_pause(2,1);pause_on_found=0;
 load_one(0);load_one(1);continue_scan();
 sector(2,1,0);
 if(!paused || cursor!=4 || total!=1) $fatal(1,"unsupported BMP skip cursor");
 continue_scan();sector(4,0,0);sector(5,1,0);
 if(!paused || cursor!=6 || total!=2)$fatal(1,"malformed sector cursor");
 continue_scan();sector(6,1,0);
 if(!done || paused || total!=3 || found_count!=3 || scan_reads!=6) $fatal(1,"terminal count must win");
 for(i=0;i<6;i=i+1) if(trace[i]!=baseline[i])$fatal(1,"trace mismatch %0d",i);
 if(images[0]!=1 || images[1]!=4 || images[2]!=6)$fatal(1,"images duplicated/lost");
 $display("PASS identical scan trace and image indices across pause, real load success/failure, skip and resume");
 boot(0,4);sector(0,1,0);if(!done || paused || req)$fatal(1,"range end must win");
 boot(3,4);sector(0,0,0);sector(1,0,0);sector(2,1,0);
 if(!done || paused || total!=1 || req)$fatal(1,"skip exact end must finish");
 $display("PASS target count / ordinary range end / skip boundary finish without false pause");
 boot(6,3);sector(0,1,0);check_pause(1,0);
 // An explicit new scan replaces the saved transaction, without resume.
 first=4;start=1;tick(1);start=0;sector(4,0,0);
 if(paused || total!=1 || found_sector!=4)$fatal(1,"rescan retained stale cursor/count");
 sector(5,1,0);
 if(!paused || cursor!=6)$fatal(1,"reset test did not reach pause");
 rst=1;tick(3);if(paused || done || total!=0 || req)$fatal(1,"reset retained paused transaction");
 $display("PASS new scan and reset discard paused context");
 $finish;
end
initial begin #2000000;$fatal(1,"scan resume watchdog");end
endmodule
