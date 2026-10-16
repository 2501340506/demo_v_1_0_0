`timescale 1ns/1ps
module tb_publicity_scan #(parameter integer GAP=0);
 reg clk=0;always #5 clk=~clk;reg rst=1,start=0;
 wire done,req,busy;wire [31:0] lba;wire [7:0] err;
 wire [3:0] pic,edu,voi,snd;wire [127:0] ec,ez,vc,vz;
 wire af,ff,tf;reg sbusy=0,valid=0,sdone=0;reg [7:0] bd=0;reg [8:0] idx=0;
 reg [7:0] disk[0:2559];integer pos=0,base=0,gap_count=0,reads=0,scenario=0;
 fat32_volume_scanner #(.SCAN_AUDIO(1),.SCAN_TEXT(1),.SCAN_PUBLICITY(1),.MAX_VISITED_CLUSTERS(4)) dut(
 .clk(clk),.rst_n(!rst),.scan_start(start),.scan_busy(busy),.scan_done(done),.fs_error(err),
 .partition_lba(),.sectors_per_cluster(),.fat_start_lba(),.data_start_lba(),.max_cluster(),
 .resource0_cluster(),.resource1_cluster(),.resource2_cluster(),.resource3_cluster(),
 .resource0_size(),.resource1_size(),.resource2_size(),.resource3_size(),
 .audio_cluster(),.audio_size(),.snd_clusters(),.snd_sizes(),
 .font_cluster(),.font_size(),.text_cluster(),.text_size(),
 .resource_valid(pic),.snd_valid(snd),.audio_found(af),.font_found(ff),.text_found(tf),
 .edu_valid(edu),.edu_clusters(ec),.edu_sizes(ez),.voi_valid(voi),.voi_clusters(vc),.voi_sizes(vz),
 .sector_req(req),.sector_lba(lba),.sector_busy(sbusy),.sector_valid(valid),.sector_byte(bd),
 .sector_byte_index(idx),.sector_done(sdone),.sector_error(8'd0));
 always @(negedge clk)begin
 valid=0;sdone=0;
 if(rst)begin sbusy=0;pos=0;gap_count=0;end
 else if(!sbusy && req)begin if(lba>4)$fatal(1,"unexpected LBA");base=lba*512;pos=0;sbusy=1;reads++;end
 else if(sbusy)begin
 if(pos<512 && gap_count<GAP)gap_count++;
 else if(pos<512)begin valid=1;bd=disk[base+pos];idx=pos;pos++;gap_count=0;
 // Exercise the last byte with done in the same cycle.
 if(pos==512)begin sdone=1;sbusy=0;end end
 end
 end
 task w32(input integer at,input reg [31:0] v);
 begin disk[at]=v;disk[at+1]=v>>8;disk[at+2]=v>>16;disk[at+3]=v>>24;end endtask
 task entry(input integer slot,input reg [87:0] name,input integer c,input reg [31:0] z,input reg [7:0] attr);
 integer j,at;begin at=1024+slot*32;for(j=0;j<11;j++)disk[at+j]=name[(10-j)*8+:8];
 disk[at+11]=attr;disk[at+20]=c>>16;disk[at+21]=c>>24;disk[at+26]=c;disk[at+27]=c>>8;w32(at+28,z);end endtask
 task setup;
 integer j;begin
 for(j=0;j<2560;j++)disk[j]=0;
 disk[12]=2;disk[13]=1;disk[14]=1;disk[16]=1;w32(32,101);w32(36,1);w32(44,2);disk[510]=8'h55;disk[511]=8'haa;
 w32(520,3);w32(524,4);w32(528,32'h0fffffff);
 for(j=0;j<48;j++)disk[1024+j*32]=8'he5;
 reads=0;
 end endtask
 task legacy;
 begin
 entry(0,"PIC1    BMP",5,100,32);entry(1,"PIC2    BMP",6,100,32);
 entry(2,"PIC3    BMP",7,100,32);entry(3,"PIC4    BMP",8,100,32);
 entry(4,"BGM     PCM",9,2,32);
 entry(5,"SND1    PCM",10,2,32);entry(6,"SND2    PCM",11,2,32);
 entry(7,"SND3    PCM",12,2,32);entry(8,"SND4    PCM",13,2,32);
 entry(9,"FONT    BIN",14,4096,32);entry(10,"TEXT    BIN",15,354,32);
 end endtask
 task named(input integer slot,input integer id);
 reg [87:0] name;begin
 if(id<4)name={"EDU",8'("1"+id),"    BMP"};else name={"VOI",8'("1"+id-4),"    PCM"};
 entry(slot,name,20+id,id<4 ? 32'h12345678+id : 32'h87654320+2*id,32);
 end endtask
 task scan(input reg [3:0] em,vm,input reg [7:0] expected_error);
 begin
 @(negedge clk);start=1;@(negedge clk);start=0;wait(done);@(negedge clk);
 if(err!==expected_error || edu!==em || voi!==vm)$fatal(1,"scenario %0d err=%h edu=%h voi=%h",scenario,err,edu,voi);
 scenario++;
 end endtask
 task fullcheck;
 integer j;begin
 if(pic!=15 || snd!=15 || !af || !ff || !tf)$fatal(1,"legacy changed");
 for(j=0;j<4;j++)begin
 if(ec[32*j+:32]!==32'(20+j) || ez[32*j+:32]!==32'h12345678+j ||
 vc[32*j+:32]!==32'(24+j) || vz[32*j+:32]!==32'h87654328+2*j)$fatal(1,"metadata slot %0d",j);
 end
 end endtask
 integer a,b,c,d,j,k,t;integer order[0:18];reg [31:0] rng=32'h13579bdf;
 initial begin
 setup();repeat(4)@(negedge clk);rst=0;
 // Every ordering of four EDU pages, paired VOI reversed, after full legacy.
 for(a=0;a<4;a++)for(b=0;b<4;b++)for(c=0;c<4;c++)for(d=0;d<4;d++)
 if(a!=b && a!=c && a!=d && b!=c && b!=d && c!=d)begin
 setup();legacy();named(16,a);named(17,b);named(18,c);named(19,d);
 for(j=0;j<4;j++)named(32+j,7-j);
 disk[1024+36*32]=0;scan(15,15,0);fullcheck();if(reads!=6)$fatal(1,"tail/chain skipped %0d",reads);
 end
 // Deterministic Fisher-Yates permutations of all 19 legacy/publicity files.
 for(k=0;k<64;k++)begin
 setup();legacy();for(j=0;j<19;j++)order[j]=j;
 for(j=18;j>0;j--)begin rng=rng*1664525+1013904223;t=rng%(j+1);a=order[j];order[j]=order[t];order[t]=a;end
 // Move legacy entries through a temporary area.
 for(j=0;j<11*32;j++)disk[2048+j]=disk[1024+j];
 for(j=0;j<32;j++)disk[1024+j*32]=8'he5;
 for(j=0;j<19;j++)begin
 if(order[j]<11)for(t=0;t<32;t++)disk[1024+j*32+t]=disk[2048+order[j]*32+t];
 else named(j,order[j]-11);
 end
 disk[1024+19*32]=0;scan(15,15,0);fullcheck();
 end
 setup();legacy();disk[1536]=0;scan(0,0,0);if(reads!=4)$fatal(1,"old card");
 if(ec || ez || vc || vz)$fatal(1,"stale metadata");
 setup();for(j=0;j<4;j++)named(j,j);scan(15,0,0);if(reads!=7)$fatal(1,"EOC missing voice"); // boot, 3 dirs, 3 FAT
 setup();named(0,0);named(1,2);named(2,4);named(3,6);disk[1152]=0;scan(5,5,0);
 setup();
 entry(0,"EDU1    BMP",1,100,32);entry(1,"EDU1    BMP",20,53,32);named(2,0);
 entry(3,"EDU1    BMP",99,999,32); // first metadata-valid wins
 entry(4,"VOI1    PCM",24,3,32);entry(5,"VOI1    PCM",24,0,32);named(6,4);
 entry(7,"VOI1    PCM",99,2,32);
 entry(8,"EDU2    BMP",21,100,16);entry(9,"EDU2    BMP",21,100,8);
 entry(10,"EDU2    BMP",21,100,15);entry(11,"EDU2    PNG",21,100,32);
 entry(12,"EDU2    BMP",101,100,32); // out of range
 entry(13,"VOI2    PCM",25,2,32);disk[1024+13*32]=8'he5;
 entry(14,"edu3    BMP",22,100,32);
 disk[1504]=0;scan(1,1,0);
 if(ec[31:0]!=20 || ez[31:0]!=32'h12345678 || vc[31:0]!=24 || vz[31:0]!=32'h87654328)$fatal(1,"invalid/duplicate");
 setup();disk[1024]=0;named(1,0);scan(0,0,0);if(ec || vc)$fatal(1,"zero marker");
 setup();w32(520,2);scan(0,0,8'h23);
 setup();w32(520,1);scan(0,0,8'h24);
 setup();w32(528,2);scan(0,0,8'h26);
 $display("PASS publicity scanner %0d scenarios GAP=%0d",scenario,GAP);$finish;
 end
 initial begin #30000000;$fatal(1,"watchdog");end
endmodule
