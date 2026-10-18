`timescale 1ns/1ps
module header_compare #(parameter RANGE=0,ALLOW=0)(input clk,rst,file_valid,input [7:0] b,input [31:0] offset);
 wire a,z,c,y;wire complete;
 bmp_header_check #(.ALLOW_32(ALLOW),.RANGE_DIMENSIONS(RANGE)) dut(.clk(clk),.rst(rst),.file_valid(file_valid),.file_byte(b),.file_byte_offset(offset),.bmp_width(16'd320),.bmp_height(16'd240),.header_match(a),.skip_format(c),.header_complete(complete));
 bmp_header_check_reference #(.ALLOW_32(ALLOW),.RANGE_DIMENSIONS(RANGE)) ref_dut(.clk(clk),.rst(rst),.file_valid(file_valid),.file_byte(b),.file_byte_offset(offset),.bmp_width(16'd320),.bmp_height(16'd240),.header_match(z),.skip_format(y));
 always @(negedge clk)if(!rst && complete && ({a,c} !== {z,y}))$fatal(1,"header decision RANGE=%d ALLOW=%d byte=%d actual=%b expected=%b",RANGE,ALLOW,offset,{a,c},{z,y});
endmodule
module tb_header_equivalence;
 reg clk=0,rst=1,v=0;always #5 clk=~clk;
 reg [7:0] b=0;reg [31:0] offset=0;
 header_compare #(.RANGE(0),.ALLOW(0)) a(clk,rst,v,b,offset);
 header_compare #(.RANGE(0),.ALLOW(1)) d(clk,rst,v,b,offset);
 header_compare #(.RANGE(1),.ALLOW(1)) c(clk,rst,v,b,offset);
 reg [7:0] bytes[0:63];
 integer i,j,seed=325751;
 reg [31:0] width,height,flen,pix,dib,compress;reg [15:0] bits,planes;
 task word32(input integer loc,input [31:0] value);begin
 bytes[loc]=value[7:0];bytes[loc+1]=value[15:8];bytes[loc+2]=value[23:16];bytes[loc+3]=value[31:24];end endtask
 initial begin
 repeat(3)@(negedge clk);rst=0;
 for(j=0;j<4000;j=j+1)begin
  for(i=0;i<64;i=i+1)bytes[i]=0;
  width=320;height=240;pix=54;dib=40;bits=j[0]?32:24;planes=1;compress=0;
  case(j%12)
   1:width=0;2:height=$random(seed);3:width=1920;
   4:begin width=1080;height=1920;end
   5:pix=$random(seed);6:dib=$random(seed);
   7:bits=$random(seed);8:planes=$random(seed);
   9:compress=$random(seed);10:begin width=16'hffff;height=16'hffff;end
   default:;
  endcase
  flen=pix+((width*(bits==32?4:3)+3)&32'hfffffffc)*height;
  if(j%3==1)flen=flen-1;else if(j%3==2)flen=$random(seed);
  bytes[0]="B";bytes[1]="M";if(j%31==0)bytes[0]=0;
  word32(2,flen);word32(10,pix);word32(14,dib);word32(18,width);word32(22,height);
  bytes[26]=planes[7:0];bytes[27]=planes[15:8];bytes[28]=bits[7:0];bytes[29]=bits[15:8];word32(30,compress);
  for(i=0;i<64;i=i+1)begin
   @(negedge clk);v=1;b=bytes[i];offset=i;
   if(j%7==0)begin @(negedge clk);v=0;end
  end
  @(negedge clk);v=0;
 end
 $display("PASS header equivalence: 4000 headers x 3 configurations, valid/truncated/overflow/boundaries/continuous bytes");$finish;
 end
endmodule
