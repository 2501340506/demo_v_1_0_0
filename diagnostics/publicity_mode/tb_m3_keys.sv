`timescale 1ns/1ps
module tb_m3_keys;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,k1=1,k2=1,k4=1,busy=0,scene=0;reg [1:0] mode=0;
 wire prev,next,rescan,at,app,warn,speed,sm;
 integer np=0,nn=0,nr=0,na=0,napp=0,nw=0,ns=0;
 mode_key_control #(.CLK_FREQ_HZ(1000),.PREVIEW_ENABLE(1),.SCENE_ENABLE(1),.PUBLICITY_ENABLE(1)) dut(
 .clk(clk),.rst(rst),.enable(!busy),.key1(k1),.key2(k2),.key4(k4),.mode(mode),
 .next_event(next),.previous_event(prev),.rescan_event(rescan),.auto_toggle_event(at),
 .application_busy(busy),.scene_active(scene),.application_toggle(app),.scene_allowed(1'b1),
 .scene_mode(sm),.scene_next(),.scene_warn(warn),.scene_speed(speed),
 .adjust_decrease(),.adjust_increase(),.adjust_restore(),.adjust_select(),.manual_activity());
 always @(posedge clk)if(!rst)begin np+=prev;nn+=next;nr+=rescan;na+=at;napp+=app;nw+=warn;ns+=speed;end
 task cycles(input integer n);repeat(n)@(negedge clk);endtask
 initial begin
  cycles(4);rst=0;cycles(40);
  k4=0;cycles(1010);if(napp || na)$fatal(1,"early long press");
  cycles(20);if(napp!=1)$fatal(1,"one second threshold");
  cycles(2000);k4=1;cycles(40);if(napp!=1 || na)$fatal(1,"long release/held repeat");
  k4=0;cycles(100);k4=1;cycles(40);if(na!=1)$fatal(1,"short AUTO");
  k1=0;cycles(2000);k1=1;cycles(40);if(np!=1)$fatal(1,"previous repeated");
  k2=0;cycles(2030);k2=1;cycles(40);if(nr!=1 || nn)$fatal(1,"rescan/short exclusion");
  k4=0;cycles(600);mode=1;cycles(700);mode=0;cycles(1200);k4=1;cycles(40);
  if(napp!=1 || na!=1)$fatal(1,"held across switch page");
  k4=0;cycles(600);busy=1;cycles(50);busy=0;cycles(1200);k4=1;cycles(40);
  if(napp!=1 || na!=1)$fatal(1,"held across app/busy");
  scene=1;k1=0;cycles(1030);k1=1;cycles(40);if(ns!=1 || nw)$fatal(1,"speed gesture");
  k1=0;cycles(100);k1=1;cycles(40);if(nw!=1)$fatal(1,"warning short");
  mode=1;cycles(40);if(!sm)$fatal(1,"page changed application identity");
  k4=0;cycles(1500);k4=1;cycles(40);if(napp!=1)$fatal(1,"parameter page switched app");
  mode=3;cycles(40);k4=0;cycles(80);k4=1;cycles(40);if(na!=2)$fatal(1,"preview short");
  $display("PASS M3 keys: threshold, mutual exclusion, hold/release, page/app arming, preview, warning/speed");$finish;
 end
endmodule
