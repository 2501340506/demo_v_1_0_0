`timescale 1ns/1ps
module tb_sd_initialization;
reg clk=0,rst=1,sd_sec_read=0,card_present=0;
wire sd_init_done,sd_init_failed,sd_sec_read_failed,sd_sec_read_end;
wire SD_nCS,SD_DCLK,SD_MOSI;
wire [15:0] sd_debug;
reg ack=0; reg [7:0] rx=255;
integer gap=0,cmd16_count=0,card_commands=0;
always #5 clk=~clk;
sd_card_top #(.CLK_FREQ_HZ(1000),.SPI_LOW_SPEED_DIV(0)) dut(
 .clk(clk),.rst(rst),.SD_nCS(SD_nCS),.SD_DCLK(SD_DCLK),.SD_MOSI(SD_MOSI),.SD_MISO(1'b1),
 .sd_debug(sd_debug),.sd_init_done(sd_init_done),.sd_init_failed(sd_init_failed),.sd_sec_read_failed(sd_sec_read_failed),
 .sd_sec_read(sd_sec_read),.sd_sec_read_addr(32'd0),.sd_sec_read_data(),.sd_sec_read_data_valid(),
 .sd_sec_read_end(sd_sec_read_end),.sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),
 .sd_sec_write_data(8'd0),.sd_sec_write_data_req(),.sd_sec_write_end());
// Card-side state is deliberately independent of host reset.
always @(negedge clk) begin
 ack=0;
 if(gap>0) gap=gap-1;
 else if(dut.spi_wr_req && !dut.protocol_rst) begin
  gap=3;ack=1;rx=255;
  if(card_present && dut.sd_card_cmd_m0.state==dut.sd_card_cmd_m0.S_CMD) begin
   if(dut.sd_card_cmd_m0.byte_cnt==0) begin
    card_commands=card_commands+1;
    if(dut.cmd[45:40]==16) cmd16_count=cmd16_count+1;
   end
   if(dut.sd_card_cmd_m0.byte_cnt>=6)
    case(dut.cmd[45:40])
     0,8,55: rx=1;
     41,16: rx=0;
     default: rx=255;
    endcase
  end
 end
end
always @(posedge clk) if(sd_init_done && cmd16_count==0) $fatal(1,"early init_done");
initial begin
 force dut.spi_wr_ack=ack; force dut.spi_data_out=rx;
 repeat(4) @(negedge clk);rst=0;
 wait(sd_init_failed);repeat(4) @(negedge clk);
 if(sd_init_done || !SD_nCS || !SD_MOSI) $fatal(1,"init failure not idle");
 if(sd_debug!==16'h00ff) $fatal(1,"CMD0 timeout diagnostic must survive protocol reset: %h",sd_debug);
 card_present=1;rst=1;repeat(4) @(negedge clk);rst=0;
 wait(sd_init_done);@(negedge clk);
 if(sd_debug!==16'h1000) $fatal(1,"CMD16 success diagnostic: %h",sd_debug);
 if(dut.sd_card_sec_read_write_m0.state!=dut.sd_card_sec_read_write_m0.S_WAIT_READ_WRITE)
  $fatal(1,"init not ready for read");
 sd_sec_read=1;repeat(2) @(negedge clk);sd_sec_read=0;
 wait(sd_sec_read_failed);if(sd_sec_read_end) $fatal(1,"failed read reported success");
 rst=1;repeat(4) @(negedge clk);rst=0;
 wait(sd_init_done);
 if(cmd16_count!=2) $fatal(1,"card state/reset test");
 $display("PASS initialization deadline, readiness, read failure, host-only reinitialization");$finish;
end
initial begin #100000;$fatal(1,"watchdog");end
endmodule
