`timescale 1ns/1ps
`include "global_def.v"
module tb_refresh_service;
reg clk=0,rst=1;
always #12.5 clk=~clk;
wire shifted;assign #12 shifted=clk;
wire done,refbusy,busy,sc,ras,cas,we;
wire [1:0] ba;wire[10:0] addr;wire[3:0]dm;tri[31:0] dq;
wire wr,rd;wire[20:0] wa,ra;
reg wreq=0,rreq=0;wire wack,rack,wb,rb;reg[9:0] supply=0,occupied=511;
frame_fifo_write #(.BURST_SIZE(256)) writer(.rst(rst),.mem_clk(clk),.Sdr_init_done(done),.Sdr_init_ref_vld(refbusy),.Sdr_busy(busy),.App_rd_busy(rb),.O_wr_busy(wb),.App_wr_en(wr),.App_wr_addr(wa),.write_cancel_req(1'b0),.write_cancel_ack(),.write_req(wreq),.write_req_ack(wack),.write_finish(),.write_addr_0(21'd0),.write_addr_1(21'd0),.write_addr_2(21'd0),.write_addr_3(21'd0),.write_addr_index(2'd0),.write_len(21'd307200),.fifo_aclr(),.rdusedw(supply));
frame_fifo_read #(.BURST_SIZE(256)) reader(.rst(rst),.mem_clk(clk),.Sdr_init_done(done),.Sdr_init_ref_vld(refbusy),.Sdr_busy(busy),.Sdr_rd_en(1'b0),.App_wr_busy(wb),.O_rd_busy(rb),.App_rd_en(rd),.App_rd_addr(ra),.read_req(rreq),.display_commit_request(1'b0),.display_commit_ack(),.read_req_ack(rack),.read_finish(),.read_addr_0(21'd524288),.read_addr_1(21'd0),.read_addr_2(21'd0),.read_addr_3(21'd0),.read_addr_index(2'd0),.read_len(21'd307200),.fifo_aclr(),.wrusedw(occupied));
// Occupancy is stimulus, not a FIFO/data model. Burst enables and arbitration
// come from the unmodified production controllers.
integer phase=0,violations=0,writes=0,reads=0;
always @(posedge clk) begin if(wr)writes=writes+1;if(rd)reads=reads+1;end
sdr_as_ram dut(.Sdr_clk(clk),.Sdr_clk_sft(shifted),.Rst(rst),.Sdr_init_done(done),.Sdr_init_ref_vld(refbusy),.Sdr_busy(busy),.App_ref_req(1'b0),.App_wr_en(wr),.App_wr_addr(wa),.App_wr_dm(4'b0),.App_wr_din(32'h12345678),.App_rd_en(rd),.App_rd_addr(ra),.Sdr_rd_en(),.Sdr_rd_dout(),.SDRAM_CLK(sc),.SDR_RAS(ras),.SDR_CAS(cas),.SDR_WE(we),.SDR_BA(ba),.SDR_ADDR(addr),.SDR_DM(dm),.SDR_DQ(dq));
integer cycles=0,last_ref=0,refs=0,max_gap=0;
always @(posedge sc) begin
 cycles=cycles+1;
 if(done && {ras,cas,we}===3'b001) begin
  if(refs>0) begin
   if(cycles-last_ref>max_gap) max_gap=cycles-last_ref;
   if(cycles-last_ref>1250) begin violations=violations+1; if(violations<12) $display("VIOLATION phase=%0d refresh_gap_cycles=%0d",phase,cycles-last_ref);end
  end
  last_ref=cycles;refs=refs+1;
 end
end
initial begin
 $display("MACRO period=%0d terminal=%0d",`SDR_CLK_PERIOD,`SELF_REFRESH_INTERVAL);
 repeat(8) @(negedge clk);rst=0;
 wait(done);$display("INIT done_at_ns=%0.3f",$realtime);
 repeat(10000) @(negedge clk);
 $display("IDLE refs=%0d max_gap_cycles=%0d",refs,max_gap);
 @(negedge clk);wreq=1;rreq=1;
 wait(wack && rack);@(negedge clk);wreq=0;rreq=0;
 for(integer n=0;n<120000;n=n+1) begin
  @(negedge clk);phase=1+n/40000;
  supply=(phase==1 || (phase==3 && n%1200<600))?511:0;
  occupied=(phase==2 || phase==3)?0:511;
 end
 supply=0;occupied=511;repeat(3000) @(negedge clk);
 $display("RESULT refs=%0d max_gap_cycles=%0d writes=%0d reads=%0d violations=%0d",refs,max_gap,writes,reads,violations);
 if(refs<35 || max_gap>1250) $fatal(1,"refresh deadline or missing refresh");
 $display("PASS refresh service");$finish;
end
initial begin #10000000;$fatal(1,"timeout");end
endmodule
