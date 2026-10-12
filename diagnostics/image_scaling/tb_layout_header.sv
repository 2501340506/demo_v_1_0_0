`timescale 1ns/1ps
module tb_layout_header;
 reg clk=0,rst=1,fv=0;always #5 clk=~clk;
 reg [7:0] b;reg [31:0] off;wire match;wire [31:0] stride,pixels;
 reg [7:0] header[0:53];
 bmp_header_check #(.RANGE_DIMENSIONS(1)) h(.clk(clk),.rst(rst),.file_valid(fv),.file_byte(b),.file_byte_offset(off),
 .bmp_width(16'd640),.bmp_height(16'd480),.file_len(),.pixel_offset(),.width(),.height(),.required_end(),
 .header_match(match),.skip_format(),.header_complete(),.is_32(),.row_stride(stride),.expected_pixels(pixels));
 reg de=1;reg [9:0] x;reg [8:0] y;reg [1:0] focus;reg [3:0] mask;reg [2:0] count;
 wire td,border;wire [1:0] si;wire [9:0] sx;wire [8:0] sy;
 thumbnail_layout layout(de,x,y,focus,count,mask,td,si,sx,sy,border);
 task put32(input integer at,v);begin for(integer k=0;k<4;k=k+1)header[at+k]=v>>(8*k);end endtask
 task check_header(input integer w,hh,bits,input bit ok);
  integer rowbytes;
  begin
   @(negedge clk);rst=1;fv=0;repeat(2)@(negedge clk);rst=0;
   rowbytes=(w*(bits/8)+3)&~3;
   for(integer k=0;k<54;k=k+1)header[k]=0;
   header[0]="B";header[1]="M";put32(2,54+rowbytes*hh);put32(10,54);put32(14,40);
   put32(18,w);put32(22,hh);header[26]=1;header[28]=bits;
   for(integer k=0;k<54;k=k+1)begin fv=1;off=k;b=header[k];@(negedge clk);end
   fv=0;repeat(8)@(negedge clk);
   if(match!==ok)$fatal(1,"range %0dx%0d bits=%0d",w,hh,bits);
   if(ok && (stride!=rowbytes || pixels!=w*hh))$fatal(1,"geometry");
  end
 endtask
 initial begin
  check_header(1920,1080,24,1);check_header(1080,1920,24,1);check_header(317,239,24,1);
  check_header(1921,1080,24,0);check_header(1081,1920,24,0);check_header(640,-480,24,0);check_header(640,480,32,0);
  count=3;mask=4'b0101;focus=1;
  for(integer yy=0;yy<480;yy=yy+1)for(integer xx=0;xx<640;xx=xx+1)begin
   integer id,lx,ly;bit eb;
   x=xx;y=yy;#1;id=(yy/240)*2+xx/320;lx=xx%320;ly=yy%240;
   eb=id==focus && id<count && (lx<2 || lx>=318 || ly<2 || ly>=238);
   if(si!=id || sx!=lx*2 || sy!=ly*2 || td!==mask[id] || border!==eb)$fatal(1,"layout %0d,%0d",xx,yy);
  end
  de=0;#1;if(td || border)$fatal(1,"blanking");
  $display("PASS range header 7 cases and layout 307200 pixels including incomplete focus");$finish;
 end
endmodule
