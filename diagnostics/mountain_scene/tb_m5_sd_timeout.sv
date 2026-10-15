`timescale 1ns/1ps
// Compare every public output with the exact M4 source, including timeout edges.
module m5_timeout_case #(parameter R=100, T=250, HZ=1000, ID=0)(output reg done=0);
 reg clk=0,rst=1,cmd_req=0,rd_req=0,wr_req=0,ack=0;
 reg [47:0] cmd=48'h3700000000ff;
 reg [7:0] r1=0,rx=8'hff,wr_data=0;
 reg [15:0] data_len=0;
 always #5 clk=~clk;
 wire ra,na,rb,nb,re,ne,rv,nv,rr,nr,rw,nw,rwa,nwa,rc,nc,rs,ns;
 wire [7:0] rp,np,rd,nd,rt,nt;
 wire [15:0] rdiv,ndiv;
 wire [47:0] rdebug,ndebug;
 `define TIMEOUT_PORTS(A,B,C,D,E,F,G,H,I,J,K,L,M,N,O) \
  .sys_clk(clk),.rst(rst),.spi_clk_div(16'd2),.cmd_req(cmd_req),.cmd_req_ack(A), \
  .block_read_error(B),.cmd_response(C),.read_debug(D),.cmd_req_error(E), \
  .cmd(cmd),.cmd_r1(r1),.cmd_data_len(data_len),.block_read_req(rd_req), \
  .block_read_valid(F),.block_read_data(G),.block_read_req_ack(H), \
  .block_write_req(wr_req),.block_write_data(wr_data),.block_write_data_rd(I), \
  .block_write_req_ack(J),.nCS_ctrl(K),.clk_div(L),.spi_wr_req(M), \
  .spi_wr_ack(ack),.spi_data_in(N),.spi_data_out(rx)
 sd_card_cmd_m4 #(.CLK_FREQ_HZ(HZ),.RESPONSE_TIMEOUT_MS(R),.TOKEN_TIMEOUT_MS(T)) ref_dut(
  `TIMEOUT_PORTS(ra,rb,rp,rdebug,re,rv,rd,rr,rw,rwa,rc,rdiv,rs,rt,unused));
 sd_card_cmd #(.CLK_FREQ_HZ(HZ),.RESPONSE_TIMEOUT_MS(R),.TOKEN_TIMEOUT_MS(T)) dut(
  `TIMEOUT_PORTS(na,nb,np,ndebug,ne,nv,nd,nr,nw,nwa,nc,ndiv,ns,nt,unused));
 `undef TIMEOUT_PORTS
 integer checks=0,cmd_timeouts=0,token_timeouts=0,reads=0,writes=0,data_states=0;
 integer phase=0,cycle=0;
 always @(posedge clk) begin
  #1;
  if ({ra,rb,rp,rdebug,re,rv,rd,rr,rw,rwa,rc,rdiv,rs,rt} !==
      {na,nb,np,ndebug,ne,nv,nd,nr,nw,nwa,nc,ndiv,ns,nt})
   $fatal(1,"timeout equivalence case=%0d cycle=%0d state=%0d count=%0d",ID,cycle,ref_dut.state,ref_dut.wait_count);
  checks=checks+1;
  if(!rst) begin
   if(ref_dut.state==ref_dut.S_ERR) cmd_timeouts++;
   if(rr && rb) token_timeouts++;
   if(rv) reads++;
   if(rwa) writes++;
   if(ref_dut.state==ref_dut.S_CMD_DATA) data_states++;
  end
 end
 // Real handshakes, including a response on the exact timeout edge. Both
 // modules receive identical inputs, never force internal state/counters.
 always @(negedge clk) begin
  cycle++;
  ack=rs && (cycle%3!=0);
  rx=8'hff;
  if(ref_dut.state==ref_dut.S_CMD && ref_dut.byte_cnt>=6 && phase!=1) rx=r1;
  if(ref_dut.state==ref_dut.S_CMD_DATA) rx=cycle;
  if(ref_dut.state==ref_dut.S_READ_WAIT && phase!=2) rx=8'hfe;
  if(ref_dut.state==ref_dut.S_READ) rx=0;
  if(ref_dut.state==ref_dut.S_WRITE_SUC) rx=8'h05;
  if(phase==5) begin
   ack=($urandom_range(0,3)!=0);
   rx=($urandom_range(0,7)==0) ? $urandom : 8'hff;
   if($urandom_range(0,31)==0) begin
    cmd_req=$urandom; rd_req=$urandom; wr_req=$urandom;
    data_len=$urandom_range(0,8); r1=$urandom; cmd={$urandom,$urandom};
   end
   wr_data=$urandom;
   if(cycle%10007==0) rst=1;
   else if(cycle%10007==3) rst=0;
  end
 end
 task automatic reset_host;
  @(negedge clk); rst=1;cmd_req=0;rd_req=0;wr_req=0;
  repeat(3) @(negedge clk);
  rst=0;
  wait(ref_dut.state==ref_dut.S_WAIT);
  @(negedge clk);
 endtask
 initial begin
  phase=0; reset_host; data_len=4; cmd_req=1;
  wait(ra); @(negedge clk); cmd_req=0;
  phase=1; reset_host; cmd_req=1;
  // Reduced frequency exhausts both timeout counters, including 1/2-cycle
  // limits and the case where the token limit is shorter than the response.
  if(HZ==1000) begin
   wait(ra); @(negedge clk);cmd_req=0;
   phase=2;reset_host;rd_req=1;wait(rr);@(negedge clk);rd_req=0;
   phase=3;reset_host;rd_req=1;wait(rr);@(negedge clk);rd_req=0;
   phase=4;reset_host;wr_req=1;wait(rwa);@(negedge clk);wr_req=0;
  end
  phase=5;reset_host;
  repeat(200000) @(negedge clk);
  if(HZ==1000 && (cmd_timeouts==0 || token_timeouts==0)) $fatal(1,"missing timeout coverage case %0d",ID);
  if(ID==3 && (reads<512 || writes==0 || data_states==0)) $fatal(1,"missing SD state coverage");
  $display("PASS M5 timeout case=%0d checks=%0d response=%0d token=%0d read=%0d write=%0d data=%0d",ID,checks,cmd_timeouts,token_timeouts,reads,writes,data_states);
  done=1;
 end
endmodule

module tb_m5_sd_timeout;
 wire [4:0] done;
 m5_timeout_case #(.R(1),.T(2),.ID(0)) c0(done[0]);
 m5_timeout_case #(.R(2),.T(1),.ID(1)) c1(done[1]);
 m5_timeout_case #(.R(3),.T(7),.ID(2)) c2(done[2]);
 m5_timeout_case #(.R(100),.T(250),.ID(3)) c3(done[3]);
 m5_timeout_case #(.R(251),.T(97),.ID(4)) c4(done[4]);
 initial begin wait(&done); $display("PASS M5 SD timeout lockstep: five parameter sets, all outputs, unchanged timeout edges"); $finish; end
 initial begin #10000000; $fatal(1,"timeout equivalence watchdog");end
endmodule
