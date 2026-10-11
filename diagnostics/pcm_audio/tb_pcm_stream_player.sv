`timescale 1ns/1ps
module tb_pcm_stream_player;
 reg wr=0,rd=0;always #5 wr=~wr;always #20 rd=~rd;
 reg wr_rst=1,rd_rst=1,start=0,loop=0,v=0,last=0,err=0,ready=1;reg [7:0] b=0;
 wire fr,sv,act;wire signed [15:0] l,r;wire [31:0] uf;
 pcm_stream_player #(.CLOCK_HZ(1000),.SAMPLE_HZ(100)) dut(.wr_clk(wr),.wr_rst_n(!wr_rst),.file_start(start),.file_loop(loop),.file_valid(v),.file_byte(b),.file_last(last),.file_error(err),.file_ready(fr),.rd_clk(rd),.rd_rst_n(!rd_rst),.sample_ready(ready),.sample_valid(sv),.sample_left(l),.sample_right(r),.active(act),.underflow_count(uf));
 integer i,n=0;
 initial begin repeat(3)@(posedge wr);wr_rst=0;rd_rst=0;@(posedge wr);start=1;@(posedge wr);start=0;
  for(i=0;i<8;i=i+1)begin @(posedge wr);while(!fr)@(posedge wr);v=1;b=i*2;@(posedge wr);b=i*2+1;last=(i==7);@(posedge wr);v=0;end
  repeat(100)begin @(posedge rd);if(sv)begin if(l!==r)$fatal(1,"stereo mismatch");n=n+1;end end
  if(n<8)$fatal(1,"only %0d samples",n);$display("PASS PCM stream player: %0d samples",n);$finish;
 end
 initial begin #20000;$fatal(1,"watchdog");end
endmodule

