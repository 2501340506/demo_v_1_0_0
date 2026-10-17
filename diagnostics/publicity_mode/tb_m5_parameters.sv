`timescale 1ns/1ps
module tb_m5_parameters;
 reg clk=0,rst=1,k1=1,k2=1,k4=1,scene=0,busy=0;always #5 clk=~clk;
 reg [1:0] mode=0;wire dec,inc,res,sel,nxt,prev,scan,auto_e,activity,sn,sw,ss,app;
 mode_key_control #(.CLK_FREQ_HZ(1000),.PREVIEW_ENABLE(1),.SCENE_ENABLE(1),.PUBLICITY_ENABLE(1)) keys(
 .clk(clk),.rst(rst),.enable(1'b1),.key1(k1),.key2(k2),.key4(k4),.mode(mode),
 .next_event(nxt),.previous_event(prev),.rescan_event(scan),.auto_toggle_event(auto_e),.manual_activity(activity),
 .adjust_decrease(dec),.adjust_increase(inc),.adjust_restore(res),.adjust_select(sel),
 .scene_allowed(1'b1),.scene_active(scene),.application_busy(busy),.scene_mode(),.scene_next(sn),.scene_warn(sw),.scene_speed(ss),.application_toggle(app));
 wire [7:0] b,c;wire [3:0] v;wire [1:0] selected;
 media_adjust_control ctl(clk,rst,mode,dec,inc,res,sel,b,c,v,selected);
 integer scans=0,autos=0,pictures=0,scenes=0,apps=0,j,q;
 always @(posedge clk)begin if(scan)scans++;if(auto_e)autos++;if(nxt||prev)pictures++;if(sn||sw||ss)scenes++;if(app)apps++;end
 task ticks(input integer t);repeat(t)@(negedge clk);endtask
 task press(input integer key,input integer duration);
 begin if(key==1)k1=0;else if(key==2)k2=0;else k4=0;ticks(duration);k1=1;k2=1;k4=1;ticks(60);end endtask
 task combo;begin k1=0;k2=0;ticks(60);k1=1;k2=1;ticks(60);end endtask
 task parameters;
 begin
 mode=1;ticks(60);if(selected!=0)$fatal(1,"B selection");
 for(j=0;j<20;j++)press(1,60);if(b!=0)$fatal(1,"B floor");
 for(j=0;j<20;j++)press(2,60);if(b!=255)$fatal(1,"B ceiling");combo();if(b!=128)$fatal(1,"B restore");
 press(4,60);if(selected!=2)$fatal(1,"B/V toggle");
 for(j=0;j<14;j++)press(1,60);if(v!=0)$fatal(1,"V floor");
 for(j=0;j<14;j++)press(2,60);if(v!=10)$fatal(1,"V ceiling");press(1,60);combo();if(v!=10)$fatal(1,"V restore");
 press(4,1100);if(selected!=2)$fatal(1,"parameter long4 must not select/switch");
 mode=2;ticks(60);if(selected!=1)$fatal(1,"C selection");
 for(j=0;j<20;j++)press(1,60);if(c!=0)$fatal(1,"C floor");
 for(j=0;j<20;j++)press(2,60);if(c!=255)$fatal(1,"C ceiling");combo();if(c!=128)$fatal(1,"C restore");
 press(4,60);if(selected!=2)$fatal(1,"C/V toggle");press(4,60);if(selected!=1)$fatal(1,"V/C toggle");
 end endtask
 initial begin
 ticks(5);rst=0;ticks(60);parameters();scene=1;ticks(60);parameters();
 if(scans || autos || pictures || scenes || apps)$fatal(1,"parameter gestures leaked playback events");
 mode=3;ticks(60);press(1,60);press(2,60);
 if(pictures!=2 || scenes)$fatal(1,"scene preview key routing");
 mode=0;ticks(60);press(1,1100);if(scenes!=1)$fatal(1,"scene speed long");press(1,60);press(2,60);
 if(scenes!=3 || pictures!=2)$fatal(1,"scene playback routing");
 k4=0;ticks(500);mode=1;ticks(1100);k4=1;ticks(60);if(apps || autos)$fatal(1,"held key crossed UI page");
 mode=0;ticks(60);busy=1;k4=0;ticks(1100);busy=0;ticks(1100);k4=1;ticks(60);if(apps)$fatal(1,"busy held key armed");
 press(4,1100);if(apps!=1 || autos)$fatal(1,"application long4");press(4,60);if(autos!=1)$fatal(1,"AUTO short4");
 $display("PASS M5 parameters: two apps B/C saturation/default16 V0..10, selection/combo, preview routing, speed/AUTO identity and hold cancellation");$finish;
 end
 initial begin #5000000;$fatal(1,"M5 parameter watchdog");end
endmodule
