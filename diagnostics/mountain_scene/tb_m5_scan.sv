`timescale 1ns/1ps
module tb_m5_scan #(parameter integer GAP=0);
 reg clk=0;always #5 clk=~clk;reg rst=1,start=0;
 wire ff,tf;wire [31:0] fc,fz,tc,tz;wire [3:0] snd;wire [127:0] clusters,sizes;
 wire busy,done,req,found;wire [7:0] err;wire [31:0] lba,cluster,size;wire [3:0] pics;
 reg sbusy=0,valid=0,sdone=0;reg [7:0] byte_data=0;reg [8:0] idx=0;
 reg [7:0] disk[0:2047];integer base=0,pos=0,reads=0,scenario=0,gap_count=0;
 fat32_volume_scanner #(.SCAN_AUDIO(1),.SCAN_TEXT(1)) dut(
 .clk(clk),.rst_n(!rst),.scan_start(start),.scan_busy(busy),.scan_done(done),.fs_error(err),
 .font_found(ff),.text_found(tf),.font_cluster(fc),.font_size(fz),.text_cluster(tc),.text_size(tz),
 .partition_lba(),.sectors_per_cluster(),.fat_start_lba(),.data_start_lba(),.max_cluster(),
 .resource_valid(pics),.resource0_cluster(),.resource1_cluster(),.resource2_cluster(),.resource3_cluster(),
 .resource0_size(),.resource1_size(),.resource2_size(),.resource3_size(),
 .snd_valid(snd),.snd_clusters(clusters),.snd_sizes(sizes),.audio_found(found),.audio_cluster(cluster),.audio_size(size),
 .sector_req(req),.sector_lba(lba),.sector_busy(sbusy),.sector_valid(valid),.sector_byte(byte_data),
 .sector_byte_index(idx),.sector_done(sdone),.sector_error(8'd0));
 always @(negedge clk)begin
  valid=0;sdone=0;
  if(rst)begin sbusy=0;pos=0;end
  else if(!sbusy && req)begin
   if(lba>3)$fatal(1,"unexpected directory LBA %d",lba);
   base=lba*512;pos=0;sbusy=1;reads++;
  end else if(sbusy)begin
   if(pos<512 && gap_count<GAP)gap_count++;
   else if(pos<512)begin valid=1;byte_data=disk[base+pos];idx=pos;pos++;gap_count=0;end
   else begin sdone=1;sbusy=0;end
  end
 end
 task word32(input integer at,input reg [31:0] x);
 begin disk[at]=x[7:0];disk[at+1]=x[15:8];disk[at+2]=x[23:16];disk[at+3]=x[31:24];end endtask
 task entry(input integer at,input reg [87:0] name,input integer c,input reg [31:0] bytes,input reg [7:0] attr);
 integer j;begin for(j=0;j<11;j++)disk[at+j]=name[(10-j)*8+:8];disk[at+11]=attr;disk[at+26]=c;word32(at+28,bytes);end endtask
 task setup;
 integer j;begin
  for(j=0;j<2048;j++)disk[j]=0;
  disk[11]=0;disk[12]=2;disk[13]=1;disk[14]=1;disk[16]=1;
  word32(32,101);word32(36,1);word32(44,2);disk[510]=8'h55;disk[511]=8'haa;
  word32(512+8,3);word32(512+12,32'h0fffffff);
  for(j=0;j<16;j++)disk[1024+32*j]=8'he5;
 end endtask
 task scan(input integer mask,input bit af,input reg [31:0] bytes);
 begin
  @(posedge clk);#1;start=1;@(posedge clk);#1;start=0;
  wait(done);@(posedge clk);#1;
  if(err || pics!==mask[3:0] || found!==af)$fatal(1,"scan %0d: err=%h pics=%h found=%b",scenario,err,pics,found);
  if(af && (cluster!=10 || size!==bytes))$fatal(1,"audio metadata %h %h",cluster,size);
  if(!af && (cluster!=0 || size!=0))$fatal(1,"rescan retained metadata");
  scenario++;
 end endtask
 initial begin
  setup();repeat(4)@(posedge clk);#1;rst=0;
  entry(1024,"PIC1    BMP",4,100,32);entry(1056,"PIC2    BMP",5,100,32);
  entry(1088,"PIC3    BMP",6,100,32);entry(1120,"PIC4    BMP",7,100,32);
  entry(1152,"BGM     PCM",10,2,32);
  entry(1184,"SND1    PCM",11,42,32);entry(1216,"SND2    PCM",12,42,32);
  entry(1248,"SND3    PCM",13,42,32);entry(1280,"SND4    PCM",14,42,32);
  entry(1536,"FONT    BIN",20,4096,1);entry(1568,"TEXT    BIN",21,354,32);
  scan(15,1,2);
  if(reads!=4 || !ff || !tf || fc!=20 || fz!=4096 || tc!=21 || tz!=354)$fatal(1,"early finish/resource metadata");
  setup();entry(1024,"FONT    BIN",20,416,32);entry(1056,"FONT    BIN",22,999,32);
  entry(1088,"TEXT    BIN",21,44,32);disk[1120]=0;scan(0,0,0);
  if(!ff || !tf || fc!=20 || fz!=416 || tz!=44)$fatal(1,"duplicate");
  setup();disk[1024]=0;scan(0,0,0);if(ff || tf || fc || fz || tc || tz)$fatal(1,"rescan clear");
  setup();entry(1024,"FONT    BIN",20,416,16);entry(1056,"TEXT    BIN",21,44,8);
  entry(1088,"FONT    TXT",20,416,32);entry(1120,"TEXT    PCM",21,44,32);disk[1152]=0;scan(0,0,0);
  if(ff || tf)$fatal(1,"attributes/extensions");
  setup();entry(1024,"FONT    BIN",20,32'h12345678,32);disk[1056]=0;scan(0,0,0);
  if(!ff || tf || fz!=32'h12345678)$fatal(1,"FONT only/full size");
  setup();entry(1024,"TEXT    BIN",21,32'h87654321,32);disk[1056]=0;scan(0,0,0);
  if(ff || !tf || tz!=32'h87654321)$fatal(1,"TEXT only/full size");
  $display("PASS M5 scan: six scenarios GAP=%0d; FAT directory chain, resources after PIC/BGM/SND, duplicate, attributes/extensions, missing and rescan",GAP);$finish;
 end
 initial begin #1000000;$fatal(1,"scan watchdog");end
endmodule
