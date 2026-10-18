`timescale 1ns/1ps
module tb_lfn;
 reg clk=0,rst=1,clear=0,valid=0;
 always #5 clk=~clk;
 reg [4:0] index;reg [7:0] data;
 wire [5:0] matched;wire [31:0] cluster;
 reg [7:0] bytes[0:262143];reg [37:0] expected[0:8191];
 integer count,checks=0,hits=0,seed=61;
 fat32_lfn_directories dut(clk,rst,clear,valid,index,data,matched,cluster);
 initial begin
  if(!$value$plusargs("ENTRIES=%d",count))$fatal(1,"entry count");
  $readmemh("lfn_bytes.hex",bytes,0,count*32-1);
  $readmemh("lfn_expected.hex",expected,0,count-1);
  repeat(3)@(negedge clk);rst=0;
  for(integer e=0;e<count;e++)begin
   // This includes arbitrary gaps at sector/cluster boundaries without
   // resetting the parser: directory entries can straddle a FAT chain walk.
   repeat($urandom(seed)%7)@(negedge clk);
   for(integer b=0;b<32;b++)begin
    @(negedge clk);valid=1;index=b;data=bytes[e*32+b];
    @(posedge clk);#1;
    if(b==31)begin
     if(matched!==expected[e][37:32] || (matched!=0 && cluster!==expected[e][31:0]))
      $fatal(1,"entry=%0d got=%h/%h expected=%h",e,matched,cluster,expected[e]);
     if(matched!=0)hits++;
     checks++;
    end else if(matched!=0)$fatal(1,"early directory commit");
    @(negedge clk);valid=0;
   end
  end
  if(hits!=180)$fatal(1,"hit coverage %0d",hits);
  $display("PASS VFAT stream: %0d entries, %0d exact names; Unicode, aliases, checksum, sequence, deleted/file/prefix/suffix and boundary pauses",checks,hits);
  $finish;
 end
endmodule
