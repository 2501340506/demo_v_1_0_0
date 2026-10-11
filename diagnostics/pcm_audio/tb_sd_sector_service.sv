`timescale 1ns/1ps
module tb_sd_sector_service;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,pr=0,ar=0,pc=0,ac=0,urgent=0,enable_a=1;
 reg [31:0] pl=0,al=0;
 wire pb,ab,pa,aa,pv,av,pd,ad,raw_req;
 wire [7:0] pe,ae,data;wire [8:0] index;wire [31:0] raw_lba;
 reg [7:0] raw_data=0;reg raw_valid=0,raw_end=0,raw_fail=0;
 integer pbytes=0,abytes=0,pdone=0,adone=0,accepted_p=0,accepted_a=0;
 integer expected_owner=0,expected_error=0,reads=0;
 sd_sector_service #(.CLK_FREQ_HZ(1000),.TIMEOUT_MS(20)) dut(
 .clk(clk),.rst(rst),.p_req(pr),.p_lba(pl),.p_cancel(pc),
 .p_busy(pb),.p_accepted(pa),.p_valid(pv),.p_done(pd),.p_error(pe),
 .a_req(ar),.a_lba(al),.a_cancel(ac),.a_enable(enable_a),.a_urgent(urgent),
 .a_busy(ab),.a_accepted(aa),.a_valid(av),.a_done(ad),.a_error(ae),
 .sector_byte(data),.sector_index(index),.sd_sec_read(raw_req),.sd_sec_read_addr(raw_lba),
 .sd_sec_read_data(raw_data),.sd_sec_read_data_valid(raw_valid),.sd_sec_read_end(raw_end),.sd_sec_read_failed(raw_fail));
 always @(posedge clk)if(!rst)begin
  if(pa)accepted_p++;
  if(aa)accepted_a++;
  if(pv && av)$fatal(1,"response delivered twice");
  if(pv || av)begin
   if((av?1:0)!=expected_owner)$fatal(1,"wrong byte owner");
   if(data!==((raw_lba+index)&255))$fatal(1,"wrong byte or address");
  end
  if(pv)pbytes++;
  if(av)abytes++;
  if(pd)begin pdone++;if(pe!=expected_error)$fatal(1,"picture error %h expected %h",pe,expected_error);end
  if(ad)begin adone++;if(ae!=expected_error)$fatal(1,"audio error %h expected %h",ae,expected_error);end
 end
 task request(input bit p,input bit a,input integer l0,input integer l1);
 begin
  @(negedge clk);if((p && pb)||(a && ab))$fatal(1,"test requested busy mailbox");
  pr=p;ar=a;pl=l0;al=l1;
  @(negedge clk);pr=0;ar=0;pl='hdead;al='hbeef;
 end endtask
 task serve(input integer lba,input integer who,input integer mode);
 integer n,before_count,before_done;
 begin
  expected_owner=who;expected_error=(mode==1)?8'h13:(mode==2)?8'h10:(mode==3)?8'h11:0;
  wait(raw_req);@(negedge clk);
  if(raw_lba!=lba)$fatal(1,"LBA %0d expected %0d",raw_lba,lba);
  reads++;before_count=who?abytes:pbytes;before_done=who?adone:pdone;
  if(mode==3)begin wait(!raw_req);end
  else begin
   for(n=0;n<512;n++)begin
    raw_valid=1;raw_data=(lba+n)&255;
    if(mode==1 && n==10)begin if(who)ac=1;else pc=1;end
    @(negedge clk);
    if(mode==1 && n==11)begin pc=0;ac=0;end
   end
   raw_valid=0;
   if(mode==2)raw_fail=1;else raw_end=1;
   @(negedge clk);raw_end=0;raw_fail=0;
  end
  wait((who?adone:pdone)>before_done);@(negedge clk);
  if(mode==0 && (who?abytes:pbytes)-before_count!=512)$fatal(1,"lost bytes");
  if(mode==1 && (who?abytes:pbytes)-before_count>=512)$fatal(1,"cancel did not discard");
 end endtask
 initial begin
  repeat(3)@(negedge clk);rst=0;
  // Both accepted together; picture wins initial tie. Address changes after
  // acceptance cannot change the queued transaction. Waiting exceeds timeout.
  request(1,1,10,20);serve(10,0,0);serve(20,1,0);
  wait(!pb && !ab);request(1,1,30,40);serve(30,0,0);
  // Requeue picture while audio waits: audio wins the next nonurgent turn.
  wait(!pb);request(1,0,31,0);serve(40,1,0);serve(31,0,0);
  wait(!pb && !ab);urgent=1;request(1,1,50,60);serve(60,1,0);urgent=0;serve(50,0,0);
  // Cancel an in-flight picture without losing the queued audio sector.
  wait(!pb && !ab);request(1,0,70,0);wait(raw_req);
  request(0,1,0,80);serve(70,0,1);serve(80,1,0);
  // Cancel a queued picture while the audio owner remains intact.
  wait(!pb && !ab);urgent=1;request(1,1,90,100);
  wait(raw_req);@(negedge clk);expected_error=8'h13;pc=1;
  @(negedge clk);pc=0;@(negedge clk);expected_error=0;
  serve(100,1,0);urgent=0;
  // Failure and timeout release ownership for subsequent good reads.
  wait(!pb && !ab);request(1,0,110,0);serve(110,0,2);
  wait(!pb);request(1,0,120,0);serve(120,0,3);
  wait(!pb);request(0,1,0,130);serve(130,1,0);
  wait(!pb && !ab);enable_a=0;request(0,1,0,140);
  repeat(5)@(negedge clk);if(ab||raw_req)$fatal(1,"disabled audio accepted");
  // Reset discards both mailboxes; no stale response after restart.
  enable_a=1;request(1,1,150,160);@(negedge clk);rst=1;
  repeat(3)@(negedge clk);rst=0;
  repeat(4)@(negedge clk);if(pb||ab||pv||av||pd||ad||raw_req)$fatal(1,"stale reset transaction");
  request(1,0,170,0);serve(170,0,0);
  $display("PASS sector service: %0d physical reads; arbitration, latched addresses, cancellation, failure, timeout, reset",reads);
  $finish;
 end
 initial begin #300000;$fatal(1,"watchdog");end
endmodule
