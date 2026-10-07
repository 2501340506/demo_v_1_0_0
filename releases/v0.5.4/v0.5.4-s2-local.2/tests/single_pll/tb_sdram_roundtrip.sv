`timescale 1ns/1ps
module tb_sdram_roundtrip;
reg clk=0,rst=1;
always #12.5 clk=~clk;
wire shifted;assign #12 shifted=clk;
wire done,busy,refbusy,sc,ras,cas,we,rvalid;
wire [31:0] rdata;tri[31:0]dq;wire[10:0]addr;wire[1:0]ba;wire[3:0]dm;
reg wr=0,rd=0;reg[20:0]wa=0,ra=0;reg[31:0]wd=0;
sdram dut(.Clk(clk),.Clk_sft(shifted),.Rst(rst),.Sdr_init_done(done),.Sdr_init_ref_vld(refbusy),.Sdr_busy(busy),
 .App_wr_en(wr),.App_wr_addr(wa),.App_wr_dm(4'b0),.App_wr_din(wd),.App_rd_en(rd),.App_rd_addr(ra),.Sdr_rd_en(rvalid),.Sdr_rd_dout(rdata),
 .SDRAM_CLK(sc),.SDR_CKE(),.SDR_RAS(ras),.SDR_CAS(cas),.SDR_WE(we),.SDR_BA(ba),.SDR_ADDR(addr),.SDR_DM(dm),.SDR_DQ(dq));
integer commands=0,returns=0;
sdram_bl4_model memory(.clk(sc),.ras(ras),.cas(cas),.we(we),.ba(ba),.addr(addr),.dm(dm),.dq(dq));
always @(posedge sc) if({ras,cas,we}!==3'b111 && commands<90) begin
 $display("CMD time=%0t cmd=%b bank=%d addr=%h dq=%h",$time,{ras,cas,we},ba,addr,dq);commands=commands+1;
end
always @(posedge clk) if(rvalid) begin
 if(rdata !== 32'h12340000+returns)$fatal(1,"READ n=%0d data=%h",returns,rdata);
 returns=returns+1;
end
initial begin
 repeat(8)@(negedge clk);rst=0;wait(done);repeat(30)@(negedge clk);
 for(integer n=0;n<64;n=n+1)begin @(negedge clk);wr=1;wa=n;wd=32'h12340000+n;end
 @(negedge clk);wr=0;repeat(120)@(negedge clk);
 for(integer n=0;n<64;n=n+1)begin @(negedge clk);rd=1;ra=n;end
 @(negedge clk);rd=0;repeat(120)@(negedge clk);
 if(returns!=64)$fatal(1,"missing returns");
 $display("PASS DQ roundtrip returns=%0d",returns);$finish;
end
initial begin #10000000;$fatal(1,"timeout");end
endmodule
