`timescale 1ns/1ps
module tb_publicity_reader #(parameter integer GAP=0);
 reg clk=0;always #5 clk=~clk;
 reg rst=1,ss=0,ms=0,target=0,ls=0,cancel=0;reg [1:0] index=0;
 wire ready,done,scan_error,found,ld,le,wr,pv,raw_req,active;
 wire [31:0] raw_lba,pixel,fc,fz;wire [2:0] total,be;wire [7:0] fe;
 wire [3:0] pm,em,vm,mapped;wire [127:0] pc,pz,ec,ez,vc,vz;wire [1:0] slot;
 reg raw_valid=0,raw_end=0,raw_fail=0,ar=0;wire ab,ad;reg [7:0] raw_byte=0;
 integer fail_lba=-1;reg forbid_results=0,forbid_scan=0,seen_scan_error=0;
 reg [7:0] disk[0:16383];integer pos=0,base=0,gap_count=0,reads=0,boots=0,dirs=0;
 reg serving=0,released=1,expect_pixels=0;integer pixels=0,expected_cluster=0,scenario=0,found_mask=0;
 fat32_bmp_reader #(.SCAN_PUBLICITY(1),.LOAD_BY_INDEX(1),.CLK_FREQ_HZ(100000),.TIMEOUT_MS(100)) dut(
 .clk(clk),.rst(rst),.sd_init_done(1'b1),.scan_start(ss),.map_start(ms),.resource_publicity(target),.active_publicity(active),
 .pic_valid(pm),.pic_clusters(pc),.pic_sizes(pz),.edu_valid(em),.edu_clusters(ec),.edu_sizes(ez),
 .voi_valid(vm),.voi_clusters(vc),.voi_sizes(vz),.mapped_valid(mapped),.scan_found_slot(slot),
 .load_start(ls),.load_cancel(cancel),.load_cluster(32'd0),.load_size(32'd0),.load_index(index),
 .bmp_width(16'd2),.bmp_height(16'd2),.ready(ready),.scan_done(done),.scan_error(scan_error),
 .scan_found_valid(found),.scan_found_cluster(fc),.scan_found_size(fz),.scan_found_total(total),
 .load_done(ld),.load_error(le),.bmp_error(be),.fat_error(fe),.state_code(),
 .write_req(wr),.write_req_ack(wr),.write_ready(1'b1),.bmp_data_wr_en(pv),.bmp_data(pixel),
 .audio_found(),.audio_cluster(),.audio_size(),.snd_valid(),.snd_clusters(),.snd_sizes(),
 .font_found(),.text_found(),.font_cluster(),.font_size(),.text_cluster(),.text_size(),
 .audio_spc(),.audio_fat_lba(),.audio_data_lba(),.audio_max_cluster(),
 .a_req(ar),.a_lba(32'd24),.a_urgent(1'b0),.a_cancel(1'b0),.a_busy(ab),.a_valid(),.a_done(ad),.a_error(),.a_byte(),.a_index(),
 .sd_sec_read(raw_req),.sd_sec_read_addr(raw_lba),.sd_sec_read_data(raw_byte),
 .sd_sec_read_data_valid(raw_valid),.sd_sec_read_end(raw_end),.sd_sec_read_failed(raw_fail));
 always @(negedge clk)begin
 raw_valid=0;raw_end=0;raw_fail=0;
 if(rst)begin serving=0;released=1;end
 else if(!serving)begin
 if(!raw_req)released=1;
 if(raw_req && released)begin
 if(raw_lba>31)$fatal(1,"unexpected LBA %d",raw_lba);
 reads++;if(raw_lba==0)boots++;if(raw_lba==2 || raw_lba==3)dirs++;
 base=raw_lba*512;pos=0;gap_count=GAP;serving=1;released=0;end
 end else if(base/512==fail_lba && pos==8)begin raw_fail=1;serving=0;fail_lba=-1;end
 else if(gap_count>0)gap_count--;
 else if(pos<512)begin raw_valid=1;raw_byte=disk[base+pos];pos++;gap_count=GAP;
 if(pos==512)begin raw_end=1;serving=0;end end
 end
 always @(posedge clk)if(!rst)begin
 if(scan_error)seen_scan_error=1;
 if(forbid_results && (ld || le || (forbid_scan && done)))$fatal(1,"cancelled transaction reported completion");
 if(found)begin
 if(found_mask[slot])$fatal(1,"duplicate found event");found_mask=found_mask | (1<<slot);
 if(fc!==(active?ec[32*slot+:32]:pc[32*slot+:32]) || fz!=70)$fatal(1,"found metadata mismatch");
 end
 if(pv)begin
 if(!expect_pixels || pixels>=4)$fatal(1,"unexpected pixels");
 if(pixel!=={8'(pixels%2),8'(pixels/2),8'(expected_cluster),8'hff})$fatal(1,"pixel %d got=%h cluster=%d",pixels,pixel,expected_cluster);
 pixels++;
 end
 end
 task w32(input integer at,input reg [31:0] v);
 begin disk[at]=v;disk[at+1]=v>>8;disk[at+2]=v>>16;disk[at+3]=v>>24;end endtask
 task entry(input integer at,input reg [87:0] name,input integer c,input integer z);
 integer j;begin for(j=0;j<11;j++)disk[at+j]=name[(10-j)*8+:8];disk[at+11]=32;disk[at+26]=c;w32(at+28,z);end endtask
 task setup;
 integer j,k,at;begin
 for(j=0;j<16384;j++)disk[j]=0;
 disk[12]=2;disk[13]=1;disk[14]=1;disk[16]=1;w32(32,101);w32(36,1);w32(44,2);disk[510]=8'h55;disk[511]=8'haa;
 w32(520,3);w32(524,32'h0fffffff);
 for(j=0;j<16;j++)disk[1024+j*32]=8'he5;
 for(j=0;j<4;j++)begin
 entry(1024+j*32,{"PIC",8'("1"+j),"    BMP"},8+j,70);
 entry(1536+j*32,{"EDU",8'("1"+j),"    BMP"},16+j,70);
 entry(1664+j*32,{"VOI",8'("1"+j),"    PCM"},24+j,2+2*j);
 end
 for(k=0;k<8;k++)begin
 j=(k<4)?8+k:12+k;at=j*512;
 disk[at]="B";disk[at+1]="M";w32(at+2,70);w32(at+10,54);w32(at+14,40);w32(at+18,2);w32(at+22,2);disk[at+26]=1;disk[at+28]=24;
 for(j=0;j<4;j++)begin disk[at+54+(j/2)*8+(j%2)*3]=at/512;disk[at+55+(j/2)*8+(j%2)*3]=j/2;disk[at+56+(j/2)*8+(j%2)*3]=j%2;end
 end
 end endtask
 task cancel_current;
 begin
 @(negedge clk);forbid_scan=!done;forbid_results=1;cancel=1;@(negedge clk);cancel=0;
 wait(ready);repeat(5)@(negedge clk);
 forbid_results=0;scenario++;
 end endtask
 task scan(input bit pub,input reg [3:0] mask,input integer count);
 begin
 found_mask=0;target=pub;@(negedge clk);ss=1;@(negedge clk);ss=0;
 // Changing live target while busy must not change the latched set.
 target=!pub;wait(done);@(negedge clk);
 if(!ready || active!==pub || mapped!==mask || total!=count || found_mask!=mask || fe || be)$fatal(1,"scan scenario %d active=%b mapped=%h count=%d fe=%h",scenario,active,mapped,total,fe);
 scenario++;
 end endtask
 task remap(input bit pub,input reg [3:0] mask,input integer count);
 integer before_boot,before_dir;begin
 before_boot=boots;before_dir=dirs;found_mask=0;
 target=pub;@(negedge clk);ms=1;@(negedge clk);ms=0;target=!pub;
 wait(done);@(negedge clk);
 if(active!==pub || mapped!==mask || total!=count || found_mask!=mask || fe || be || !ready)$fatal(1,"remap %d",scenario);
 if(boots!=before_boot || dirs!=before_dir)$fatal(1,"remap physically rescanned");scenario++;
 end endtask
 task load(input reg [1:0] id,input integer cluster,input bit good);
 integer before_reads;reg saved_active;begin
 index=id;pixels=0;expected_cluster=cluster;expect_pixels=good;before_reads=reads;saved_active=active;
 @(negedge clk);ls=1;@(negedge clk);ls=0;
 if(good)begin
 wait(wr);@(negedge clk);ms=1;target=!saved_active;@(negedge clk);ms=0;
 end
 wait(ld || le);@(negedge clk);
 if(active!==saved_active || !ready || ld!==good || le===good || pixels!=(good?4:0))$fatal(1,"load slot=%d cluster=%d done=%b error=%b pixels=%d be=%d fe=%h",id,cluster,ld,le,pixels,be,fe);
 if(!good && (reads!=before_reads || wr))$fatal(1,"invalid load issued IO");
 expect_pixels=0;scenario++;
 end endtask
 integer i;
 initial begin
 setup();repeat(4)@(negedge clk);rst=0;
 // No mapping before a successful physical scan.
 load(0,0,0);
 target=1;ms=1;@(negedge clk);ms=0;@(negedge clk);
 if(fe!=8'h24)$fatal(1,"unscanned remap accepted");
 scan(0,15,4);
 if(pm!=15 || em!=15 || vm!=15)$fatal(1,"raw metadata masks");
 for(i=0;i<4;i++)if(pc[32*i+:32]!=8+i || ec[32*i+:32]!=16+i || pz[32*i+:32]!=70 || ez[32*i+:32]!=70 || vc[32*i+:32]!=24+i || vz[32*i+:32]!=2+2*i)$fatal(1,"raw metadata tables");
 for(i=0;i<4;i++)load(i,8+i,1);
 remap(1,15,4);for(i=0;i<4;i++)load(i,16+i,1);
 remap(0,15,4);load(0,8,1);remap(1,15,4);load(0,16,1);
 // Missing EDU2, malformed EDU4; source mask and accepted mask differ.
 setup();disk[1568]=8'he5;disk[19*512]=0;disk[1724]=3;
 scan(1,5,2);if(em!=13 || vm!=13)$fatal(1,"missing/raw metadata");
 load(0,16,1);load(1,0,0);load(2,18,1);load(3,0,0);
 // PIC compatibility still compresses holes, never mixes EDU.
 disk[1056]=8'he5;disk[1120]=8'he5;scan(0,5,2);
 load(0,8,1);load(1,10,1);load(2,0,0);remap(1,5,2);load(2,18,1);
 // Old card, publicity-only card, and empty card clear the other table.
 setup();disk[1536]=0;scan(0,15,4);if(em || vm || ec || ez || vc || vz)$fatal(1,"old card retained EDU");
 remap(1,0,0);load(0,0,0);remap(0,15,4);load(3,11,1);
 setup();for(i=0;i<4;i++)disk[1024+i*32]=8'he5;scan(1,15,4);if(pm || pc || pz)$fatal(1,"pure EDU retained PIC");load(3,19,1);
 setup();disk[1024]=0;scan(0,0,0);if(pm || em || vm)$fatal(1,"empty card");remap(1,0,0);load(0,0,0);
 // Cancel a physical scan while its first sector is in flight, then rescan.
 setup();target=1;@(negedge clk);ss=1;@(negedge clk);ss=0;
 wait(serving && pos==4);cancel_current();
 if(mapped || dut.metadata_ready || dut.volume_busy)$fatal(1,"cancelled scan retained state");
 load(0,0,0);scan(1,15,4);
 // Cancel logical preflight: metadata survives, partial map cannot load.
 found_mask=0;target=0;@(negedge clk);ms=1;@(negedge clk);ms=0;
 wait(serving && pos==4);cancel_current();
 if(mapped || !dut.metadata_ready)$fatal(1,"cancelled map state");
 load(0,0,0);remap(1,15,4);
 // File cancellation drains IO, keeps its map, and emits no false success.
 index=0;@(negedge clk);ls=1;@(negedge clk);ls=0;
 wait(serving && pos==4);cancel_current();
 if(mapped!=15)$fatal(1,"file cancel lost map");load(0,16,1);
 // A remap pulse while the audio client owns a sector must be ignored.
 @(negedge clk);ar=1;@(negedge clk);ar=0;wait(ab);@(negedge clk);
 target=0;ms=1;@(negedge clk);ms=0;
 if(!active || !done || !ready)$fatal(1,"audio-busy remap accepted");
 wait(ad);wait(!ab);scenario++;remap(0,15,4);
 // Header IO failure invalidates loads; retry reuses the discovered tables.
 found_mask=0;seen_scan_error=0;target=1;fail_lba=16;@(negedge clk);ms=1;@(negedge clk);ms=0;
 wait(done);@(negedge clk);if(!seen_scan_error || fe!=8'h10 || dut.mapping_ready)$fatal(1,"header IO failure error=%b fe=%h mapped=%b",seen_scan_error,fe,dut.mapping_ready);scenario++;
 load(0,0,0);remap(1,15,4);load(3,19,1);
 // A failed physical rescan cannot leave an old metadata table usable.
 found_mask=0;seen_scan_error=0;fail_lba=0;@(negedge clk);ss=1;@(negedge clk);ss=0;
 wait(done);@(negedge clk);if(!seen_scan_error || !fe || dut.metadata_ready)$fatal(1,"physical scan IO failure");scenario++;
 load(0,0,0);scan(0,15,4);
 $display("PASS publicity reader %0d operations GAP=%0d reads=%0d: actual pixels, holes, remap without rescan, legacy/pure/empty, cancel/drain, audio-busy, IO recovery",scenario,GAP,reads);$finish;
 end
 initial begin #15000000;$fatal(1,"reader watchdog");end
endmodule
