`timescale 1ns/1ps
module tb_m5_loader #(parameter GAP=0);
 reg clk=0;always #5 clk=~clk;reg rst=1,start=0,ff=1,tf=1;
 reg [31:0] fc=2,tc=20,fz=4096,tz=777;
 wire done,fv,tv,we,wt,req;wire [7:0] count,wd;wire [12:0] bytes;
 wire [11:0] wa;wire [31:0] lba;
 reg busy=0,valid=0,sdone=0;reg [7:0] data=0,error=0;reg [8:0] idx=0;
 integer sector=0,pos=0,gap=0,fn=0,tn=0,tests=0,fault=0,reads=0;
 bin_to_bram_loader dut(.clk(clk),.rst(rst),.start(start),.font_found(ff),.text_found(tf),
  .font_cluster(fc),.font_size(fz),.text_cluster(tc),.text_size(tz),.spc(8'd1),
  .fat_lba(32'd1),.data_lba(32'd100),.max_cluster(32'd100),.done(done),
  .font_valid(fv),.text_valid(tv),.font_count(count),.text_bytes(bytes),
  .wr_en(we),.wr_text(wt),.wr_addr(wa),.wr_data(wd),.sector_req(req),.sector_lba(lba),
  .sector_busy(busy),.sector_valid(valid),.sector_done(sdone),.sector_byte(data),.sector_error(error),.sector_index(idx));
 function [7:0] content(input integer sec,at);
  integer c,v;begin
   if(sec==1)begin
    c=at/4;v=(fault==2 && c==2)?32'h0fffffff:c+1;
    content=(v>>((at%4)*8))&255;
   end else content=((sec-100)*512+at)*7+3;
  end
 endfunction
 always @(negedge clk)begin
  valid=0;sdone=0;
  if(rst)begin busy=0;pos=0;end
  else if(!busy && req)begin sector=lba;pos=0;gap=0;busy=1;error=0;reads++;end
  else if(busy)begin
   if(pos<512 && gap<GAP)gap++;
   else if(pos<512)begin valid=1;idx=pos;data=content(sector,pos);pos++;gap=0;end
   else begin sdone=1;error=(fault==1 && sector==100)?8'h10:0;busy=0;end
  end
 end
 always @(posedge clk)if(we)begin
  if(wt)begin
   if(wa!==tn[11:0] || wd!==8'(((tc-2)*512+tn)*7+3) || tn>=tz)$fatal(1,"TEXT write %d %h",wa,wd);
   tn++;
  end else begin
   if(wa!==fn[11:0] || wd!==8'(((fc-2)*512+fn)*7+3) || fn>=fz)$fatal(1,"FONT write %d %h",wa,wd);
   fn++;
  end
 end
 task run(input bit expect_f,expect_t,input integer expected_fn,expected_tn);
  begin
   fn=0;tn=0;reads=0;@(negedge clk);start=1;@(negedge clk);start=0;
   wait(done);@(negedge clk);
   if(fv!==expect_f || tv!==expect_t || fn!=expected_fn || tn!=expected_tn)$fatal(1,"case %d: valid=%b%b bytes=%d/%d",tests,fv,tv,fn,tn);
   if(fv && count!=fz/32 || tv && bytes!=tz)$fatal(1,"published sizes");
   tests++;
  end
 endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;
  run(1,1,4096,777); // eight clusters, exact maximum FONT and partial TEXT sector
  fz=416;tz=44;run(1,1,416,44);
  ff=0;run(0,1,0,44);tf=0;run(0,0,0,0);if(reads)$fatal(1,"absent resource requested");
  ff=1;tf=1;fz=415;tz=4097;run(0,0,0,0);if(reads)$fatal(1,"invalid sizes requested");
  fz=417;tz=43;run(0,0,0,0);
  fz=4096;tz=44;fc=1;run(0,1,0,44);fc=2;
  fault=1;run(0,1,512,44);
  fault=2;run(0,1,512,44);
  fault=0;fz=416;run(1,1,416,44);
  $display("PASS M5 loader: %0d cases GAP=%0d; 4096 bytes/eight clusters, offsets, final partial sector, missing/bad sizes/cluster/sector/early EOF and reload",tests,GAP);$finish;
 end
 initial begin #2000000;$fatal(1,"loader watchdog");end
endmodule
