`timescale 1ns/1ps
module tb_sd_init_retry;
reg clk=0,rst=1,sd_sec_read=0,card_present=0;
wire sd_init_done,sd_init_failed,sd_sec_read_failed,sd_sec_read_end;
wire SD_nCS,SD_DCLK,SD_MOSI;
wire [63:0] sd_debug;
reg ack=0; reg [7:0] rx=255;
integer gap=0,cmd16_count=0,cmd59_count=0,card_commands=0;
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
    if(dut.cmd[45:40]==59) cmd59_count=cmd59_count+1;
   end
   if(dut.sd_card_cmd_m0.byte_cnt>=6)
    case(dut.cmd[45:40])
     0,8,55: rx=1;
     41,16,59: rx=0;
     default: rx=255;
    endcase
  end
 end
end
always @(posedge clk) if(sd_init_done && (cmd16_count==0 || cmd59_count==0)) $fatal(1,"early init_done");
integer retries=0, startup_bytes=0;
reg prev_recovery=0;
always @(posedge clk) if(!rst)begin
 if(dut.sd_init_recovery && !prev_recovery)retries++;
 prev_recovery<=dut.sd_init_recovery;
 if(dut.sd_init_recovery && (!SD_nCS || !SD_MOSI))$fatal(1,"recovery pins");
 if(ack && dut.sd_card_cmd_m0.state==dut.sd_card_cmd_m0.S_INIT)begin
  if(!SD_nCS || dut.spi_data_in!=255)$fatal(1,"startup clocks not deselected FF");
  startup_bytes++;
 end
end else prev_recovery<=0;
initial begin
 force dut.spi_wr_ack=ack;force dut.spi_data_out=rx;
 repeat(4)@(negedge clk);rst=0;
 wait(sd_init_failed);repeat(8)@(negedge clk);
 if(retries!=3 || startup_bytes!=44 || sd_init_done)$fatal(1,"retry bound %d bytes %d",retries,startup_bytes);
 repeat(3000)@(negedge clk);
 if(retries!=3 || !sd_init_failed)$fatal(1,"failure not sticky");
 // No response first attempt, card becomes responsive during recovery.
 rst=1;repeat(4)@(negedge clk);rst=0;retries=0;startup_bytes=0;
 wait(dut.sd_init_recovery);@(negedge clk);card_present=1;
 wait(sd_init_done);@(negedge clk);
 if(sd_init_failed || retries!=1 || startup_bytes!=22)$fatal(1,"automatic recovery did not restart full initialization");
 if(cmd16_count!=1 || cmd59_count!=1)$fatal(1,"early readiness");
 $display("PASS bounded initialization recovery: three retries then stop; automatic recovery with 88 startup clocks per attempt");$finish;
end
initial begin #400000;$fatal(1,"retry watchdog");end
endmodule
