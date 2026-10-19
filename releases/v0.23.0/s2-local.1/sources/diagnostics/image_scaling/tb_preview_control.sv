`timescale 1ns/1ps
module tb_preview_control;
 reg clk=0,rst=1;always #5 clk=~clk;
 reg [1:0] mode=0,current=1;
 reg scanning=0,first=1,transition=0,foreground=0,rescan=0;
 reg next_key=0,prev_key=0,toggle=0,ready=1,failed=0,stopped=0,display=0,committed=0;
 reg [3:0] valid=2;reg [7:0] banks=8'he4;
 wire offer,target_select,intent,selecting,full,request;wire [1:0] target;wire [17:0] desc;
 reg ack=0;integer cycle=0;
 media_preview_control dut(.clk(clk),.rst(rst),.mode(mode),.scan_busy(scanning),.first_image_committed(first),
 .transition_busy(transition),.foreground_busy(foreground),.rescan_wait(rescan),
 .next_event(next_key),.previous_event(prev_key),.toggle_event(toggle),
 .current_image(current),.image_count(3'd4),.cache_valid(valid),.cache_banks(banks),
 .request_ready(ready),.request_failed(failed),.storage_stopped(stopped),.display_request(display),.display_committed(committed),
 .request_valid(offer),.request_image(target),.target_select(target_select),.preview_intent(intent),.selecting(selecting),.fullscreen_ready(full),
 .preview_request(request),.preview_descriptor(desc),.preview_ack(ack));
 reg [17:0] held;reg outstanding=0;
 always @(posedge clk)begin
  cycle<=cycle+1;
  if(!rst && (target_select!==dut.offer || offer!==(target_select && !rescan)))
   $fatal(1,"preview target owner/request inhibition mismatch");
  if(cycle%30==0)ack<=request;
  if(outstanding && request!=ack && desc!==held)$fatal(1,"mailbox data changed before acknowledgement");
  held<=desc;outstanding<=request!=ack;
 end
 task key(input integer k);begin
  @(negedge clk);next_key=k==0;prev_key=k==1;toggle=k==2;
  @(negedge clk);next_key=0;prev_key=0;toggle=0;repeat(3)@(negedge clk);
 end endtask
 initial begin
  repeat(3)@(negedge clk);rst=0;transition=1;mode=3;
  repeat(20)@(negedge clk);if(intent)$fatal(1,"entered during transition");
  transition=0;wait(intent);wait(desc[17]);if(desc[16:15]!=1)$fatal(1,"initial focus");
  key(0);wait(desc[16:15]==2);$display("step focus");if(offer)$fatal(1,"focus became request");
  ready=0;key(2);wait(offer);$display("step offer");if(target!=2 || !intent)$fatal(1,"uncached focus request");
  ready=1;foreground=1;repeat(60)@(negedge clk);
  if(!intent || offer)$fatal(1,"left preview before loaded");
  failed=1;@(negedge clk);failed=0;foreground=0;
  repeat(5)@(negedge clk);if(!intent || selecting)$fatal(1,"failure lost preview");
  key(2);$display("step select again");foreground=1;valid=6;display=1;
  wait(full);$display("step full");if(desc[17])$fatal(1,"full before preview ack");
  @(negedge clk);committed=1;current=2;@(negedge clk);committed=0;display=0;foreground=0;
  key(2);wait(desc[17]);key(0);wait(desc[16:15]==3);
  mode=0;wait(full);$display("step full");if(current!=2)$fatal(1,"exit selected focus");
  mode=3;wait(desc[17]);rescan=1;wait(full);$display("step full");scanning=1;first=0;
  repeat(5)@(negedge clk);rescan=0;scanning=0;first=1;current=0;banks=8'h1b;
  wait(desc[17] && desc[16:15]==0 && desc[7:0]==8'h1b);
  ready=0;key(2);wait(offer);@(negedge clk);rescan=1;#1;
  if(offer || !target_select)$fatal(1,"rescan must inhibit valid without combinationally changing target owner");
  @(negedge clk);if(target_select || selecting)$fatal(1,"cancelled preview owner was retained");
  rescan=0;wait(desc[17]);
  ready=0;stopped=1;key(2);repeat(8)@(negedge clk);
  if(selecting || offer || !intent)$fatal(1,"stopped storage trapped uncached selection");
  $display("PASS preview control: transition, focus, uncached failure/success, mailbox, exit, rescan, stopped storage");$finish;
 end
 initial begin #100000;$fatal(1,"watchdog desc=%h intent=%b selecting=%b offer=%b full=%b focus=%d entered=%b fullview=%b",desc,intent,selecting,offer,full,dut.focus,dut.entered,dut.full_view);end
endmodule
