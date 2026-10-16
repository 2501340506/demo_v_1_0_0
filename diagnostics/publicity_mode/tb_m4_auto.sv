`timescale 1ns/1ps
module tb_m4_auto;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,en=0,commit=0,pending=0,busy=0,ui=1,frame=0,toggle=0,manual=0,ready=1;
 reg ar=0,selected=1,found=1,done=0;reg [7:0] error=0;reg [15:0] id=16'h1101,did=16'h1101;
 reg [1:0] cp=0;wire request,fade,auto_en,offer,accept;wire [1:0] page;wire [2:0] status;
 publicity_voice_control dut(.clk(clk),.rst(rst),.enable(en),.commit(commit),.commit_page(cp),.page_pending(pending),.busy(busy),.ui_play(ui),.frame_tick(frame),
 .toggle_auto(toggle),.manual(manual),.offer_ready(ready),.audio_ready(ar),.selected_publicity(selected),.selected_found(found),.stream_error(error),
 .session_id(id),.done(done),.done_id(did),.voice_request(request),.page(page),.fade(fade),.auto_enable(auto_en),.auto_offer(offer),.auto_accept(accept),.status(status));
 task cyc(input integer n);repeat(n)@(negedge clk);endtask
 task tick;begin frame=1;cyc(1);frame=0;cyc(1);end endtask
 task frames(input integer n);repeat(n)tick();endtask
 task new_page(input integer p);begin cp=p;commit=1;cyc(1);commit=0;wait(request);cyc(2);id++;ar=1;cyc(1);ar=0;cyc(1);if(page!=p)$fatal(1,"page not committed");end endtask
 task auto_on;begin toggle=1;manual=1;cyc(1);toggle=0;manual=0;end endtask
 integer offers=0,i;
 always @(posedge clk)if(accept)offers++;
 initial begin
  cyc(4);rst=0;en=1;new_page(0);auto_on();
  frames(310);if(offers || status!=2)$fatal(1,"AUTO cut long narration");
  did=id-1;done=1;cyc(5);frames(3);if(offers || status!=2)$fatal(1,"stale EOF accepted");
  did=id;cyc(2);done=0;tick();if(offers)$fatal(1,"no HDMI tail guard");tick();cyc(2);
  if(offers!=1 || status!=3)$fatal(1,"natural EOF did not advance");frames(20);if(offers!=1)$fatal(1,"repeated AUTO offer");
  new_page(1);did=id;done=1;cyc(2);done=0;frames(299);if(offers!=1)$fatal(1,"short voice skipped five seconds");
  manual=1;tick();if(offers!=1)$fatal(1,"AUTO beat manual");manual=0;ready=0;cyc(2);if(offers!=1 || !offer || accept)$fatal(1,"AUTO valid must persist independently of ready");ready=1;cyc(2);if(offers!=2)$fatal(1,"five second advance");
  new_page(1); // Same-page preview replay requires a fresh identity/request.
  ui=0;did=id;done=1;cyc(2);done=0;frames(320);
  if(offers!=2 || status!=3)$fatal(1,"non00 lost completion or advanced");
  ui=1;frames(299);if(offers!=2)$fatal(1,"return00 did not restart dwell");tick();cyc(2);if(offers!=3)$fatal(1,"return00 five seconds");
  found=0;new_page(2);frames(300);cyc(2);if(status!=0 || offers!=4)$fatal(1,"missing VOI fallback");
  found=1;error=8'h30;new_page(3);frames(300);cyc(2);if(status!=4 || offers!=5)$fatal(1,"error fallback/status");
  error=0;new_page(0);error=8'h10;cyc(2);frames(300);cyc(2);if(status!=4 || offers!=6)$fatal(1,"runtime read error fallback");
  error=0;new_page(1);auto_on();did=id;done=1;cyc(2);frames(310);if(offers!=6 || auto_en)$fatal(1,"AUTO off still advanced");
  en=0;cyc(2);en=1;new_page(0);did=id-2;done=1;frames(310);if(status!=2 || auto_en || offers!=6)$fatal(1,"mode reentry used old EOF/AUTO");
  $display("PASS M4 AUTO: actual 300-frame minimum, long/short/missing/error, old identity, two-frame HDMI tail, manual priority, same-page restart, non00 latch/return, AUTO off and mode reentry");$finish;
 end
 initial begin #200000;$fatal(1,"M4 auto watchdog state=%d",dut.state);end
endmodule
