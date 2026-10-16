`timescale 1ns/1ps
module tb_m4_metadata;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,en=0,found=1,single=1;
 reg [31:0] cluster=2,size=2,maximum=100;
 wire [1:0] pe,fv,stopped,req;wire [7:0] fb[0:1],error[0:1];
 wire [31:0] loops[0:1],lba[0:1];
 `define PORTS(i) .clk(clk),.rst_n(!rst),.enable(en),.audio_found(found),.single_play(single), \
 .first_cluster(cluster),.file_size(size),.max_cluster(maximum),.sectors_per_cluster(8'd1), \
 .fat_start_lba(32'd1),.data_start_lba(32'd10),.sector_permit(1'b1), \
 .player_stopped(1'b1),.player_ready(1'b1),.player_enable(pe[i]),.file_valid(fv[i]), \
 .file_byte(fb[i]),.stopped(stopped[i]),.error_code(error[i]),.loop_count(loops[i]), \
 .sector_req(req[i]),.sector_lba(lba[i]),.sector_busy(1'b0),.sector_valid(1'b0), \
 .sector_done(1'b0),.sector_byte(8'd0),.sector_error(8'd0),.sector_index(9'd0)
 fat32_pcm_stream #(.SINGLE_SUPPORT(1)) dut(`PORTS(0));
 fat32_pcm_stream_m4_reference #(.SINGLE_SUPPORT(1)) reference_dut(`PORTS(1));
 `undef PORTS
 integer checks=0,cases=0,i,j,k;reg expected_bad;reg [31:0] values[0:9];reg [31:0] rng=32'h71ab4312;
 always @(negedge clk)if(!rst)begin
  if({pe[0],fv[0],stopped[0],req[0],error[0],loops[0],lba[0]} !==
     {pe[1],fv[1],stopped[1],req[1],error[1],loops[1],lba[1]} || dut.state!==reference_dut.state)
   $fatal(1,"M4 metadata equivalence case=%0d cluster=%h max=%h size=%h",cases,cluster,maximum,size);
  if(fv[0] && fb[0]!==fb[1])$fatal(1,"M4 metadata byte mismatch");
  checks++;
 end
 task run_case;
 begin
  @(posedge clk);#1;en=1;
  expected_bad=size==0 || size[0] || cluster<2 || cluster>maximum;
  repeat(5)@(posedge clk);#1;
  if(error[0] !== ((!found || !expected_bad)?8'h00:8'h30))$fatal(1,"M4 metadata wrong decision");
  repeat(12)@(posedge clk);#1;en=0;
  wait(&stopped);repeat(5)@(posedge clk);#1;cases++;
 end endtask
 initial begin
  values[0]=0;values[1]=1;values[2]=2;values[3]=32'hffff;
  values[4]=32'h10000;values[5]=32'h10001;values[6]=32'h1ffff;
  values[7]=32'hffff0000;values[8]=32'hfffffffe;values[9]=32'hffffffff;
  repeat(4)@(posedge clk);#1;rst=0;
  for(i=0;i<10;i++)for(j=0;j<10;j++)for(k=0;k<4;k++)begin
   cluster=values[i];maximum=values[j];size=k==0?0:k==1?3:k==2?2:1202;
   found=1;single=k[0];run_case();
  end
  for(i=0;i<400;i++)begin
   rng=rng*1664525+1013904223;cluster=rng;
   rng=rng*1664525+1013904223;maximum=rng;
   size=512;found=i%7!=0;single=i[0];run_case();
  end
  $display("PASS M4 metadata equivalence: %0d cases / %0d cycles; full-word vs registered half-words, bounds, equality, carry, odd/empty/missing, single and loop; same public outputs and state latency",cases,checks);$finish;
 end
 initial begin #1000000;$fatal(1,"M4 metadata watchdog");end
endmodule
