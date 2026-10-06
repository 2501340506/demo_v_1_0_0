`timescale 1ns/1ps
module tb_sd_protocol;
reg clk=0,rst=1,cmd_req=0,read_req=0,ack=0;
always #5 clk=~clk;
reg [7:0] rx=8'hff;
wire req,cmd_ack,error,read_ack,read_error,cs;
wire [7:0] tx;
wire [47:0] read_debug;
integer gap=0, bytes=0, payload=0, idle_bytes=0;
integer scenario=0;
sd_card_cmd #(.CLK_FREQ_HZ(1000)) dut(
 .sys_clk(clk),.rst(rst),.spi_clk_div(16'd248),
 .read_debug(read_debug),.cmd_response(),.cmd_req(cmd_req),.cmd_req_ack(cmd_ack),.cmd_req_error(error),
 .cmd({8'd0,32'd0,8'h95}),.cmd_r1(8'h01),.cmd_data_len(16'd0),
 .block_read_req(read_req),.block_read_req_ack(read_ack),.block_read_error(read_error),
 .block_read_data(),.block_read_valid(),.block_write_req(1'b0),.block_write_data(8'd0),
 .block_write_data_rd(),.block_write_req_ack(),.nCS_ctrl(cs),.clk_div(),
 .spi_wr_req(req),.spi_wr_ack(ack),.spi_data_in(tx),.spi_data_out(rx));
always @(negedge clk) begin
 ack=0;
 if(rst) gap=0;
 else if(gap>0) gap=gap-1;
 else if(req) begin
  ack=1;gap=3;rx=8'hff;
  if(dut.state==dut.S_INIT) begin
   if(!cs || tx!=8'hff) $fatal(1,"idle clocks not CS/MOSI high");
   idle_bytes=idle_bytes+1;
  end
  if(dut.state==dut.S_CMD) begin
   if(dut.byte_cnt<6) begin bytes=bytes+1; rx=0; end
   else if(scenario!=1) rx=1;
  end
  if(dut.state==dut.S_READ_WAIT && scenario!=2) rx=8'hfe;
  if(dut.state==dut.S_READ) begin
   // SD CRC16 of 512 bytes of FF is 7FA1 (independent known vector).
   if(scenario==4) begin
    if(dut.byte_cnt==512) rx=8'h7f;
    else if(dut.byte_cnt==513) rx=8'ha1;
    else rx=8'hff;
   end else rx=(scenario==3 && dut.byte_cnt==513) ? 8'h01 : 8'h00;
   payload=payload+1;
  end
 end
end
task reset_host;
begin
 @(posedge clk); #1;rst=1;cmd_req=0;read_req=0;bytes=0;payload=0;idle_bytes=0;
 repeat(3) @(posedge clk); #1;rst=0;
 wait(dut.state==dut.S_WAIT); @(posedge clk); #1;
 if(idle_bytes<10) $fatal(1,"less than 80 clocks");
end endtask
task command(input integer kind);
begin
 scenario=kind;cmd_req=1;wait(cmd_ack);#1;
 if(bytes!=6 || error!=(kind==1)) $fatal(1,"command framing/timeout");
 cmd_req=0;repeat(4) @(posedge clk);#1;
end endtask
task block(input integer kind);
begin
 scenario=kind;read_req=1;wait(read_ack);#1;
 if(read_error!=(kind==2 || kind==3) || !cs) $fatal(1,"read failure/CS");
 if(kind!=2 && payload!=514) $fatal(1,"incomplete sector");
 if(kind==2 && read_debug!==48'h10ff00000000) $fatal(1,"token timeout diagnostic");
 if(kind==3 && read_debug!==48'h220000000001) $fatal(1,"CRC failure diagnostic");
 read_req=0;repeat(4) @(posedge clk);#1;
end endtask
initial begin
 reset_host; command(0);
 reset_host; command(1);
 reset_host; block(2);
 reset_host; block(3);
 reset_host; command(0); block(4);
 $display("PASS full command, response timeout, token timeout, CRC failure and retry");$finish;
end
initial begin #200000;$fatal(1,"watchdog");end
endmodule
