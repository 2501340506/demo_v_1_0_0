`timescale 1ns/1ps
module tb_thumbnail_loader;
 reg clk=0,src=0,rst=1,req=0,cancel=0,put=0,done=0;
 reg [31:0] pixel=0;
 always #12.5 clk=~clk;
 always #5 src=~src;
 wire shifted;assign #12 shifted=clk;
 wire init_done,refresh,busy,valid;wire [31:0] data;
 wire wb,we_app,ready,ack,cack,finish,fault;wire [2:0] code;
 wire [20:0] wa;wire [31:0] wd;
 wire sc,ras,cas,we;wire [1:0] ba;wire [10:0] addr;wire [3:0] dm;tri [31:0] dq;
 media_thumbnail_loader dut(.rst(rst),.mem_clk(clk),.write_clk(src),.write_rst(rst),
 .Sdr_init_done(init_done),.Sdr_init_ref_vld(refresh),.Sdr_busy(busy),.App_rd_busy(1'b0),
 .O_wr_busy(wb),.App_wr_en(we_app),.App_wr_addr(wa),.App_wr_din(wd),.App_wr_dm(),
 .write_req(req),.write_req_ack(ack),.write_cancel_req(cancel),.write_cancel_ack(cack),
 .write_addr_0(21'd0),.write_addr_1(21'd307200),.write_addr_2(21'd614400),.write_addr_3(21'd921600),
 .write_addr_index(2'd2),.write_len(21'd307200),.write_en(put),.write_data(pixel),.write_ready(ready),
 .source_done(done),.source_error(1'b0),.write_finish(finish),.error_toggle(fault),.memory_error(code));
 sdram controller(.Clk(clk),.Clk_sft(shifted),.Rst(rst),
 .Sdr_init_done(init_done),.Sdr_init_ref_vld(refresh),.Sdr_busy(busy),
 .App_wr_en(we_app),.App_wr_addr(wa),.App_wr_dm(4'd0),.App_wr_din(wd),
 .App_rd_en(1'b0),.App_rd_addr(21'd0),.Sdr_rd_en(valid),.Sdr_rd_dout(data),
 .SDRAM_CLK(sc),.SDR_CKE(),.SDR_RAS(ras),.SDR_CAS(cas),.SDR_WE(we),
 .SDR_BA(ba),.SDR_ADDR(addr),.SDR_DM(dm),.SDR_DQ(dq));
 sdram_bl4_model memory(.clk(sc),.ras(ras),.cas(cas),.we(we),.ba(ba),.addr(addr),.dm(dm),.dq(dq));
 function integer physical(input integer a);physical=(a & ~1023)|((a & 12)<<6)|((a & 1008)>>2)|(a & 3);endfunction
 function [31:0] pattern(input integer x,y);pattern={8'ha5,y[7:0],x[7:0],8'h00} ^ (y<<16) ^ (x<<8);endfunction
 integer completions=0;
 always @(posedge clk)begin
  if(finish)completions=completions+1;
  if(code!=0)$fatal(1,"loader memory fault %0d",code);
  if(dut.en==3)$fatal(1,"simultaneous writers");
 end
 task start;
  begin @(negedge src);req=1;wait(ack);repeat(4)@(negedge src);req=0;repeat(12)@(negedge src);end
 endtask
 task send_pixels(input integer count);
  begin
   for(integer i=0;i<count;i=i+1)begin
    @(negedge src);put=0;
    while(!ready)@(negedge src);
    pixel=pattern(i%640,479-i/640);put=1;
   end
   @(negedge src);put=0;
  end
 endtask
 initial begin
  repeat(5)@(negedge clk);rst=0;wait(init_done);
  start();send_pixels(3000);
  @(negedge src);cancel=1;wait(cack);repeat(8)@(negedge src);cancel=0;repeat(20)@(negedge src);
  if(completions!=0)$fatal(1,"cancel committed");
  start();send_pixels(307200);done=1;@(negedge src);done=0;
  wait(completions==1);repeat(20)@(negedge clk);
  for(integer y=0;y<480;y=y+1)for(integer x=0;x<640;x=x+1)
   if(memory.memory[physical(614400+y*640+x)]!==pattern(x,y))$fatal(1,"full pixel %0d %0d",x,y);
  for(integer y=0;y<240;y=y+1)for(integer x=0;x<320;x=x+1)
   if(memory.memory[physical(1382400+y*320+x)]!==pattern(x*2,y*2))$fatal(1,"thumbnail pixel %0d %0d got %h expected %h",x,y,memory.memory[physical(1382400+y*320+x)],pattern(x*2,y*2));
  $display("PASS dual loader: full 307200 and thumbnail 76800 pixels, cancel/reload, backpressure, refresh=%0d",memory.refresh_count);$finish;
 end
 initial begin #200000000;$fatal(1,"watchdog");end
endmodule
