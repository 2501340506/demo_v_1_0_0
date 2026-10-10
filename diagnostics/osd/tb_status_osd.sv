`timescale 1ns/1ps
module tb_status_osd;
 reg clk=0,src_clk=0,rst=1,vs=1,de=0;
 always #20 clk=~clk;
 always #5 src_clk=~src_clk;
 reg [9:0] x=0;
 reg [23:0] rgb=0;
 reg [1:0] idx=0;
 reg valid=0,auto_en=0;
 reg [7:0] err=0;
 wire [23:0] out_rgb,bypass;
 status_osd_overlay dut(.clk(clk),.rst(rst),.vs(vs),.de(de),.pixel_x(x),.rgb_in(rgb),
  .image_index(idx),.image_valid(valid),.auto_enabled(auto_en),.error_code(err),.rgb_out(out_rgb));
 status_osd_overlay #(.OSD_ENABLE(0)) off_dut(.clk(clk),.rst(rst),.vs(vs),.de(de),.pixel_x(x),.rgb_in(rgb),
  .image_index(idx),.image_valid(valid),.auto_enabled(auto_en),.error_code(err),.rgb_out(bypass));
 reg src_auto=0;reg [7:0] src_err=0;
 wire dst_auto;wire [7:0] dst_err;
 osd_status_cdc cdc(.src_clk(src_clk),.src_rst(rst),.src_auto(src_auto),.src_error(src_err),
  .dst_clk(clk),.dst_rst(rst),.dst_auto(dst_auto),.dst_error(dst_err));
 // Independent bitmaps for every character used by the status line.
 function [34:0] bitmap(input [7:0] c);
  case(c)
   "P":bitmap={5'b11110,5'b10001,5'b10001,5'b11110,5'b10000,5'b10000,5'b10000};
   "I":bitmap={5'b01110,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b01110};
   "C":bitmap={5'b01111,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b01111};
   "M":bitmap={5'b10001,5'b11011,5'b10101,5'b10101,5'b10001,5'b10001,5'b10001};
   "A":bitmap={5'b01110,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
   "N":bitmap={5'b10001,5'b11001,5'b10101,5'b10011,5'b10001,5'b10001,5'b10001};
   "U":bitmap={5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
   "T":bitmap={5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100};
   "O":bitmap={5'b01110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
   "E":bitmap={5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b11111};
   "R":bitmap={5'b11110,5'b10001,5'b10001,5'b11110,5'b10100,5'b10010,5'b10001};
   "0":bitmap={5'b01110,5'b10001,5'b10011,5'b10101,5'b11001,5'b10001,5'b01110};
   "1":bitmap={5'b00100,5'b01100,5'b00100,5'b00100,5'b00100,5'b00100,5'b01110};
   "2":bitmap={5'b01110,5'b10001,5'b00001,5'b00010,5'b00100,5'b01000,5'b11111};
   "3":bitmap={5'b11110,5'b00001,5'b00001,5'b01110,5'b00001,5'b00001,5'b11110};
   "4":bitmap={5'b00010,5'b00110,5'b01010,5'b10010,5'b11111,5'b00010,5'b00010};
   ":":bitmap={5'b00000,5'b00100,5'b00100,5'b00000,5'b00100,5'b00100,5'b00000};
   "-":bitmap={5'b00000,5'b00000,5'b00000,5'b11111,5'b00000,5'b00000,5'b00000};
   default:bitmap=0;
  endcase
 endfunction
 integer checks=0;
 task frame(input string expected,input bit red,input bit mid_change);
  integer y,col,cell_id,gx,gy;reg [34:0] bits;reg hit;reg [23:0] want;
  begin
   @(negedge clk);vs=0;de=0;repeat(4)@(negedge clk);vs=1;
   repeat(4)@(negedge clk);
   for(y=0;y<480;y=y+1) begin
    for(col=0;col<640;col=col+1) begin
     @(negedge clk);de=1;x=col;rgb={8'(col),8'(y),8'(col+y)};
     if(mid_change && y==10 && col==100)begin idx=3;auto_en=1;err=3;valid=1;end
     hit=0;
     if(col>=8 && col<280 && y>=8 && y<24) begin
      cell_id=(col-8)/16;gx=((col-8)%16)/2;gy=(y-8)/2;
      bits=bitmap(expected[cell_id]);
      if(gx<5 && gy<7)hit=bits[34-gy*5-gx];
     end
     want=hit?(red?24'hff4444:24'hffff00):rgb;
     #1;
     if(out_rgb!==want)$fatal(1,"OSD pixel x=%0d y=%0d got=%h expected=%h char=%s",col,y,out_rgb,want,expected);
     if(bypass!==rgb)$fatal(1,"bypass changed RGB");
     checks=checks+1;
    end
    @(negedge clk);de=0;x=640;rgb=24'h13579b;#1;
    if(out_rgb!==rgb || bypass!==rgb)$fatal(1,"blanking changed");
    repeat(3)@(negedge clk);
   end
  end
 endtask
 reg [8:0] held_prev;reg request_prev,was_busy;
 always @(negedge src_clk) begin
  if(!rst && was_busy && cdc.held_status!==held_prev)$fatal(1,"CDC changed held bus while busy");
  held_prev=cdc.held_status;request_prev=cdc.request;
  was_busy=!rst && cdc.request!=cdc.ack_sync[1];
 end
 initial begin
  #101;rst=0;
  // Faster changes than the round trip: only the latest state must survive.
  repeat(20)begin @(negedge src_clk);src_auto=~src_auto;src_err=src_err+1;end
  @(negedge src_clk);src_auto=1;src_err=3;
  repeat(20)@(negedge clk);
  if({dst_auto,dst_err}!==9'h103)$fatal(1,"CDC latest state lost");
  @(negedge src_clk);src_auto=0;src_err=0;
  repeat(20)@(negedge clk);
  if({dst_auto,dst_err}!==0)$fatal(1,"CDC clear lost");
  frame("PIC:- MAN  ERR:00",0,0);
  valid=1;idx=0;frame("PIC:1 MAN  ERR:00",0,1);
  frame("PIC:4 AUTO ERR:03",1,0);
  idx=1;err=1;auto_en=0;frame("PIC:2 MAN  ERR:01",1,0);
  idx=2;err=2;frame("PIC:3 MAN  ERR:02",1,0);
  err=0;frame("PIC:3 MAN  ERR:00",0,0);
  $display("PASS status OSD: %0d active pixels, blanking, bypass, frame snapshot and latest-state CDC",checks);
  $finish;
 end
 initial begin #100000000;$fatal(1,"OSD test watchdog");end
endmodule
