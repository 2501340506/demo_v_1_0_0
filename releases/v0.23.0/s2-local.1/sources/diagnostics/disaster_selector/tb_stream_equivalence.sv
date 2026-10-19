`timescale 1ns/1ps
module tb_stream_equivalence;
 reg clk=0; always #5 clk=~clk;
 wire [3:0] finished;
 genvar g;
 generate for(g=0;g<4;g=g+1)begin:pair
 localparam WIDTH=(g<2)?20:32;
 reg rst_n=0,start=0,permit=0;
 reg [31:0] size=0;
 reg [31:0] first_cluster=2,max_cluster=4096;
 reg [7:0] spc=1;
 reg busy=0,valid=0,done=0;
 reg [7:0] data=0,err=0;
 reg [8:0] index=0;
 wire [1:0] fb,fd,fv,req;
 wire [7:0] byte_out[0:1],error_out[0:1];
 wire [31:0] offset[0:1],lba[0:1];
 `define PORTS(N) .clk(clk),.rst_n(rst_n),.file_start(start),.data_permit(permit),.first_cluster(first_cluster),.file_size(size),.sectors_per_cluster(spc),.fat_start_lba(32'd10),.data_start_lba(32'd100),.max_cluster(max_cluster),.file_busy(fb[N]),.file_done(fd[N]),.file_valid(fv[N]),.file_byte(byte_out[N]),.file_byte_offset(offset[N]),.fs_error(error_out[N]),.sector_req(req[N]),.sector_lba(lba[N]),.sector_busy(busy),.sector_valid(valid),.sector_byte(data),.sector_byte_index(index),.sector_done(done),.sector_error(err)
 fat32_file_streamer #(.FILE_SIZE_BITS(WIDTH),.DATA_GATE_ENABLE(g%2)) dut(`PORTS(0));
 fat32_file_streamer_reference #(.FILE_SIZE_BITS(WIDTH),.DATA_GATE_ENABLE(g%2)) ref_dut(`PORTS(1));
 `undef PORTS
 integer pos=-1,files=0,bytes=0,reads=0,k;
 reg [31:0] saved;
 reg last_with_done=0,inject=0;
 reg complete=0;
 assign finished[g]=complete;
 always @(negedge clk)begin
  if(rst_n)begin
   if({fb[0],fd[0],fv[0],req[0],byte_out[0],offset[0],lba[0],error_out[0]} !==
      {fb[1],fd[1],fv[1],req[1],byte_out[1],offset[1],lba[1],error_out[1]})
     $fatal(1,"stream cycle equivalence width=%0d gate=%0d file=%0d",WIDTH,g%2,files);
   if(dut.remaining_empty !== (dut.remaining_bytes==0) || dut.remaining_one !== (dut.remaining_bytes==1))
     $fatal(1,"stream EOF predicate invariant");
   if(fv[0])bytes++;
  end
  #1;
  valid=0;done=0;err=0;permit=$urandom_range(0,3)!=0;
  if(!rst_n)begin pos=-1;busy=0;end
  else if(req[0])begin pos=0;saved=lba[0];busy=1;reads++;end
  else if(pos>=0 && pos<512 && $urandom_range(0,3)!=0)begin
   valid=1;index=pos;
   // Contiguous cluster chain and actual full sectors, including final-byte
   // sector_done on half the files and injected sector failures.
   if(saved<100)data=((saved-10)*128+pos/4+1) >> (8*(pos%4));
   else data=pos^saved;
   pos++;
   if(pos==512 && last_with_done)begin done=1;busy=0;pos=-1;err=inject?8'h10:0;end
  end else if(pos==512)begin done=1;busy=0;pos=-1;err=inject?8'h10:0;end
 end
 task run_file(input [31:0] n,input bit coincident,input bit fail);
 begin
  @(posedge clk);#2;size=n;last_with_done=coincident;inject=fail;start=1;
  @(posedge clk);#2;start=0;
  wait(fd[0]);@(posedge clk);#2;files++;
 end endtask
 initial begin
  repeat(4)@(posedge clk);#2;rst_n=1;
  for(k=0;k<2;k++)begin
   run_file(0,k,0);run_file(1,k,0);run_file(2,k,0);
   run_file(511,k,0);run_file(512,k,0);run_file(513,k,0);
   run_file(1024,k,0);run_file(1025,k,0);run_file(8193,k,0);
   run_file(513,k,1);
  end
  for(k=0;k<80;k++)begin spc=1<<$urandom_range(0,4);run_file($urandom_range(1,18000),k%2,k%11==0);end
  // Reset during an active file also resets both look-ahead predicates.
  @(posedge clk);#2;size=10000;start=1;
  @(posedge clk);#2;start=0;
  wait(fv[0]);@(posedge clk);#2;rst_n=0;
  repeat(3)@(posedge clk);#2;rst_n=1;
  run_file(513,1,0);
  if(files!=101 || bytes<100000 || reads<200)$fatal(1,"stream coverage");
  // Exercise every comparator byte, equality and carries at the bound.
  for(k=0;k<128;k++)begin
   max_cluster=$urandom;
   case(k%4)
    0:first_cluster=max_cluster;
    1:first_cluster=max_cluster+1;
    2:first_cluster=max_cluster-1;
    3:first_cluster=$urandom;
   endcase
   run_file(1,1,0);
   if(error_out[0] !== ((first_cluster<2 || first_cluster>max_cluster)?8'h24:8'h00))
    $fatal(1,"stream range boundary first=%h max=%h error=%h",first_cluster,max_cluster,error_out[0]);
  end
  $display("PASS stream equivalence width=%0d gate=%0d files=%0d bytes=%0d reads=%0d",WIDTH,g%2,files,bytes,reads);
  complete=1;
 end
 end endgenerate
 initial begin wait(&finished);$display("PASS stream equivalence all four configurations");$finish;end
 initial begin #100000000;$fatal(1,"stream equivalence watchdog");end
endmodule
