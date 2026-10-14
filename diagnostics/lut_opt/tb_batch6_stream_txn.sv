`timescale 1ns/1ps
// S2 batch6: old/new fat32_file_streamer, each with its own sector server; the ordered
// transactions (sector LBAs, file bytes with offsets, done with fs_error) must match.
module server(input clk, input rst_n, input req, input [31:0] lba, output reg busy, output reg valid,
              output reg [7:0] data, output reg [8:0] index, output reg done, output reg [7:0] err);
 integer remaining=-1, wait_cycles=0; reg [31:0] lba_q;
 // FAT region at LBA 100..131 (4096 clusters); data elsewhere.
 function automatic [7:0] content(input [31:0] a, input [8:0] i);
  reg [31:0] c, next;
  begin
   if(a>=100 && a<132) begin
    c=(a-100)*128+i[8:2];
    next = (c%97==0) ? 32'h0ffffff8 + c%8 : (c%89==0) ? c : (c%83==0) ? 32'd1 : (c%79==0) ? 32'd5000 :
           2 + ((c*37+11) % 3990);
    next = next | ((c%5==0) ? 32'hf0000000 : 0);   // high nibble ignored by FAT32
    content = next[8*i[1:0] +: 8];
   end else content = (a*131 + i*7 + (a>>3)) & 8'hff;
  end
 endfunction
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin busy<=0; valid<=0; done<=0; err<=0; remaining<=-1; end
  else begin
   valid<=0; done<=0;
   if(req) begin busy<=1; lba_q<=lba; wait_cycles<=$urandom%20; remaining<=512; end
   else if(remaining>0) begin
    if(wait_cycles>0) wait_cycles<=wait_cycles-1;
    else if($urandom%3!=0) begin valid<=1; index<=512-remaining; data<=content(lba_q,512-remaining); remaining<=remaining-1; end
   end else if(remaining==0) begin done<=1; busy<=0; err<=(lba_q%211==7) ? 8'h31 : 8'h00; remaining<=-1; end
  end
 end
endmodule

module tb_batch6_stream_txn;
 parameter integer GATE=0;
 reg clk=0, rst_n=0; always #5 clk=~clk;
 integer cycle=0, errors=0, files=0, bytes=0, reqs=0;
 integer codes[0:255];
 reg start=0, permit=0; reg [31:0] first=0, size=0; reg [7:0] spc=1;
 wire r_busy,n_busy,r_done,n_done,r_valid,n_valid,r_req,n_req; wire [7:0] r_byte,n_byte,r_err,n_err; wire [31:0] r_off,n_off,r_lba,n_lba;
 wire rs_busy,ns_busy,rs_valid,ns_valid,rs_done,ns_done; wire [7:0] rs_data,ns_data,rs_err,ns_err; wire [8:0] rs_idx,ns_idx;
 `define STREAM_PORTS(P) .clk(clk),.rst_n(rst_n),.file_start(start),.data_permit(permit),.first_cluster(first),.file_size(size), \
  .sectors_per_cluster(spc),.fat_start_lba(32'd100),.data_start_lba(32'd1000),.max_cluster(32'd3991),.file_busy(P``_busy),.file_done(P``_done), \
  .file_valid(P``_valid),.file_byte(P``_byte),.file_byte_offset(P``_off),.fs_error(P``_err),.sector_req(P``_req),.sector_lba(P``_lba), \
  .sector_busy(P``s_busy),.sector_valid(P``s_valid),.sector_byte(P``s_data),.sector_byte_index(P``s_idx),.sector_done(P``s_done),.sector_error(P``s_err)
 fat32_file_streamer_v015 #(.MAX_VISITED_CLUSTERS(24),.DATA_GATE_ENABLE(GATE)) ref_s(`STREAM_PORTS(r));
 fat32_file_streamer #(.MAX_VISITED_CLUSTERS(24),.DATA_GATE_ENABLE(GATE)) new_s(`STREAM_PORTS(n));
 server rsrv(clk,rst_n,r_req,r_lba,rs_busy,rs_valid,rs_data,rs_idx,rs_done,rs_err);
 server nsrv(clk,rst_n,n_req,n_lba,ns_busy,ns_valid,ns_data,ns_idx,ns_done,ns_err);
 typedef struct packed {bit [1:0] kind; bit [31:0] a; bit [31:0] b;} event_t;
 event_t rq[$], nq[$], re, ne;
 always @(posedge clk) if(rst_n) begin
  if(r_req) rq.push_back({2'd0,r_lba,32'd0}); if(r_valid) rq.push_back({2'd1,{24'd0,r_byte},r_off}); if(r_done) rq.push_back({2'd2,{24'd0,r_err},32'd0});
  if(n_req) nq.push_back({2'd0,n_lba,32'd0}); if(n_valid) nq.push_back({2'd1,{24'd0,n_byte},n_off}); if(n_done) nq.push_back({2'd2,{24'd0,n_err},32'd0});
  while(rq.size()>0 && nq.size()>0) begin
   re=rq.pop_front(); ne=nq.pop_front();
   if(re!==ne) begin errors=errors+1; if(errors<10) $display("MISMATCH kind=%0d/%0d a=%h/%h b=%h/%h file=%0d",re.kind,ne.kind,re.a,ne.a,re.b,ne.b,files); end
   else begin if(re.kind==0) reqs=reqs+1; if(re.kind==1) bytes=bytes+1; if(re.kind==2) begin files=files+1; codes[re.a[7:0]]=codes[re.a[7:0]]+1; end end
  end
 end
 reg [7:0] spcs[0:8]; integer k;
 initial begin spcs[0]=1;spcs[1]=2;spcs[2]=4;spcs[3]=8;spcs[4]=16;spcs[5]=32;spcs[6]=64;spcs[7]=128;spcs[8]=3; for(k=0;k<256;k=k+1) codes[k]=0; end
 always @(posedge clk) begin
  cycle<=cycle+1;
  #1;
  start=0; permit=($urandom%4!=0);
  if(cycle==5) rst_n=1;
  if(rst_n && cycle>10 && !r_busy && !n_busy && !start && rq.size()==0 && nq.size()==0 && $urandom%5==0) begin
   start=1; spc=spcs[($urandom%30==0) ? 8 : $urandom%8];
   first=($urandom%40==0) ? $urandom%2 : ($urandom%40==0) ? 32'd3992 : 2+$urandom%3990;
   size=($urandom%20==0) ? 0 : ($urandom%6==0) ? spc*512*(20+$urandom%20) : 1+$urandom%(spc*512*6);
  end
 end
 initial begin
  wait(files==2500);
  $display("coverage files=%0d reqs=%0d bytes=%0d ok=%0d sector=%0d loop=%0d range=%0d eof=%0d exhausted=%0d",
   files,reqs,bytes,codes[0],codes[8'h10],codes[8'h23],codes[8'h24],codes[8'h25],codes[8'h26]);
  if(codes[0]<300 || codes[8'h10]<5 || codes[8'h23]<5 || codes[8'h24]<20 || codes[8'h25]<20 || codes[8'h26]<5) $display("** Error: insufficient coverage");
  else if(errors) $display("** Error: %0d mismatches",errors);
  else $display("PASS batch6 streamer transactions GATE=%0d files=%0d",GATE,files);
  $finish;
 end
endmodule
