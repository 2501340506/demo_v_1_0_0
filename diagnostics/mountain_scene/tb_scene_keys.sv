`timescale 1ns/1ps
module tb_scene_keys;
 reg clk=0;always #5 clk=~clk;reg rst=1,k1=1,k2=1,k4=1,allowed=1;
 reg [1:0] mode=0;wire next,prev,rescan,aut,sm,sn,sw,ss;
 integer na=0,nn=0,np=0,nr=0,ns=0,nw=0,nt=0;
 mode_key_control #(.CLK_FREQ_HZ(1000),.PREVIEW_ENABLE(1),.SCENE_ENABLE(1)) dut(
 .clk(clk),.rst(rst),.enable(1'b1),.key1(k1),.key2(k2),.key4(k4),.mode(mode),
 .next_event(next),.previous_event(prev),.rescan_event(rescan),.auto_toggle_event(aut),
 .adjust_decrease(),.adjust_increase(),.adjust_restore(),.adjust_select(),.manual_activity(),
 .scene_allowed(allowed),.scene_mode(sm),.scene_next(sn),.scene_warn(sw),.scene_speed(ss));
 always @(posedge clk)begin na+=aut;nn+=next;np+=prev;nr+=rescan;ns+=sn;nw+=sw;nt+=ss;end
 task waitcl(input integer n);begin repeat(n)@(negedge clk);end endtask
 task key4short;begin k4=0;waitcl(60);k4=1;waitcl(60);end endtask
 task key4long;begin k4=0;waitcl(1100);k4=1;waitcl(60);end endtask
 initial begin
  waitcl(4);rst=0;waitcl(30);key4short();if(na!=1 || sm)$fatal(1,"legacy auto");
  key4long();if(!sm || na!=1)$fatal(1,"entry long gesture");
  key4short();if(nt!=1 || na!=1)$fatal(1,"speed routes");
  k1=0;waitcl(60);k1=1;waitcl(60);if(nw!=1 || np)$fatal(1,"warn routes");
  k2=0;waitcl(60);k2=1;waitcl(60);if(ns!=1 || nn)$fatal(1,"next routes");
  k2=0;waitcl(2100);k2=1;waitcl(60);if(nr!=1 || ns!=1)$fatal(1,"rescan routes");
  key4long();if(sm)$fatal(1,"exit long");key4long();if(!sm)$fatal(1,"reentry");
  mode=1;waitcl(50);if(sm)$fatal(1,"switch exit");
  k4=0;waitcl(60);mode=0;waitcl(1100);k4=1;waitcl(60);
  if(sm || na!=1)$fatal(1,"held across modes");
  allowed=0;key4long();if(sm || na!=1)$fatal(1,"missing pictures entry");
  mode=3;waitcl(30);key4short();if(na!=2)$fatal(1,"preview toggle");
  $display("PASS M4 keys: long entry/exit, short auto/speed, next/warn, rescan, switch exit, held suppression, missing-picture gate, legacy preview");$finish;
 end
 initial begin #1000000;$fatal(1,"watchdog");end
endmodule
