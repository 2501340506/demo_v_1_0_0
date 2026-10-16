`timescale 1ns/1ps
// Sparse sector transport, real BPB/layout and directory parser. Exercise
// carry boundaries in the pipelined cluster check with contiguous bytes.
module tb_m3_scan_bounds;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,start=0,sbusy=0,valid=0,sdone=0;
 reg [7:0] bd=0;reg [8:0] idx=0;
 wire req,done;wire [31:0] lba,max_cluster;wire [7:0] err;
 wire [3:0] edu,voi;wire [127:0] ec,ez,vc,vz;
 reg [7:0] boot[0:511],dir[0:511];
 reg [31:0] bound,fats,data_lba,c;integer pos=0,kind=0,reads=0,cases=0,i,j;
 fat32_volume_scanner #(.SCAN_PUBLICITY(1)) dut(
 .clk(clk),.rst_n(!rst),.scan_start(start),.scan_done(done),.scan_busy(),.fs_error(err),
 .partition_lba(),.sectors_per_cluster(),.fat_start_lba(),.data_start_lba(),.max_cluster(max_cluster),
 .resource_valid(),.resource0_cluster(),.resource1_cluster(),.resource2_cluster(),.resource3_cluster(),
 .resource0_size(),.resource1_size(),.resource2_size(),.resource3_size(),
 .audio_found(),.audio_cluster(),.audio_size(),.snd_valid(),.snd_clusters(),.snd_sizes(),
 .font_found(),.text_found(),.font_cluster(),.font_size(),.text_cluster(),.text_size(),
 .edu_valid(edu),.voi_valid(voi),.edu_clusters(ec),.edu_sizes(ez),.voi_clusters(vc),.voi_sizes(vz),
 .sector_req(req),.sector_lba(lba),.sector_busy(sbusy),.sector_valid(valid),
 .sector_byte(bd),.sector_byte_index(idx),.sector_done(sdone),.sector_error(8'd0));
 always @(negedge clk)begin
  valid=0;sdone=0;
  if(rst)begin sbusy=0;pos=0;end
  else if(!sbusy && req)begin
   if(lba==0)kind=0;else if(lba==data_lba)kind=1;else $fatal(1,"LBA %h",lba);
   sbusy=1;pos=0;reads++;
  end else if(sbusy)begin
   valid=1;bd=kind?dir[pos]:boot[pos];idx=pos;pos++;
   if(pos==512)begin sbusy=0;sdone=1;end
  end
 end
 task b32(input integer at,input reg [31:0] v);
  begin for(integer k=0;k<4;k++)boot[at+k]=v>>(8*k);end
 endtask
 task entry(input integer slot,input reg [87:0] name,input reg [31:0] cluster,input reg [31:0] size);
  integer at,k;begin
   at=slot*32;for(k=0;k<11;k++)dir[at+k]=name[(10-k)*8+:8];
   dir[at+11]=32;dir[at+20]=cluster>>16;dir[at+21]=cluster>>24;
   dir[at+26]=cluster;dir[at+27]=cluster>>8;
   for(k=0;k<4;k++)dir[at+28+k]=size>>(8*k);
  end
 endtask
 task run_case(input reg [31:0] limit,cluster);
  reg good;begin
   bound=limit;c=cluster;fats=(bound>>7)+1;data_lba=1+fats;reads=0;
   for(integer k=0;k<512;k++)begin boot[k]=0;dir[k]=0;end
   boot[12]=2;boot[13]=1;boot[14]=1;boot[16]=1;
   b32(32,bound+fats);b32(36,fats);b32(44,2);boot[510]=8'h55;boot[511]=8'haa;
   entry(0,"EDU1    BMP",cluster,54);entry(1,"VOI1    PCM",cluster,2);
   // A malformed first duplicate must not claim a slot. The second valid
   // duplicate is contiguous and differs in its low cluster bits.
   entry(2,"EDU2    BMP",bound+1,54);entry(3,"EDU2    BMP",2,54);
   @(negedge clk);start=1;@(negedge clk);start=0;wait(done);@(negedge clk);
   good=(cluster>=2 && cluster<=limit);
   if(err || max_cluster!==limit || edu!==(good?4'b0011:4'b0010) ||
      voi!==(good?4'b0001:4'b0000) || reads!=2)$fatal(1,"bounds limit=%h cluster=%h err=%h E=%b V=%b",limit,cluster,err,edu,voi);
   if(ec[63:32]!=2 || ez[63:32]!=54)$fatal(1,"invalid duplicate claimed slot");
   if(good && (ec[31:0]!==cluster || vc[31:0]!==cluster || ez[31:0]!=54 || vz[31:0]!=2))$fatal(1,"metadata");
   cases++;
  end
 endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;
  for(i=0;i<5;i++)begin
   case(i)0:bound=32'hffff;1:bound=32'h10000;2:bound=32'h10001;3:bound=32'h1ffff;4:bound=32'h1000001;endcase
   for(j=0;j<5;j++)begin
    case(j)0:c=1;1:c=2;2:c=bound-1;3:c=bound;4:c=bound+1;endcase
    run_case(bound,c);
   end
  end
  $display("PASS M3 scanner bounds: %0d sparse-card cases, contiguous bytes, high/low carry and invalid duplicate",cases);$finish;
 end
 initial begin #2000000;$fatal(1,"watchdog");end
endmodule
