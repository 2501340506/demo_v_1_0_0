`timescale 1ns/1ps
module tb_directories;
 parameter CASE_ID=0;
 reg clk=0,rst=1,start=0;
 always #5 clk=~clk;
 wire req,busy,done;wire [31:0] lba;
 reg serving=0,valid=0,sdone=0;
 reg [7:0] data=0,error=0;
 reg [8:0] index=0;
 wire [7:0] fs_error;wire [5:0] dirs;wire [191:0] clusters;wire [3:0] pics;
 reg [31:0] meta[0:11],lbas[0:63];reg [7:0] media[0:32767];
 integer count=0,gap=0,slot=-1,k,requests=0;
 fat32_volume_scanner #(.DIRECTORY_ENABLE(1),.SCAN_PUBLICITY(1)) dut(
 .clk(clk),.rst_n(!rst),.scan_start(start),.directory_cluster(meta[0]),
 .directory_valid(dirs),.directory_clusters(clusters),.scan_busy(),.scan_done(done),.fs_error(fs_error),
 .thumb_found(),.image_index(4'd0),.image_cluster(),.image_size(),.audio_index(4'd0),.audio_entry_cluster(),.audio_entry_size(),.resource_valid(pics),.voi_invalid(),.voi_valid(),.edu_valid(),.text_size(),.text_cluster(),.font_size(),.font_cluster(),.text_found(),.font_found(),.snd_valid(),.audio_found(),.max_cluster(),.data_start_lba(),.fat_start_lba(),.sectors_per_cluster(),.partition_lba(),.sector_req(req),.sector_lba(lba),.sector_busy(serving),
 .sector_valid(valid),.sector_byte(data),.sector_byte_index(index),.sector_done(sdone),.sector_error(error));
 always @(negedge clk)begin
  valid=0;sdone=0;error=0;
  if(!rst)begin
   if(!serving && req)begin
    slot=-1;for(k=0;k<meta[3];k++)if(lbas[k]==lba)slot=k;
    if(slot<0)$fatal(1,"unmapped image sector %0d",lba);
    serving=1;count=0;gap=3;requests++;
   end else if(serving)begin
    if(gap>0)gap--;
    else if(lba==meta[4])begin error=8'h10;sdone=1;serving=0;end
    else if(count<512)begin valid=1;index=count;data=media[slot*512+count];count++;gap=count%3;end
    else begin sdone=1;serving=0;end
   end
  end
 end
 string prefix;
 initial begin
  prefix=$sformatf("case%0d_",CASE_ID);
  $readmemh({prefix,"meta.hex"},meta,0,11);$readmemh({prefix,"lba.hex"},lbas,0,meta[3]-1);
  $readmemh({prefix,"bytes.hex"},media,0,meta[3]*512-1);
  repeat(4)@(negedge clk);rst=0;@(negedge clk);start=1;@(negedge clk);start=0;
  wait(done);@(negedge clk);
  if(fs_error!==8'(meta[2]))$fatal(1,"error got %h expected %h",fs_error,meta[2]);
  if(!fs_error)begin
   if(dirs!==6'(meta[1]) || pics!==4'(meta[11]))$fatal(1,"directory/file masks got %b/%b",dirs,pics);
   for(k=0;k<6;k++)if(dirs[k] && clusters[k*32+:32]!==meta[5+k])$fatal(1,"directory identity slot %0d",k);
  end
  $display("PASS directories case=%0d requests=%0d VFAT Unicode/shuffled SFN/order/cross-cluster/file/error",CASE_ID,requests);$finish;
 end
 initial begin #5000000;$fatal(1,"watchdog");end
endmodule
