`timescale 1ns/1ps
module tb_thumbnail_memory;
 reg clk=0,rst=1,reload=0,advance=0,preview=0,write_en=0;
 reg [20:0] write_address=1600000;
 always #12.5 clk=~clk;
 wire shifted;assign #12 shifted=clk;
 wire init_done,refresh,busy,valid;wire [31:0] data;wire [20:0] address;
 wire sc,ras,cas,we;wire [1:0] ba;wire [10:0] addr;wire [3:0] dm;tri [31:0] dq;
 thumbnail_address generator(clk,rst,reload,advance,preview,8'b01_11_00_10,2'd1,address);
 sdram controller(.Clk(clk),.Clk_sft(shifted),.Rst(rst),
 .Sdr_init_done(init_done),.Sdr_init_ref_vld(refresh),.Sdr_busy(busy),
 .App_wr_en(write_en),.App_wr_addr(write_address),.App_wr_dm(4'd0),.App_wr_din(32'h12345678),
 .App_rd_en(advance),.App_rd_addr(address),.Sdr_rd_en(valid),.Sdr_rd_dout(data),
 .SDRAM_CLK(sc),.SDR_CKE(),.SDR_RAS(ras),.SDR_CAS(cas),.SDR_WE(we),
 .SDR_BA(ba),.SDR_ADDR(addr),.SDR_DM(dm),.SDR_DQ(dq));
 sdram_bl4_model memory(.clk(sc),.ras(ras),.cas(cas),.we(we),.ba(ba),.addr(addr),.dm(dm),.dq(dq));
 integer issued=0,received=0,expected_address,ox,oy,image_id,bank;
 integer map[0:3];
 function [31:0] pattern(input integer a);pattern=32'ha5000000 ^ (a*32'd7919);endfunction
 always @(posedge clk) begin
  if(advance) issued=issued+1;
  if(valid)begin
   ox=received%640;oy=received/640;
   image_id=(oy/240)*2+ox/320;bank=preview?map[image_id]:1;
   expected_address=bank*307200+(preview?((oy%240)*2*640+(ox%320)*2):(oy*640+ox));
   if(data!==pattern(expected_address))$fatal(1,"SDRAM preview=%0d pixel=%0d addr=%0d got=%h expected=%h",preview,received,expected_address,data,pattern(expected_address));
   received=received+1;
  end
 end
 task frame(input bit mode);
  integer b,j;
  begin
   @(negedge clk);preview=mode;reload=1;issued=0;received=0;
   @(negedge clk);reload=0;
   for(b=0;b<4800;b=b+1)begin
    while(busy || refresh)@(negedge clk);
    advance=1;repeat(64)@(negedge clk);advance=0;
    repeat(12)@(negedge clk);
    if(mode && b%100==0)begin
     while(busy || refresh)@(negedge clk);
     write_address=1600000;write_en=1;
     repeat(64)begin @(negedge clk);write_address=write_address+1;end
     write_en=0;repeat(12)@(negedge clk);
    end
   end
   wait(received==307200);
   $display("PASS physical SDRAM mode=%0d pixels=%0d refresh=%0d",mode,received,memory.refresh_count);
  end
 endtask
 initial begin
  map[0]=2;map[1]=0;map[2]=3;map[3]=1;
  // Deterministic fixture initialization of the physical command/DQ model.
  for(integer i=0;i<2097152;i=i+1) begin
   integer a;
   a=i;
   if(i>=1228800 && i<1536000)
    a=((i-1228800)/76800)*307200+(((i-1228800)%76800)/320)*1280+((i-1228800)%320)*2;
   memory.memory[(i & ~1023) | ((i & 12)<<6) | ((i & 1008)>>2) | (i & 3)]=pattern(a);
  end
  repeat(5)@(negedge clk);rst=0;wait(init_done);repeat(20)@(negedge clk);
  frame(0);frame(1);
  for(integer i=1600000;i<1600064;i=i+1)
   if(memory.memory[(i & ~1023)|((i & 12)<<6)|((i & 1008)>>2)|(i & 3)]!==32'h12345678)$fatal(1,"background write");
  $display("PASS thumbnail physical memory suite including 48 interleaved write bursts");$finish;
 end
 initial begin #100000000;$fatal(1,"watchdog");end
endmodule
