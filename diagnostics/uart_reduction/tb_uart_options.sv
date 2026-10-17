`timescale 1ns/1ps
module tb_uart_options #(parameter LOG=0, SUB=0);
 reg clk=0,pix=0,rst=1,rx=1,vs=1,de=0,update=0;
 always #5 clk=~clk;
 always #7 pix=~pix;
 wire tx;
 top #(.UART_LOG_ENABLE(LOG),.UART_SUBTITLE_ENABLE(SUB),
       .UART_CLK_FREQ_HZ(160000),.UART_BAUD_RATE(10000)) dut(
 .clk(clk),.rst_n(!rst),.key1(1'b1),.key2(1'b1),.key4(1'b1),
 .sw1(1'b0),.sw2(1'b0),.sd_miso(1'b1),.uart_rx(rx),.uart_tx(tx));
 integer tx_starts=0,frames=0;
 always @(negedge tx)if(!rst)tx_starts++;
 always @(posedge pix)if(!rst && dut.sub_frame_start)frames++;
 always @(negedge clk)if(!rst && !LOG && tx!==1'b1)$fatal(1,"disabled TX must stay idle");
 initial begin
 force dut.sd_card_clk=clk;force dut.video_clk=pix;
 force dut.rst_sd=rst;force dut.rst_video=rst;force dut.rst_panel=rst;
 force dut.rst_mem=1;force dut.rst_serial=1;
 force dut.hs=1;force dut.vs=vs;force dut.de=de;force dut.video_x=0;
 force dut.uart_diagnostics=0;force dut.sd_debug=64'h123456789abcdef0;
 force dut.audio_update=update;force dut.committed_bundle=8'h94;
 end
 task send_byte(input [7:0] value);
 begin
  @(negedge clk);rx=0;repeat(16)@(negedge clk);
  for(integer j=0;j<8;j++)begin rx=value[j];repeat(16)@(negedge clk);end
  rx=1;repeat(20)@(negedge clk);
 end endtask
 task send(input string command);
 begin for(integer j=0;j<command.len();j++)send_byte(command[j]);end endtask
 task frame;
 begin
  @(negedge pix);vs=0;de=0;repeat(4)@(negedge pix);vs=1;
  repeat(8)@(negedge pix);de=1;repeat(4)@(negedge pix);de=0;
  repeat(30)@(negedge pix);
 end endtask
 initial begin
  #101;rst=0;repeat(20)@(negedge clk);
  if(dut.sd_debug_panel1!==64'h123456789abcdef0 ||
     dut.seg7_panel_m0.sd_debug!==64'h123456789abcdef0)$fatal(1,"SD debug panel lost");
  // Let the optional boot log finish, then drive actual serial command bytes.
  repeat(5000)@(negedge clk);
  send("SUB=ab\n");repeat(100)@(negedge clk);frame();frame();
  if(SUB)begin
   if(!dut.sub_enable_pixel || dut.sub_length_pixel!=2 || dut.sub_text_pixel[15:0]!==16'h4241)
    $fatal(1,"subtitle command/CDC not restored");
  end else if({dut.sub_enable_pixel,dut.sub_length_pixel,dut.sub_text_pixel,dut.sub_text_changed}!==126'd0)
    $fatal(1,"RX changed disabled subtitle state");
  @(negedge pix);update=1;@(negedge pix);update=0;
  repeat(4)@(negedge pix);
  if(dut.pixel_identity!==0)$fatal(1,"identity committed before frame");
  frame();
  if(dut.pixel_identity!==6'h25 || frames!=3)$fatal(1,"shared frame/identity commit lost");
  repeat(10000)@(negedge clk);
  if(LOG && tx_starts==0)$fatal(1,"logger not restored");
  if(!LOG && dut.sub_reply_ready!==1'b1)$fatal(1,"disabled logger blocks subtitle receiver");
  @(negedge clk);rst=1;repeat(4)@(negedge clk);rst=0;frame();
  if(!SUB && dut.sub_enable_pixel!==0)$fatal(1,"disabled subtitle reset");
  $display("PASS UART options LOG=%0d SUB=%0d: serial command, idle/boot TX, SD debug panel, shared frame/identity commit, reset",LOG,SUB);
  $finish;
 end
 initial begin #10000000;$fatal(1,"UART options watchdog");end
endmodule
