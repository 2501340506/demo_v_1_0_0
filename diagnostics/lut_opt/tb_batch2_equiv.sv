`timescale 1ns/1ps
// S1 batch2: v0.15.0 vs new frame_fifo_write, media_frame_reader (with frame_fifo_read and
// thumbnail_address) and a full thumbnail_address traversal; every output every cycle.
module tb_batch2_equiv;
 reg clk=0, pix=0, rst=1;
 always #5 clk=~clk;
 always #20 pix=~pix;
 integer cycle=0, errors=0;
 task automatic check(input bit ok, input string what);
  if(!ok) begin errors=errors+1; if(errors<10) $display("MISMATCH %s cycle=%0d t=%0t",what,cycle,$time); end
 endtask
 // Shared memory-side stimulus
 reg init_done=0, ref_vld=0, sdr_busy=0, rd_busy=0, wr_busy=0, permit=0;
 always @(posedge clk) begin
  #1;
  init_done = cycle>20; ref_vld=($urandom%50==0); sdr_busy=($urandom%8==0); rd_busy=($urandom%6==0);
  wr_busy=($urandom%6==0); permit=($urandom%4!=0);
 end

 // ---------------- frame_fifo_write pairs ----------------
 localparam integer NW=4;
 integer w_finish[0:NW-1], w_cancel[0:NW-1], w_bursts[0:NW-1];
 `define WRITER_PAIR(K,GATE,BURST,FLIP,W,H,LEN) \
 reg wreq``K=0, wcan``K=0; reg [1:0] widx``K=0; reg [9:0] used``K=0; \
 wire [20:0] ra``K, na``K; wire rbusy``K,nbusy``K,ren``K,nen``K,rcack``K,ncack``K,rack``K,nack``K,rfin``K,nfin``K,rclr``K,nclr``K; \
 frame_fifo_write_v015 #(.BURST_GATE_ENABLE(GATE),.BURST_SIZE(BURST),.WRITE_V_FLIP(FLIP),.FRAME_WIDTH(W),.FRAME_HEIGHT(H)) wr``K( \
  .rst(rst),.mem_clk(clk),.Sdr_init_done(init_done),.Sdr_init_ref_vld(ref_vld),.Sdr_busy(sdr_busy),.App_rd_busy(rd_busy), \
  .burst_permit(permit),.O_wr_busy(rbusy``K),.App_wr_en(ren``K),.App_wr_addr(ra``K),.write_cancel_req(wcan``K),.write_cancel_ack(rcack``K), \
  .write_req(wreq``K),.write_req_ack(rack``K),.write_finish(rfin``K),.write_addr_0(21'd0),.write_addr_1(21'd307200), \
  .write_addr_2(21'd614400),.write_addr_3(21'd1459200),.write_addr_index(widx``K),.write_len(LEN),.fifo_aclr(rclr``K),.rdusedw(used``K)); \
 frame_fifo_write #(.BURST_GATE_ENABLE(GATE),.BURST_SIZE(BURST),.WRITE_V_FLIP(FLIP),.FRAME_WIDTH(W),.FRAME_HEIGHT(H)) wn``K( \
  .rst(rst),.mem_clk(clk),.Sdr_init_done(init_done),.Sdr_init_ref_vld(ref_vld),.Sdr_busy(sdr_busy),.App_rd_busy(rd_busy), \
  .burst_permit(permit),.O_wr_busy(nbusy``K),.App_wr_en(nen``K),.App_wr_addr(na``K),.write_cancel_req(wcan``K),.write_cancel_ack(ncack``K), \
  .write_req(wreq``K),.write_req_ack(nack``K),.write_finish(nfin``K),.write_addr_0(21'd0),.write_addr_1(21'd307200), \
  .write_addr_2(21'd614400),.write_addr_3(21'd1459200),.write_addr_index(widx``K),.write_len(LEN),.fifo_aclr(nclr``K),.rdusedw(used``K)); \
 always @(negedge clk) check({rbusy``K,ren``K,ra``K,rcack``K,rack``K,rfin``K,rclr``K}==={nbusy``K,nen``K,na``K,ncack``K,nack``K,nfin``K,nclr``K},`"writer K`"); \
 initial begin w_finish[K]=0; w_cancel[K]=0; w_bursts[K]=0; end \
 always @(posedge clk) begin \
  if(rfin``K) w_finish[K]=w_finish[K]+1; \
  #1; \
  used``K = ($urandom%10<7) ? BURST+$urandom%(1024-BURST) : $urandom%1024; \
  if(wcan``K) begin if(rcack``K) begin wcan``K=0; w_cancel[K]=w_cancel[K]+1; wreq``K=1; widx``K=$urandom; end end \
  else if(wreq``K) begin if(rack``K) wreq``K=0; end \
  else if(cycle>30 && $urandom%300000==0) wcan``K=1; \
  else if(cycle>30 && (rfin``K || $urandom%400000==0 || (cycle<100))) begin wreq``K=1; widx``K=$urandom; end \
 end
 `WRITER_PAIR(0,1,64,1,640,480,21'd307200)
 `WRITER_PAIR(1,1,64,1,320,240,21'd76800)
 `WRITER_PAIR(2,0,64,1,640,480,21'd1024)
 `WRITER_PAIR(3,0,256,0,640,480,21'd1024)

 // ---------------- media_frame_reader pairs (production PREVIEW_ENABLE=1) ----------------
 // Display reads start once data is buffered; rare forced reads cover underflow/frame_bad.
 integer read_frames=0, preview_frames=0, underflows=0;
 `define READER_PAIR(K,LEN,STALL) \
 reg rreq_r``K=0, commit_r``K=0, prev_r``K=0, rd_en_r``K=0, disp_r``K=0, sdr_en_r``K=0; reg [17:0] pdesc_in_r``K=0; \
 reg [31:0] dout_r``K=0; reg [1:0] ridx_r``K=0; reg [7:0] pipe_r``K=0; integer age_r``K=0; \
 wire [20:0] ra_r``K, na_r``K; wire [31:0] rd_r``K, nd_r``K; wire [17:0] rp_r``K, np_r``K; wire [2:0] re_r``K, ne_r``K; \
 wire rb_r``K,nb_r``K,ren_r``K,nen_r``K,rpri_r``K,npri_r``K,rack_r``K,nack_r``K,rfin_r``K,nfin_r``K,rcack_r``K,ncack_r``K,rpack_r``K,npack_r``K,ru_r``K,nu_r``K; \
 media_frame_reader_v015 #(.PREVIEW_ENABLE(1)) mr_r``K(.rst(rst),.mem_clk(clk),.read_clk(pix),.read_rst(rst), \
  .Sdr_init_done(init_done),.Sdr_init_ref_vld(ref_vld),.Sdr_busy(sdr_busy),.App_wr_busy(wr_busy), \
  .O_rd_busy(rb_r``K),.App_rd_en(ren_r``K),.App_rd_addr(ra_r``K),.refill_priority(rpri_r``K),.Sdr_rd_en(sdr_en_r``K),.Sdr_rd_dout(dout_r``K), \
  .read_req(rreq_r``K),.read_req_ack(rack_r``K),.read_finish(rfin_r``K),.display_commit_request(commit_r``K),.display_commit_ack(rcack_r``K), \
  .preview_request(prev_r``K),.preview_descriptor(pdesc_in_r``K),.preview_ack(rpack_r``K),.pixel_descriptor(rp_r``K), \
  .read_addr_0(21'd0),.read_addr_1(21'd307200),.read_addr_2(21'd614400),.read_addr_3(21'd921600),.read_addr_index(ridx_r``K),.read_len(LEN), \
  .read_en(rd_en_r``K),.display_valid(disp_r``K),.read_data(rd_r``K),.underflow(ru_r``K),.reader_error(re_r``K)); \
 media_frame_reader #(.PREVIEW_ENABLE(1)) mn_r``K(.rst(rst),.mem_clk(clk),.read_clk(pix),.read_rst(rst), \
  .Sdr_init_done(init_done),.Sdr_init_ref_vld(ref_vld),.Sdr_busy(sdr_busy),.App_wr_busy(wr_busy), \
  .O_rd_busy(nb_r``K),.App_rd_en(nen_r``K),.App_rd_addr(na_r``K),.refill_priority(npri_r``K),.Sdr_rd_en(sdr_en_r``K),.Sdr_rd_dout(dout_r``K), \
  .read_req(rreq_r``K),.read_req_ack(nack_r``K),.read_finish(nfin_r``K),.display_commit_request(commit_r``K),.display_commit_ack(ncack_r``K), \
  .preview_request(prev_r``K),.preview_descriptor(pdesc_in_r``K),.preview_ack(npack_r``K),.pixel_descriptor(np_r``K), \
  .read_addr_0(21'd0),.read_addr_1(21'd307200),.read_addr_2(21'd614400),.read_addr_3(21'd921600),.read_addr_index(ridx_r``K),.read_len(LEN), \
  .read_en(rd_en_r``K),.display_valid(disp_r``K),.read_data(nd_r``K),.underflow(nu_r``K),.reader_error(ne_r``K)); \
 always @(negedge clk) check({rb_r``K,ren_r``K,ra_r``K,rpri_r``K,rack_r``K,rfin_r``K,rcack_r``K,rpack_r``K,re_r``K}==={nb_r``K,nen_r``K,na_r``K,npri_r``K,nack_r``K,nfin_r``K,ncack_r``K,npack_r``K,ne_r``K},`"reader K mem`"); \
 always @(negedge pix) check({rd_r``K,rp_r``K,ru_r``K}==={nd_r``K,np_r``K,nu_r``K},`"reader K pixel`"); \
 always @(posedge clk) begin \
  if(rfin_r``K) begin read_frames=read_frames+1; if(mr_r``K.frame_descriptor[17]) preview_frames=preview_frames+1; end \
  #1; \
  pipe_r``K={pipe_r``K[6:0],ren_r``K}; sdr_en_r``K=pipe_r``K[5] || ($urandom%200000==0); dout_r``K=$urandom; \
  age_r``K=age_r``K+1; \
  if(rreq_r``K) begin if(rack_r``K) rreq_r``K=0; end \
  else if(cycle>30 && (rfin_r``K || cycle<100 || age_r``K>STALL)) begin \
   rreq_r``K=1; ridx_r``K=$urandom; age_r``K=0; \
   if($urandom%2) begin prev_r``K=~prev_r``K; pdesc_in_r``K={$urandom%2==0,9'd0,8'($urandom)}; end \
   if($urandom%2) commit_r``K=~commit_r``K; \
  end \
 end \
 always @(posedge pix) begin \
  if(ru_r``K) underflows=underflows+1; \
  #1; rd_en_r``K=(!mr_r``K.fifo_empty && $urandom%10!=0) || ($urandom%2000==0); disp_r``K=($urandom%50!=0); \
 end
 `READER_PAIR(0,21'd307200,1600000)
 `READER_PAIR(1,21'd1024,20000)

 // ---------------- thumbnail_address full traversal ----------------
 reg t_reload=0, t_adv=0, t_prev=0; reg [7:0] t_map=0; reg [1:0] t_full=0;
 wire [20:0] t_ref, t_new; integer combo=0, steps=0;
 thumbnail_address_v015 tr(.clk(clk),.rst(rst),.reload(t_reload),.advance(t_adv),.preview(t_prev),.bank_map(t_map),.fullscreen_bank(t_full),.address(t_ref));
 thumbnail_address tn(.clk(clk),.rst(rst),.reload(t_reload),.advance(t_adv),.preview(t_prev),.bank_map(t_map),.fullscreen_bank(t_full),.address(t_new));
 always @(negedge clk) check(t_ref===t_new,"thumbnail_address");
 reg [7:0] maps[0:3]; initial begin maps[0]=8'hE4; maps[1]=8'h1B; maps[2]=8'h4E; maps[3]=8'hB1; end
 always @(posedge clk) begin
  #1;
  t_reload=0; t_adv=0;
  if(cycle>20 && combo<8) begin
   if(steps==0) begin t_reload=1; t_prev=combo>=4; t_full=combo; t_map=maps[combo%4]; t_adv=$urandom%2; steps=1; end
   else if($urandom%5!=0) begin t_adv=1; steps=steps+1; if(steps>307200+5) begin steps=0; combo=combo+1; end end
  end
 end

 always @(posedge clk) begin
  cycle<=cycle+1;
  #2;
  if(cycle==10) rst=0;
  else if(cycle>3600000 && cycle<3600010) rst=1;
  else if(cycle==3600010) rst=0;
 end
 integer k, finishes;
 initial begin
  wait(combo==8 && cycle>=5000000);
  finishes=0; for(k=0;k<NW;k=k+1) begin $display("writer%0d finishes=%0d cancels=%0d",k,w_finish[k],w_cancel[k]); if(w_finish[k]<1 || w_cancel[k]<1) finishes=-1000; end
  if(finishes<0 || read_frames<20 || preview_frames<5 || underflows<1)
   $display("** Error: insufficient coverage read_frames=%0d preview_frames=%0d underflows=%0d",read_frames,preview_frames,underflows);
  else if(errors) $display("** Error: %0d mismatches",errors);
  else $display("PASS batch2 equivalence cycles=%0d read_frames=%0d preview_frames=%0d thumbnail_combos=%0d",cycle,read_frames,preview_frames,combo);
  $finish;
 end
endmodule
