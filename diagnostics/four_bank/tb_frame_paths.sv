`timescale 1ns/1ps
// Real FIFOs, protected controller and command/DQ SDRAM model, 100/40/25 MHz.
module tb_frame_paths;
 reg src_clk=0,mem_clk=0,pix_clk=0,rst=1;
 always #5 src_clk=~src_clk;
 always #12.5 mem_clk=~mem_clk;
 always #20 pix_clk=~pix_clk;
 wire shifted; assign #12 shifted=mem_clk;
 reg block_writer=0;
 wire init_done,refresh,busy,wr_en,rd_en,rd_valid,wr_busy,rd_busy;
 wire [20:0] wr_addr,rd_addr; wire [31:0] wr_data,rd_data;
 wire sc,ras,cas,we;wire [1:0] ba;wire [10:0] addr;wire [3:0] dm;tri [31:0] dq;
 sdram controller(.Clk(mem_clk),.Clk_sft(shifted),.Rst(rst),
  .Sdr_init_done(init_done),.Sdr_init_ref_vld(refresh),.Sdr_busy(busy),
  .App_wr_en(wr_en),.App_wr_addr(wr_addr),.App_wr_dm(4'b0),.App_wr_din(wr_data),
  .App_rd_en(rd_en),.App_rd_addr(rd_addr),.Sdr_rd_en(rd_valid),.Sdr_rd_dout(rd_data),
  .SDRAM_CLK(sc),.SDR_CKE(),.SDR_RAS(ras),.SDR_CAS(cas),.SDR_WE(we),
  .SDR_BA(ba),.SDR_ADDR(addr),.SDR_DM(dm),.SDR_DQ(dq));
 sdram_bl4_model memory(.clk(sc),.ras(ras),.cas(cas),.we(we),.ba(ba),.addr(addr),.dm(dm),.dq(dq));
 reg req=0,src_we=0,source_done=0,source_error=0,cancel=0;
 reg [31:0] src_data=0;reg [1:0] write_bank=0;
 wire ack,finish,cancel_ack,error_toggle;wire [2:0] memory_error;
 media_frame_loader loader(.rst(rst),.mem_clk(mem_clk),.write_clk(src_clk),.write_rst(rst),
  .Sdr_init_done(init_done),.Sdr_init_ref_vld(refresh),.Sdr_busy(busy),
  .App_rd_busy(rd_busy || block_writer),.O_wr_busy(wr_busy),
  .App_wr_en(wr_en),.App_wr_addr(wr_addr),.App_wr_din(wr_data),.App_wr_dm(),
  .write_req(req),.write_req_ack(ack),.write_cancel_req(cancel),.write_cancel_ack(cancel_ack),
  .write_addr_0(21'd0),.write_addr_1(21'd307200),.write_addr_2(21'd614400),.write_addr_3(21'd921600),
  .write_addr_index(write_bank),.write_len(21'd307200),.write_en(src_we),.write_data(src_data),
  .source_done(source_done),.source_error(source_error),.write_finish(finish),
  .error_toggle(error_toggle),.memory_error(memory_error));
 reg display_valid=0,commit_req=0; reg [1:0] display_bank=0;
 wire commit_ack,read_req,read_ack,consume,read_finish,underflow;
 wire [2:0] reader_error;wire [31:0] pixel_data;
 wire hs0,vs0,de0,hs,vs,de;wire [9:0] x0,x;wire [23:0] rgb;
 video_timing_data timing(.video_clk(pix_clk),.rst(rst),.read_req(read_req),.read_req_ack(read_ack),
  .hs(hs0),.vs(vs0),.de(de0),.video_x(x0));
 video_delay delay_path(.video_clk(pix_clk),.rst(rst),.read_en(consume),.read_data(pixel_data[31:8]),
  .hs(hs0),.vs(vs0),.de(de0),.video_x(x0),.hs_r(hs),.vs_r(vs),.de_r(de),.vout_data(rgb),.video_x_r(x));
 reg suppress_return=0;
 media_frame_reader reader(.rst(rst),.mem_clk(mem_clk),.read_clk(pix_clk),.read_rst(rst),
  .Sdr_init_done(init_done),.Sdr_init_ref_vld(refresh),.Sdr_busy(busy),
  .App_wr_busy(wr_busy),.O_rd_busy(rd_busy),.App_rd_en(rd_en),.App_rd_addr(rd_addr),
  .Sdr_rd_en(rd_valid && !suppress_return),.Sdr_rd_dout(rd_data),
  .read_req(read_req),.read_req_ack(read_ack),.read_finish(read_finish),
  .display_commit_request(commit_req),.display_commit_ack(commit_ack),
  .read_addr_0(21'd0),.read_addr_1(21'd307200),.read_addr_2(21'd614400),.read_addr_3(21'd921600),
  .read_addr_index(display_bank),.read_len(21'd307200),.read_en(consume),.display_valid(display_valid),
  .read_data(pixel_data),.underflow(underflow),.reader_error(reader_error));
 function [31:0] pattern(input integer bank,input integer n);
  pattern={8'(bank+48),8'(n/640),8'(n%640),8'h00};
 endfunction
 integer writes=0,finishes=0,checked_frames=0,pixel=0;
 integer burst_words=0,read_words=0,refreshes=0,last_refresh=0,cycles=0;
 reg wr_prev=0,rd_prev=0,check_pixels=0,injecting=0;
 always @(posedge mem_clk) if(!rst) begin
  if(finish) finishes=finishes+1;
  if(wr_en) begin
   if(!wr_prev && refresh)$fatal(1,"new write burst during active refresh");
   burst_words=burst_words+1;writes=writes+1;
   if(display_valid && wr_addr/307200==display_bank)$fatal(1,"overwrite displayed bank");
  end else if(wr_prev) begin
   if(burst_words!=64)$fatal(1,"write burst length %0d",burst_words);
   burst_words=0;
  end
  if(rd_en) read_words=read_words+1;
  else if(rd_prev)begin if(read_words!=64)$fatal(1,"read burst length %0d",read_words);read_words=0;end
  if(wr_en && rd_en)$fatal(1,"read/write issue collision");
  wr_prev=wr_en;rd_prev=rd_en;
  if(!injecting && memory_error!=0)$fatal(1,"unexpected loader error %0d",memory_error);
  if(!injecting && display_valid && reader_error!=0)$fatal(1,"unexpected reader error %0d",reader_error);
 end
 always @(posedge sc)begin
  cycles=cycles+1;
  if(init_done && {ras,cas,we}==3'b001)begin
   if(refreshes>0 && cycles-last_refresh!=1100)$fatal(1,"refresh cadence %0d",cycles-last_refresh);
   last_refresh=cycles;refreshes=refreshes+1;
  end
 end
 // Observe the actual aligned RGB bus; all 307200 pixels, not just addresses.
 always @(negedge pix_clk) if(!rst)begin
  if(check_pixels && de) begin
   if(rgb!==(pattern(display_bank,(479-pixel/640)*640+pixel%640) >> 8))
    $fatal(1,"pixel bank=%0d n=%0d rgb=%h",display_bank,pixel,rgb);
   if(pixel==307199)begin pixel=0;checked_frames=checked_frames+1;end
   else pixel=pixel+1;
  end
  if(!injecting && display_valid && underflow)$fatal(1,"unexpected visible underflow");
 end
 task start_write(input [1:0] bank);
  @(negedge src_clk);write_bank=bank;req=1;
  wait(ack);repeat(4)@(negedge src_clk);req=0;wait(!ack);repeat(8)@(negedge src_clk);
 endtask
 task send_pixels(input integer count,input integer gap,input bit eof_with_last=0);
  for(integer n=0;n<count;n=n+1)begin
   src_data=pattern(write_bank,n);src_we=1;source_done=eof_with_last && n==count-1;
   @(negedge src_clk);src_we=0;source_done=0;
   repeat(gap-1)@(negedge src_clk);
  end
 endtask
 task load_bank(input [1:0] bank);
  integer before_finish;
  before_finish=finishes;start_write(bank);send_pixels(307200,24,bank==3);
  // Memory draining without parser success must never publish a frame.
  if(bank!=3)begin
   repeat(100)@(negedge src_clk);
   if(finishes!=before_finish)$fatal(1,"published before parser success");
   source_done=1;@(negedge src_clk);source_done=0;
  end
  wait(finishes==before_finish+1);
  if(bank==3)$display("PASS EOF coincident with the final pixel");
  $display("PASS completed physical write bank %0d; display readback follows",bank);
 endtask
 task show_bank(input [1:0] bank);
  integer before_frame;
  check_pixels=0;
  @(negedge src_clk);display_bank=bank;commit_req=~commit_req;
  wait(commit_ack==commit_req);display_valid=1;
  // Commit acknowledgement occurs in vertical blank ahead of effective data.
  wait(!de);pixel=0;before_frame=checked_frames;check_pixels=1;
  wait(checked_frames>=before_frame+1);
 endtask
 integer saved_finishes, recovery_frame;reg saved_toggle;
 initial begin
  #200;rst=0;wait(init_done);
  load_bank(0);show_bank(0);
  load_bank(1);show_bank(1);
  load_bank(2);show_bank(2);
  load_bank(3);show_bank(3);
  $display("PASS concurrent display/write and all four independent bank addresses");
  // Decode failure after a partial burst must cancel without a completion.
  injecting=1;saved_finishes=finishes;start_write(0);send_pixels(400,24);
  source_error=1;@(negedge src_clk);source_error=0;
  wait(loader.core_cancel_ack);wait(!loader.core_cancel_ack);
  if(finishes!=saved_finishes)$fatal(1,"failed source committed");
  $display("PASS source failure drains and cancels without success");
  // Explicit short successful source is a distinct count failure, once only.
  start_write(0);saved_toggle=error_toggle;send_pixels(130,24);
  source_done=1;@(negedge src_clk);source_done=0;
  wait(error_toggle!=saved_toggle);if(memory_error!=2)$fatal(1,"short count error missing");
  wait(loader.core_cancel_ack);wait(!loader.core_cancel_ack);
  if(finishes!=saved_finishes)$fatal(1,"short frame committed");
  $display("PASS short-frame error and internal cancellation");
  // User cancellation while App_wr_en is active preserves the full burst.
  start_write(0);send_pixels(100,1);wait(wr_en);
  @(negedge src_clk);cancel=1;wait(cancel_ack);
  if(wr_en)$fatal(1,"cancel acknowledged before last write");
  @(negedge src_clk);cancel=0;wait(!cancel_ack);
  if(finishes!=saved_finishes)$fatal(1,"cancelled load committed");
  $display("PASS explicit cancellation at active burst");
  // A blocked writer exercises the actual FIFO capacity and bounded stall.
  start_write(0);saved_toggle=error_toggle;block_writer=1;send_pixels(520,1);
  wait(error_toggle!=saved_toggle);if(memory_error!=1)$fatal(1,"FIFO overflow error missing");
  wait(loader.core_cancel_ack);wait(!loader.core_cancel_ack);block_writer=0;
  if(finishes!=saved_finishes)$fatal(1,"overflowed load committed");
  $display("PASS write FIFO overflow cancels exactly this load");
  start_write(0);saved_toggle=error_toggle;block_writer=1;send_pixels(130,24);
  wait(error_toggle!=saved_toggle);if(memory_error!=3)$fatal(1,"write stall error missing");
  wait(loader.core_cancel_ack);wait(!loader.core_cancel_ack);block_writer=0;
  if(finishes!=saved_finishes)$fatal(1,"stalled load committed");
  $display("PASS write stall reports and cancels without success");
  // Controlled read loss; normal timing continues, next frame restarts cleanly.
  check_pixels=0;recovery_frame=checked_frames+1;wait(read_req);suppress_return=1;wait(underflow);
  repeat(5)@(negedge pix_clk);if(pixel_data!=0)$fatal(1,"underflow must black output");
  suppress_return=0;wait(reader.fifo_clear);wait(!reader.fifo_clear);
  wait(!de);pixel=0;check_pixels=1;
  wait(checked_frames>=recovery_frame);
  if(underflow || reader_error)$fatal(1,"reader did not recover");
  if(refreshes<1000)$fatal(1,"insufficient physical refresh coverage");
  $display("PASS next-frame underflow recovery with video timing intact");
  $display("PASS frame paths: checked_frames=%0d writes=%0d refreshes=%0d",checked_frames,writes,refreshes);
  $finish;
 end
 initial begin #1000000000;$fatal(1,"frame paths watchdog");end
endmodule
