`timescale 1ns/1ps
module tb_menu_control;
 reg clk=0,rst=1,sw=1,k1=1,k2=1,k4=1;
 always #5 clk=~clk;
 reg [1:0] mode=3;reg safe=0,ready=1,done=0,rejected=0;reg [3:0] valid=15;
 wire pending,active,enter,confirm,cancel,blocked;wire [1:0] focus,effective;
 integer entries=0,confirms=0,cancels=0;
 disaster_menu_control #(.CLK_FREQ_HZ(1000)) dut(clk,rst,sw,k1,k2,k4,mode,safe,ready,done,rejected,valid,pending,active,enter,confirm,cancel,focus,blocked,effective);
 always @(posedge clk)begin if(enter)entries++;if(confirm)confirms++;if(cancel)cancels++;end
 task cycles(input integer n);repeat(n)@(negedge clk);endtask
 task next_key;begin k2=0;cycles(50);k2=1;cycles(50);end endtask
 task previous_key;begin k1=0;cycles(50);k1=1;cycles(50);end endtask
 initial begin
  cycles(4);rst=0;cycles(100);
  if(!pending || active || !blocked)$fatal(1,"boot high must wait for transaction");
  k4=0;safe=1;cycles(100);
  if(!active || confirms!=0)$fatal(1,"held key on entry");
  k4=1;cycles(100);previous_key();if(focus!=3)$fatal(1,"previous wrap");
  next_key();if(focus!=0)$fatal(1,"next wrap");
  valid=14;k4=0;cycles(1500);k4=1;cycles(100);
  if(confirms!=0 || !active)$fatal(1,"unavailable confirm/long press");
  next_key();k4=0;cycles(100);
  if(confirms!=1 || effective!=0 || !active)$fatal(1,"confirmation");
  done=1;cycles(3);done=0;cycles(100);
  if(active || !blocked)$fatal(1,"handover held key");
  k4=1;cycles(100);if(blocked)$fatal(1,"release rearm");
  cycles(1500);if(entries!=1)$fatal(1,"held SW3 repeated");
  mode=2;cycles(3);if(effective!=2)$fatal(1,"actual switch change override");
  sw=0;cycles(100);sw=1;cycles(100);
  if(!active || entries!=2)$fatal(1,"reentry");
  sw=0;cycles(100);if(cancels!=1 || !active)$fatal(1,"cancel request");
  done=1;cycles(3);done=0;cycles(100);
  if(active || effective!=2 || blocked)$fatal(1,"cancel restore");
  $display("PASS menu UI: boot/busy, key release, focus wrap, invalid scene, long press, confirm/cancel, SW edge, switch override");$finish;
 end
endmodule
