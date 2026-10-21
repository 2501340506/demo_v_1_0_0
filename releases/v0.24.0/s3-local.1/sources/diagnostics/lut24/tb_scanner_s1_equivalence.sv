`timescale 1ns/1ps
// v0.24 S1: original and reduced fat32_volume_scanner share one randomized
// sector model. Every output, including sector_lba, is compared every cycle.
// Volumes cover MBR priority, BPB field rejects, mirror flags, layout ranges,
// geometry reuse, FAT chains, directory entries, sector errors and resets.
module tb_scanner_s1_equivalence;
 parameter integer DIRECTORY_ENABLE=1, REUSE_GEOMETRY=1;
 parameter integer SCAN_AUDIO=1, SCAN_TEXT=1, SCAN_PUBLICITY=1;
 parameter integer SEED=1, SCANS=400;
 reg clk=0; always #5 clk=~clk;
 reg rst_n=0, scan_start=0;
 reg [31:0] directory_cluster=0;
 reg sector_busy=0, sector_valid=0, sector_done=0;
 reg [7:0] sector_byte=0, sector_error=0;
 reg [8:0] sector_byte_index=0;

`define SCANNER_PORTS(p) \
  .clk(clk),.rst_n(rst_n),.scan_start(scan_start),.directory_cluster(directory_cluster), \
  .directory_valid(p``_directory_valid),.directory_clusters(p``_directory_clusters), \
  .scan_busy(p``_scan_busy),.scan_done(p``_scan_done),.fs_error(p``_fs_error), \
  .partition_lba(p``_partition_lba),.sectors_per_cluster(p``_spc), \
  .fat_start_lba(p``_fat_start),.data_start_lba(p``_data_start),.max_cluster(p``_max_cluster), \
  .resource_valid(p``_resource_valid), \
  .resource0_cluster(p``_rc[0]),.resource1_cluster(p``_rc[1]),.resource2_cluster(p``_rc[2]),.resource3_cluster(p``_rc[3]), \
  .resource0_size(p``_rs[0]),.resource1_size(p``_rs[1]),.resource2_size(p``_rs[2]),.resource3_size(p``_rs[3]), \
  .thumb_found(p``_thumb_found),.thumb_cluster(p``_thumb_cluster),.thumb_size(p``_thumb_size), \
  .audio_found(p``_audio_found),.audio_cluster(p``_audio_cluster),.audio_size(p``_audio_size), \
  .snd_valid(p``_snd_valid),.snd_clusters(p``_snd_clusters),.snd_sizes(p``_snd_sizes), \
  .font_found(p``_font_found),.text_found(p``_text_found), \
  .font_cluster(p``_font_cluster),.font_size(p``_font_size),.text_cluster(p``_text_cluster),.text_size(p``_text_size), \
  .edu_valid(p``_edu_valid),.voi_valid(p``_voi_valid),.voi_invalid(p``_voi_invalid), \
  .edu_clusters(p``_edu_clusters),.edu_sizes(p``_edu_sizes),.voi_clusters(p``_voi_clusters),.voi_sizes(p``_voi_sizes), \
  .sector_req(p``_sector_req),.sector_lba(p``_sector_lba), \
  .sector_busy(sector_busy),.sector_valid(sector_valid),.sector_byte(sector_byte), \
  .sector_byte_index(sector_byte_index),.sector_done(sector_done),.sector_error(sector_error)

`define SCANNER_WIRES(p) \
 wire [5:0] p``_directory_valid; wire [191:0] p``_directory_clusters; \
 wire p``_scan_busy,p``_scan_done; wire [7:0] p``_fs_error,p``_spc; \
 wire [31:0] p``_partition_lba,p``_fat_start,p``_data_start,p``_max_cluster; \
 wire [3:0] p``_resource_valid; wire [31:0] p``_rc[0:3],p``_rs[0:3]; \
 wire p``_thumb_found,p``_audio_found; wire [31:0] p``_thumb_cluster,p``_thumb_size,p``_audio_cluster,p``_audio_size; \
 wire [3:0] p``_snd_valid; wire [127:0] p``_snd_clusters,p``_snd_sizes; \
 wire p``_font_found,p``_text_found; wire [31:0] p``_font_cluster,p``_font_size,p``_text_cluster,p``_text_size; \
 wire [3:0] p``_edu_valid,p``_voi_valid,p``_voi_invalid; \
 wire [127:0] p``_edu_clusters,p``_edu_sizes,p``_voi_clusters,p``_voi_sizes; \
 wire p``_sector_req; wire [31:0] p``_sector_lba; \
 wire [2047:0] p``_all={p``_directory_valid,p``_directory_clusters,p``_scan_busy,p``_scan_done,p``_fs_error,p``_spc, \
  p``_partition_lba,p``_fat_start,p``_data_start,p``_max_cluster,p``_resource_valid, \
  p``_rc[0],p``_rc[1],p``_rc[2],p``_rc[3],p``_rs[0],p``_rs[1],p``_rs[2],p``_rs[3], \
  p``_thumb_found,p``_thumb_cluster,p``_thumb_size,p``_audio_found,p``_audio_cluster,p``_audio_size, \
  p``_snd_valid,p``_snd_clusters,p``_snd_sizes,p``_font_found,p``_text_found, \
  p``_font_cluster,p``_font_size,p``_text_cluster,p``_text_size, \
  p``_edu_valid,p``_voi_valid,p``_voi_invalid,p``_edu_clusters,p``_edu_sizes,p``_voi_clusters,p``_voi_sizes, \
  p``_sector_req,p``_sector_lba};

 `SCANNER_WIRES(r)
 `SCANNER_WIRES(n)
 fat32_volume_scanner_reference #(.MAX_VISITED_CLUSTERS(8),.DIRECTORY_ENABLE(DIRECTORY_ENABLE),
  .REUSE_GEOMETRY(REUSE_GEOMETRY),.SCAN_AUDIO(SCAN_AUDIO),.SCAN_TEXT(SCAN_TEXT),.SCAN_PUBLICITY(SCAN_PUBLICITY))
  ref_scanner(`SCANNER_PORTS(r));
 fat32_volume_scanner #(.MAX_VISITED_CLUSTERS(8),.DIRECTORY_ENABLE(DIRECTORY_ENABLE),
  .REUSE_GEOMETRY(REUSE_GEOMETRY),.SCAN_AUDIO(SCAN_AUDIO),.SCAN_TEXT(SCAN_TEXT),.SCAN_PUBLICITY(SCAN_PUBLICITY))
  new_scanner(`SCANNER_PORTS(n));

 integer seed=SEED;
 function integer urand(input integer n); begin urand=$unsigned($random(seed))%n; end endfunction
 function [31:0] rand32(input integer dummy); begin rand32=$random(seed); end endfunction

 // ---- Volume description ----
 reg use_mbr, active_fat1;
 reg [31:0] part_lba, total_sectors, fat_sectors, root_cluster, fat_start, data_start, clusters;
 reg [15:0] bps, reserved, root_entries, fat16, flags;
 reg [7:0] spc, fat_count;
 reg [7:0] mbr_type[0:3]; reg [31:0] mbr_lba[0:3];
 reg mbr_bpb_like, bad_signature;
 integer k;
 task new_volume;
  integer first;
  begin
   use_mbr=urand(3)!=0;
   part_lba=!use_mbr?0:(urand(4)==0?rand32(0):1+urand(5000));
   // Clean volume, then at most one field fault (about 40% of volumes).
   bps=16'd512;
   case(urand(8))0:spc=8'd128;1:spc=64;2:spc=16;3:spc=8;4,5:spc=4;6:spc=2;default:spc=1;endcase
   reserved=1+urand(64);
   fat_count=urand(4)==0?1:2;
   root_entries=0;fat16=0;
   case(urand(6))0,1,2:flags=0;3:flags=16'h0080|urand(fat_count);4:flags=16'h0081|(rand32(0)&16'hff00);default:flags=rand32(0)&16'hff7f;endcase
   clusters=100+urand(70000);
   fat_sectors=((clusters+2)>>7)+1+urand(3);
   bad_signature=0;
   root_cluster=2+urand(30);
   case(urand(40))
    0:bps=urand(2)?16'd1024:rand32(0);1:spc=0;2:spc=urand(2)?3:8'd255;3:reserved=0;
    4:fat_count=urand(2)?0:3+urand(250);5:root_entries=1+urand(512);6:fat16=1+urand(200);
    7:flags=16'h0080|(fat_count+urand(14));8:clusters=urand(2)?0:32'h0ffffff0+urand(16);
    9:fat_sectors=1+urand(4);10:root_cluster=urand(2);11:root_cluster=rand32(0);12:bad_signature=1;
    13:spc=urand(2)?8'd1:8'd2;
    default:;
   endcase
   case(urand(25))0:total_sectors=urand(2)?0:urand(50);
    1:total_sectors=32'hfffffff0;
    default:total_sectors=reserved+(fat_count==2?fat_sectors<<1:fat_sectors)+clusters*(spc==0?1:spc)+urand(8);
   endcase
   active_fat1=flags[7] && flags[0];
   fat_start=part_lba+reserved+(active_fat1?fat_sectors:0);
   data_start=part_lba+reserved+(fat_count==2?fat_sectors<<1:fat_sectors);
   first=urand(5);
   for(k=0;k<4;k=k+1)begin
    mbr_lba[k]=urand(3)==0?rand32(0):1+urand(5000);
    case(urand(4))0:mbr_type[k]=8'h0b;1:mbr_type[k]=8'h0c;2:mbr_type[k]=8'h07;default:mbr_type[k]=8'h00;endcase
    if(k<first && (mbr_type[k]==8'h0b || mbr_type[k]==8'h0c))mbr_type[k]=8'h83;
    if(k==first)begin mbr_type[k]=urand(2)?8'h0b:8'h0c;mbr_lba[k]=part_lba;end
   end
   mbr_bpb_like=urand(10)==0;
  end
 endtask

 reg [7:0] sector[0:511];
 integer i,e;
 task put16(input integer at,input [15:0] v); begin sector[at]=v[7:0];sector[at+1]=v[15:8]; end endtask
 task put32(input integer at,input [31:0] v); begin sector[at]=v[7:0];sector[at+1]=v[15:8];sector[at+2]=v[23:16];sector[at+3]=v[31:24]; end endtask
 task put_bpb;
  begin
   put16(11,bps);sector[13]=spc;put16(14,reserved);sector[16]=fat_count;
   put16(17,root_entries);put16(22,fat16);put32(32,total_sectors);put32(36,fat_sectors);
   put16(40,flags);put32(44,root_cluster);
  end
 endtask
 task put_name(input integer at,input [87:0] name); integer c; begin for(c=0;c<11;c=c+1)sector[at+c]=name[87-8*c-:8]; end endtask
 task build_sector(input [31:0] lba);
  reg [31:0] value;
  begin
   for(i=0;i<512;i=i+1)sector[i]=urand(4)==0?8'h00:rand32(0);
   if(lba==0 && use_mbr)begin
    if(mbr_bpb_like)put_bpb;
    for(k=0;k<4;k=k+1)begin sector[450+16*k]=mbr_type[k];put32(454+16*k,mbr_lba[k]);end
   end else if(lba==part_lba)put_bpb;
   else if(lba>=fat_start && lba<fat_start+fat_sectors)begin
    for(e=0;e<128;e=e+1)begin
     case(urand(20))0,1,2,3:value=32'h0ffffff8+urand(8)|(urand(4)==0?32'hf0000000:0);
      7:value=urand(2);8:value=rand32(0);9:value=((lba-fat_start)<<7)+e;
      10:value=clusters+1+urand(3);default:value=2+urand(40);
     endcase
     put32(4*e,value);
    end
   end else begin
    for(e=0;e<16;e=e+1)begin
     case(urand(16))
      0:put_name(32*e,"PIC1    BMP");1:put_name(32*e,"PIC4    BMP");2:put_name(32*e,"BGM     PCM");
      3:put_name(32*e,"SND2    PCM");4:put_name(32*e,"FONT    BIN");5:put_name(32*e,"TEXT    BIN");
      6:put_name(32*e,"EDU3    BMP");7:put_name(32*e,"VOI1    PCM");8:put_name(32*e,"THUMB   BMP");
      9:put_name(32*e,"PIC5    BMP");10:put_name(32*e,"SND9    PCM");
      11:begin put_name(32*e,"PIC2    BMP");sector[32*e+3]="1"+urand(4);end
      12:begin put_name(32*e,"VOI2    PCM");sector[32*e+3]="1"+urand(4);end
      default:;
     endcase
     // Unnamed entries keep random bytes; only an explicit marker ends the directory.
     if(sector[32*e]==8'h00)sector[32*e]=8'h41;
     if(urand(400)==0)sector[32*e]=8'h00;
     else if(urand(30)==0)sector[32*e]=8'he5;
     case(urand(8))0:sector[32*e+11]=8'h10;1:sector[32*e+11]=8'h08;2:sector[32*e+11]=8'h0f;3:sector[32*e+11]=8'h01;default:sector[32*e+11]=8'h20;endcase
     case(urand(10))0:value=urand(2);1:value=rand32(0);2:value=clusters+urand(3);default:value=2+urand(40);endcase
     put16(32*e+20,value[31:16]);put16(32*e+26,value[15:0]);
     case(urand(10))0:value=urand(54);1:value=rand32(0);2:value=1+2*urand(30000);3:value=0;default:value=54+urand(1<<20);endcase
     put32(32*e+28,value);
    end
   end
   if(lba==0 || lba==part_lba)begin
    sector[510]=bad_signature?8'h54:8'h55;sector[511]=8'haa;
   end
  end
 endtask

 // ---- Sector service model ----
 integer m_state=0,m_wait=0,m_index=0,m_gap=0,requests=0;
 reg [31:0] m_lba;
 always @(posedge clk)begin
  sector_valid<=0;sector_done<=0;sector_error<=0;
  case(m_state)
   0:if(r_sector_req)begin
     m_lba=r_sector_lba;build_sector(m_lba);requests=requests+1;
     sector_busy<=1;m_wait=urand(8);m_index=0;m_gap=0;m_state=1;
    end
   1:if(m_wait!=0)m_wait=m_wait-1;else m_state=2;
   2:if(urand(60000)==0)begin
     sector_done<=1;sector_error<=8'h11;m_state=4;
    end else if(m_gap!=0)m_gap=m_gap-1;
    else begin
     sector_valid<=1;sector_byte<=sector[m_index];sector_byte_index<=m_index;
     m_gap=urand(3)==0?urand(4):0;
     if(m_index==511)begin
      if(urand(3)==0)begin sector_done<=1;sector_error<=urand(200)==0?8'h12:8'h00;m_state=4;end
      else m_state=3;
     end
     m_index=m_index+1;
    end
   3:begin sector_done<=1;sector_error<=urand(200)==0?8'h12:8'h00;m_state=4;end
   4:begin sector_busy<=0;m_state=0;end
  endcase
 end

 // ---- Comparison and coverage ----
 integer cycles=0,mismatches=0,done_ok=0,done_bpb=0,done_sig=0,done_other=0,mbr_used=0,reuse_hits=0,mirror_used=0;
 integer resource_hits=0,publicity_hits=0,limit_hits=0,range_hits=0,loop_hits=0,mbr_late=0;
 always @(negedge clk)begin
  cycles=cycles+1;
  if(r_all!==n_all)begin
   mismatches=mismatches+1;
   if(mismatches<=5)$display("MISMATCH t=%0t state=%0d diff=%h",$time,ref_scanner.state,r_all^n_all);
  end
  if(r_scan_done)begin
   case(r_fs_error)8'h00:done_ok=done_ok+1;8'h21:done_bpb=done_bpb+1;8'h20:done_sig=done_sig+1;
    8'h26:limit_hits=limit_hits+1;8'h24:range_hits=range_hits+1;8'h23:loop_hits=loop_hits+1;default:done_other=done_other+1;endcase
   if(r_fs_error==0 && r_partition_lba!=0)mbr_used=mbr_used+1;
   if(r_fs_error==0 && r_resource_valid!=0)resource_hits=resource_hits+1;
   if(r_fs_error==0 && (r_edu_valid!=0 || r_voi_valid!=0 || r_voi_invalid!=0))publicity_hits=publicity_hits+1;
  end
  if(ref_scanner.state==0 && scan_start && REUSE_GEOMETRY && ref_scanner.geometry_valid)reuse_hits=reuse_hits+1;
  if(ref_scanner.state==7 && ref_scanner.flags[7] && ref_scanner.flags[0])mirror_used=mirror_used+1;
  if(ref_scanner.state==3 && !ref_scanner.bpb_ok && ref_scanner.mbr_match!=0 && !ref_scanner.mbr_match[0])mbr_late=mbr_late+1;
 end

 integer scan_count=0,idle_wait;
 initial begin
  if(!$value$plusargs("seed=%d",seed))seed=SEED;
  new_volume;
  repeat(5)@(posedge clk);rst_n<=1;
  while(scan_count<SCANS)begin
   idle_wait=urand(40);
   repeat(idle_wait)@(posedge clk);
   if(!r_scan_busy)begin
    // A cancel reset clears reused geometry, as the reader's scan_cancel does.
    if(urand(4)==0)begin new_volume;rst_n<=0;@(posedge clk);rst_n<=1;@(posedge clk);end
    case(urand(10))0,1,2,3,4:directory_cluster<=0;5:directory_cluster<=1;6:directory_cluster<=rand32(0);default:directory_cluster<=2+urand(40);endcase
    scan_start<=1;@(posedge clk);scan_start<=0;scan_count=scan_count+1;
    while(r_scan_busy || scan_start)begin
     @(posedge clk);
     if(urand(3000)==0)begin scan_start<=1;@(posedge clk);scan_start<=0;end
     if(urand(150000)==0)begin rst_n<=0;@(posedge clk);rst_n<=1;end
    end
   end
  end
  repeat(20)@(posedge clk);
  $display("COVERAGE cycles=%0d requests=%0d ok=%0d bpb=%0d sig=%0d range=%0d loop=%0d limit=%0d other=%0d mbr=%0d mbr_late=%0d reuse=%0d mirror=%0d resources=%0d publicity=%0d",
   cycles,requests,done_ok,done_bpb,done_sig,range_hits,loop_hits,limit_hits,done_other,mbr_used,mbr_late,reuse_hits,mirror_used,resource_hits,publicity_hits);
  if(mismatches!=0)$display("FAIL scanner mismatches=%0d",mismatches);
  else if(done_ok<20 || done_bpb<5 || mbr_used<5 || mbr_late<1 || (REUSE_GEOMETRY && reuse_hits<20) || mirror_used<1 || resource_hits<5 ||
          (SCAN_PUBLICITY && publicity_hits<3) || range_hits+loop_hits+limit_hits<3)
   $display("FAIL scanner coverage");
  else $display("PASS scanner S1 equivalence");
  $finish;
 end
endmodule
