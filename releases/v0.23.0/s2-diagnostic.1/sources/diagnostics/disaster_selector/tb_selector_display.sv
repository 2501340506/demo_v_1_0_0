`timescale 1ns/1ps
// Real protected SDRAM/BL4 model and real FIFO read path at 40/25 MHz.
module tb_selector_display;
 parameter CASE_ID=0;
 reg mem_clk=0,pix_clk=0,rst=1;
 always #12.5 mem_clk=~mem_clk;always #20 pix_clk=~pix_clk;
 wire shifted;assign #12 shifted=mem_clk;
 wire init_done,refresh,busy,rd_en,rd_valid,rd_busy;
 wire [20:0] rd_addr;wire [31:0] rd_data;
 wire sc,ras,cas,we;wire [1:0] ba;wire [10:0] addr;wire [3:0] dm;tri [31:0] dq;
 sdram controller(.Clk(mem_clk),.Clk_sft(shifted),.Rst(rst),
  .Sdr_init_done(init_done),.Sdr_init_ref_vld(refresh),.Sdr_busy(busy),
  .App_wr_en(1'b0),.App_wr_addr(21'd0),.App_wr_dm(4'd0),.App_wr_din(32'd0),
  .App_rd_en(rd_en),.App_rd_addr(rd_addr),.Sdr_rd_en(rd_valid),.Sdr_rd_dout(rd_data),
  .SDRAM_CLK(sc),.SDR_CKE(),.SDR_RAS(ras),.SDR_CAS(cas),.SDR_WE(we),
  .SDR_BA(ba),.SDR_ADDR(addr),.SDR_DM(dm),.SDR_DQ(dq));
 sdram_bl4_model memory(.clk(sc),.ras(ras),.cas(cas),.we(we),.ba(ba),.addr(addr),.dm(dm),.dq(dq));
 reg req=1;reg [31:0] desc=32'h15fc00e4;wire ack;
 reg [1:0] bank=1;reg bank_req=0;wire bank_ack;
 reg [1:0] shown_bank=1;
 always @(posedge mem_clk)if(bank_req==bank_ack)shown_bank<=bank;
 wire [31:0] pixel_desc,pixel_data;wire read_req,read_ack,consume,read_finish,underflow;
 wire [2:0] reader_error;wire hs0,vs0,de0,hs,vs,de;wire [9:0] x0,x;wire [23:0] rgb;
 video_timing_data timing(.video_clk(pix_clk),.rst(rst),.read_req(read_req),.read_req_ack(read_ack),
  .hs(hs0),.vs(vs0),.de(de0),.video_x(x0));
 video_delay delay_path(.video_clk(pix_clk),.rst(rst),.read_en(consume),.read_data(pixel_data[31:8]),
  .hs(hs0),.vs(vs0),.de(de0),.video_x(x0),.hs_r(hs),.vs_r(vs),.de_r(de),.vout_data(rgb),.video_x_r(x));
 media_frame_reader #(.PREVIEW_ENABLE(1),.MENU_ENABLE(1),.DESC_WIDTH(32)) reader(
  .rst(rst),.mem_clk(mem_clk),.read_clk(pix_clk),.read_rst(rst),
  .Sdr_init_done(init_done),.Sdr_init_ref_vld(refresh),.Sdr_busy(busy),.App_wr_busy(1'b0),
  .O_rd_busy(rd_busy),.App_rd_en(rd_en),.App_rd_addr(rd_addr),.refill_priority(),
  .Sdr_rd_en(rd_valid),.Sdr_rd_dout(rd_data),.read_req(read_req),.read_req_ack(read_ack),.read_finish(read_finish),
  .preview_request(req),.preview_descriptor(desc),.preview_ack(ack),.pixel_descriptor(pixel_desc),
  .display_commit_request(bank_req),.display_commit_ack(bank_ack),
  .read_addr_0(21'd0),.read_addr_1(21'd307200),.read_addr_2(21'd614400),.read_addr_3(21'd921600),
  .read_addr_index(bank),.read_len(21'd307200),.read_en(consume),.display_valid(init_done),
  .read_data(pixel_data),.underflow(underflow),.reader_error(reader_error));
 function [31:0] pattern(input integer kind,tile,col,row);
  pattern={8'(32+kind*64+tile*12),8'(row),8'(col),8'hff};
 endfunction
 function [23:0] color(input integer kind,tile,col,row);
  color={8'(32+kind*64+tile*12),8'(row),8'(col)};
 endfunction
 function integer physical(input integer a);
  physical=(a & ~1023)|((a & 12)<<6)|((a & 1008)>>2)|(a & 3);
 endfunction
 integer frames=0,n=0,t,lx,ly,mx,my,checked=0,menu_pixels=0;
 reg [31:0] frame_desc;
 reg monitoring=0;
 always @(negedge pix_clk)if(read_ack)monitoring=1;
 // The timing generator starts before SDRAM's first vertical-blank reload.
 // Only frames after that first acknowledged reload have display data.
 always @(negedge pix_clk)if(!rst && monitoring)begin
  if(underflow || reader_error!=0)$fatal(1,"SDRAM read underflow/error");
  if(de)begin
   if(n==0)frame_desc=pixel_desc;
   if(pixel_desc!==frame_desc)$fatal(1,"descriptor changed within active frame");
   t=(n/640>=240?2:0)+(n%640>=320?1:0);lx=n%320;ly=n/640%240;
   if(pixel_desc[24])begin
    if(lx>=32 && lx<288 && ly>=8 && ly<200)begin
     if(rgb!==color(2,t,lx-32,ly-8))$fatal(1,"menu slot/address pixel n=%d got=%h",n,rgb);
     menu_pixels++;
    end
   end else if(pixel_desc[17])begin
    if(rgb!==color(1,t,lx,ly))$fatal(1,"old preview cache n=%d got=%h",n,rgb);
   end else if(rgb!==color(0,shown_bank,n%640,n/640))$fatal(1,"full cache bank=%d n=%d got=%h",shown_bank,n,rgb);
   checked++;
   if(n==307199)begin frames++;n=0;end else n++;
  end
 end
 integer i,j,b;
 initial begin
  for(b=0;b<4;b++)begin
   for(j=0;j<480;j++)for(i=0;i<640;i++)memory.memory[physical(b*307200+j*640+i)]=pattern(0,b,i,j);
   for(j=0;j<240;j++)for(i=0;i<320;i++)memory.memory[physical(1228800+b*76800+j*320+i)]=pattern(1,b,i,j);
   for(j=0;j<192;j++)for(i=0;i<256;i++)memory.memory[physical(1536000+b*49152+j*256+i)]=pattern(2,b,i,j);
  end
  repeat(20)@(negedge mem_clk);rst=0;
  wait(frames==1);wait(n==10000);desc=32'h25e400e4;req=~req;
  wait(frames==3);wait(n==10000);desc=32'h300200e4;req=~req;
  wait(frames==5);wait(n==10000);desc=32'h400000e4;req=~req;
  wait(frames==8);
  if(CASE_ID==1)begin
   for(b=0;b<4;b++)begin
    wait(n==10000);bank=2'(b);bank_req=~bank_req;
    wait(bank_req==bank_ack);wait(n==20000);wait(n==0);
   end
  end
  repeat(10)@(negedge pix_clk);
  if(menu_pixels<4*196608 || memory.refresh_count<10)$fatal(1,"coverage");
  $display("PASS selector display: %d pixels, menu=%d, 4 independent slots + old preview/full buffers; frame descriptor stable; refresh=%d",checked,menu_pixels,memory.refresh_count);$finish;
 end
 initial begin #300000000;$fatal(1,"display watchdog");end
endmodule
