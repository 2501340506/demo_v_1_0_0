`timescale 1ns/1ps
// Real production mailbox/blank commit. A bank is acknowledged after VS;
// metadata must arrive before that frame's first active pixel, never next VS.
module tb_identity_blank;
 reg clk=0,pix=0,rst=1,fs=0,de=0,update=0;
 reg [15:0] bundle=0;
 always #5 clk=~clk;
 always #7 pix=~pix;
 top dut(.clk(clk),.rst_n(!rst),.key1(1'b1),.key2(1'b1),.key4(1'b1),
  .sw1(1'b0),.sw2(1'b0),.sd_miso(1'b1),.uart_rx(1'b1));
 initial begin
  force dut.video_clk=pix;force dut.rst_video=rst;
  force dut.rst_sd=1;force dut.rst_mem=1;force dut.rst_panel=1;
  force dut.sub_frame_start=fs;force dut.de=de;
  force dut.audio_update=update;force dut.committed_bundle=bundle;
 end
 task cycles(input integer n);repeat(n)@(negedge pix);endtask
 task publish(input [7:0] kind,input [5:0] identity);
  begin bundle={kind,identity,2'b00};update=1;cycles(1);update=0;cycles(3);end
 endtask
 initial begin
  cycles(4);rst=0;fs=1;cycles(1);fs=0;cycles(5);
  publish(8'h21,6'h16); // reader ack arrives AFTER the VS edge
  if(dut.pixel_kind!==8'h21 || dut.pixel_identity!==6'h16)$fatal(1,"bank type missed its own blank");
  de=1;cycles(30);de=0;cycles(10); // horizontal blank cannot change identity
  publish(8'h43,6'h22);
  if(dut.pixel_kind!==8'h21)$fatal(1,"type changed within an active frame");
  de=1;cycles(10);de=0;fs=1;cycles(1);fs=0;cycles(3);
  if(dut.pixel_kind!==8'h43 || dut.pixel_identity!==6'h22)$fatal(1,"queued type lost at blank");
  // Failed loads publish no mailbox: preserve displayed metadata over frames.
  repeat(3)begin de=1;cycles(30);de=0;fs=1;cycles(1);fs=0;cycles(5);end
  if(dut.pixel_kind!==8'h43)$fatal(1,"uncommitted load changed type");
  $display("PASS identity blank: same-frame bank/type, horizontal hold, queued blank, failure hold");$finish;
 end
 initial begin #100000;$fatal(1,"watchdog");end
endmodule
