`timescale 1ns/1ps
module tb_reply_pipeline;
 reg clk=0,rst=1,rx_valid=0,framing=0;
 reg [7:0] rx_data=0;
 reg [1:0] ready_mode=0;
 integer cycle=0,transfers=0,stalls=0;
 wire valid,last,old_valid,old_last;
 wire [7:0] data,old_data;
 wire ready=(ready_mode==2) || (ready_mode==1 && cycle%11<5);
 always #5 clk=~clk;
 always @(negedge clk)cycle=cycle+1;
 subtitle_uart_controller dut(.clk(clk),.rst(rst),.rx_data(rx_data),.rx_valid(rx_valid),
  .rx_framing_error(framing),.cfg_text(),.cfg_length(),.cfg_enable(),.cfg_update_valid(),
  .reply_valid(valid),.reply_data(data),.reply_last(last),.reply_ready(ready));
 // Both implementations consume exactly the same accepted beats. The old
 // combinational producer may assert valid earlier than the prepared producer.
 subtitle_uart_controller_reference ref_dut(.clk(clk),.rst(rst),.rx_data(rx_data),.rx_valid(rx_valid),
  .rx_framing_error(framing),.cfg_text(),.cfg_length(),.cfg_enable(),.cfg_update_valid(),
  .reply_valid(old_valid),.reply_data(old_data),.reply_last(old_last),.reply_ready(ready && valid));
 string received="";
 reg was_stalled=0;reg [8:0] held;
 always @(posedge clk)begin
  if(rst)was_stalled=0;
  else begin
   if(was_stalled && (!valid || {last,data}!==held))$fatal(1,"reply changed under backpressure");
   if(valid && ready)begin
    if(!old_valid || {last,data}!=={old_last,old_data})$fatal(1,"accepted reply differs from baseline");
    received={received,data};transfers++;
   end
   was_stalled=valid && !ready;held={last,data};if(was_stalled)stalls++;
   #1;
   if({dut.cfg_text,dut.cfg_length,dut.cfg_enable,dut.cfg_update_valid} !==
      {ref_dut.cfg_text,ref_dut.cfg_length,ref_dut.cfg_enable,ref_dut.cfg_update_valid})
    $fatal(1,"configuration timing changed");
  end
 end
 task send(input string s);
  begin
   for(integer i=0;i<s.len();i++)begin @(negedge clk);rx_valid=1;rx_data=s[i];end
   @(negedge clk);rx_valid=0;
  end
 endtask
 task drain(input string expected);
  begin
   wait(!dut.active && !dut.pending);repeat(3)@(negedge clk);
   if(received!=expected)$fatal(1,"reply <%s> expected <%s>",received,expected);
   received="";
  end
 endtask
 initial begin
  repeat(3)@(negedge clk);rst=0;
  send("SUB=AB\n");send("SUB?\n");send("SUB=CD\n");send("SUB?\n");
  ready_mode=1;drain("OK\015\nERR\015\n");
  send("SUB?\n");drain("SUB=1,02,4344\015\n");
  ready_mode=0;send("SUB?\n");send("SUB=EF\n");
  ready_mode=1;drain("SUB=1,02,4344\015\nOK\015\n");
  ready_mode=2;
  send("SUB=abcdefghijkl\n");drain("OK\015\n");
  send("SUB?\n");drain("SUB=1,0C,4142434445464748494A4B4C\015\n");
  send("SUB=\n");drain("OK\015\n");send("SUB?\n");drain("SUB=1,00,\015\n");
  ready_mode=0;send("SUB?\n");send("SUB=OFF\n");repeat(3)@(negedge clk);
  rst=1;repeat(3)@(negedge clk);rst=0;ready_mode=2;
  repeat(5)@(negedge clk);if(valid || dut.pending)$fatal(1,"reset retained reply");
  send("BAD\n");drain("ERR\015\n");
  if(transfers<100 || stalls<20)$fatal(1,"insufficient handshake coverage");
  $display("PASS reply pipeline: %0d accepted bytes, %0d stalled cycles; baseline beats, snapshot, overflow ERR, lengths 0/2/12, always-ready and reset",transfers,stalls);
  $finish;
 end
 initial begin #1000000;$fatal(1,"watchdog");end
endmodule
