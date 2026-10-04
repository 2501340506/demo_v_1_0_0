`timescale 1ns/1ps
// Reproduces two existing protocol gaps; PASS means the defect was observed,
// not that recovery works. No board RTL is changed by this diagnostic.
module tb_sd_recovery_gaps;
 reg clk=0,rst=1,cmd_req=0,read_req=0,ack=0;
 always #5 clk=~clk;
 reg [7:0] rx=8'hff;
 wire req,cmd_ack,error,read_ack,cs;
 wire [7:0] tx;
 sd_card_cmd dut(.sys_clk(clk),.rst(rst),.spi_clk_div(16'd248),
 .cmd_req(cmd_req),.cmd_req_ack(cmd_ack),.cmd_req_error(error),
 .cmd({8'd0,32'd0,8'h95}),.cmd_r1(8'h01),.cmd_data_len(16'd0),
 .block_read_req(read_req),.block_read_req_ack(read_ack),.block_read_data(),.block_read_valid(),
 .block_write_req(1'b0),.block_write_data(8'd0),.block_write_data_rd(),.block_write_req_ack(),
 .nCS_ctrl(cs),.clk_div(),.spi_wr_req(req),.spi_wr_ack(ack),.spi_data_in(tx),.spi_data_out(rx));
 integer pause_count=0,command_bytes=0,token_polls=0;
 reg bad_first=0;
 // Byte-level SPI completion model, with programmable MISO return bytes.
 always @(negedge clk) begin
  ack=0;
  if(rst) pause_count=0;
  else if(pause_count>0) pause_count=pause_count-1;
  else if(req) begin
   ack=1;pause_count=3;rx=8'hff;
   if(dut.state==dut.S_CMD) begin
    command_bytes=command_bytes+1;
    if(bad_first && command_bytes==1) rx=8'h00;
   end
   if(dut.state==dut.S_READ_WAIT) token_polls=token_polls+1;
  end
 end
 initial begin
  repeat(3) @(posedge clk);#1;rst=0;
  wait(dut.state==dut.S_WAIT);@(posedge clk);#1;bad_first=1;cmd_req=1;
  wait(cmd_ack);#1;
  if(!error || command_bytes!=1) $fatal(1,"expected early command response parsing defect");
  $display("PASS REPRO existing bug: CMD0 aborted after %0d of 6 command bytes when MISO returned 00",command_bytes);
  rst=1;cmd_req=0;bad_first=0;
  repeat(3) @(posedge clk);#1;rst=0;
  wait(dut.state==dut.S_WAIT);@(posedge clk);#1;read_req=1;
  wait(token_polls==2000);@(posedge clk);#1;
  if(dut.state!=dut.S_READ_WAIT || read_ack) $fatal(1,"unexpected token-wait exit");
  $display("PASS REPRO existing gap: 2000 FF token polls, still waiting with no read failure/completion output");
  $finish;
 end
 initial begin #1000000;$fatal(1,"test timeout");end
endmodule
