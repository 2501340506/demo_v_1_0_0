`timescale 1ns/1ps
module tb_m5_text;
 reg clk=0,wr_clk=0;always #5 clk=~clk;always #7 wr_clk=~wr_clk;
 reg rst=1,hs=1,vs=1,de=0,wen=0,kind=0,fv=0,tv=0,en=0,warn=0;
 reg [1:0] stage=0;reg [9:0] x=0;reg [11:0] wa=0;reg [7:0] wd=0;
 reg [7:0] fm[0:4095],tm[0:4095];integer fbytes,tbytes,checks=0;
 wire [10:0] fa,ta;wire [15:0] fd,td;wire ho,vo,deo,available,active;
 wire [9:0] xo;wire [23:0] rgb;
 wire [8:0] y;wire fs,first;
 reg [7:0] escape_code=0,escape_char=0;reg [3:0] escape_row=0;
 wire [4:0] escape_pixels;
 osd_font_5x7 escape_reference(.character(escape_char),.row(escape_row[3:1]),.pixels(escape_pixels));
 osd_pixel_position pos(.clk(clk),.rst(rst),.vs(vs),.de(de),.line_y(y),.frame_start(fs),.first_active(first));
 wire legacy=de && y>=200 && y<216 && x>=8 && x<216;
 wire [7:0] lc=8'h80+((x-8)>>4);
 scene_bram32k fr(.wr_clk(wr_clk),.wr_en(wen && !kind),.wr_addr(wa),.wr_data(wd),.rd_clk(clk),.rd_addr(fa),.rd_data(fd));
 scene_bram32k tr(.wr_clk(wr_clk),.wr_en(wen && kind),.wr_addr(wa),.wr_data(wd),.rd_clk(clk),.rd_addr(ta),.rd_data(td));
 scene_text_overlay dut(.clk(clk),.rst(rst),.hs(hs),.vs(vs),.de(de),.pixel_x(x),.rgb_in(24'h123456),
  .font_valid(fv),.text_valid(tv),.font_count(8'(fbytes/32)),.text_bytes(13'(tbytes)),.resource_generation(1'b0),.scene_enable(en),.warn_mode(warn),.stage(stage),
  .legacy_region(legacy),.legacy_char(lc),.legacy_row(4'(y-200)),.legacy_col(4'(x-8)),
  .font_available(available),.scene_text_active(active),.text_addr(ta),.text_data(td),.font_addr(fa),.font_data(fd),
  .hs_out(ho),.vs_out(vo),.de_out(deo),.x_out(xo),.rgb_out(rgb));
 task load(input bit text_kind,input integer count);
  begin kind=text_kind;for(integer i=0;i<count;i++)begin @(negedge wr_clk);wen=1;wa=i;wd=text_kind?tm[i]:fm[i];end
   @(negedge wr_clk);wen=0;end
 endtask
 reg [36:0] expected[0:2];integer step=0,blink=0;
 function automatic [23:0] reference(input integer px,py);
  integer segment,tx,row,offset,code,at;bit hit;
  begin
   reference=24'h123456;segment=-1;tx=px-8;row=py%16;hit=0;
   if(en && py>=64 && py<80)begin segment=stage*2;row=py-64;end
   if(en && py>=88 && py<104)begin segment=9;row=py-88;end
   if(en && py>=444 && py<460)begin segment=warn?8:stage*2+1;row=py-444;if(!warn)tx=px+step-632;end
   if(segment>=0 && px>=8 && px<632 && tx>=0 && tx<tm[6+segment*4]*16)begin
    offset=tm[4+segment*4]+256*tm[5+segment*4];code=tm[offset+tx/16];
    if(code<128)begin at=code*32+row*2+(tx%16)/8;hit=(fm[at]>>(7-tx%8))&1;end
    // Demo's only ASCII is '!': explicit independent 5x7 rows below.
    else if(code==255 && tx%16<10 && row<14)hit=(tx%16)/2==2 && (row/2<4 || row/2==5);
   end
   if(legacy)begin at=((px-8)/16)*32+(py-200)*2+((px-8)%16)/8;hit=(fm[at]>>(7-(px-8)%8))&1;end
   if(hit)reference=24'hffffff;
   if(en && warn && blink && de && (px<8 || px>=632 || py<8 || py>=472))reference=24'hff0000;
  end
 endfunction
 always @(posedge clk)begin
  if(rst)begin expected[0]=0;expected[1]=0;expected[2]=0;end
  else begin
   expected[2]=expected[1];expected[1]=expected[0];
   expected[0]={hs,vs,de,x,reference(x,y)};
   #1;if({ho,vo,deo,xo,rgb}!==expected[2])$fatal(1,"M5 pixel got %h expected %h x=%0d y=%0d",{ho,vo,deo,xo,rgb},expected[2],x,y);
   checks++;
  end
 end
 task frame(input integer scroll_step);
  begin
   step=scroll_step;@(negedge clk);vs=0;de=0;repeat(12)@(negedge clk);vs=1;
   for(integer yy=0;yy<480;yy++)begin
    for(integer xx=0;xx<650;xx++)begin @(negedge clk);de=xx<640;x=xx;end
    @(negedge clk);de=0;
   end
   repeat(12)@(negedge clk);
  end
 endtask
 task invalid_file(input integer at,input reg [7:0] value);
  reg [7:0] saved;
  begin
   saved=tm[at];tv=0;repeat(5)@(negedge clk);tm[at]=value;load(1,tbytes);tv=1;
   repeat(9000)@(negedge clk);if(dut.parser==4)$fatal(1,"invalid text accepted at %d",at);
   tv=0;repeat(5)@(negedge clk);tm[at]=saved;
  end
 endtask
 initial begin
  // Every TEXT escape must preserve the shared font, including blank row 7.
  force dut.code=escape_code;force dut.row1=escape_row;
  for(integer ec=0;ec<16;ec++)begin
   escape_code=8'hf0+ec;
   case(ec)
    10:escape_char=" ";11:escape_char=":";12:escape_char=".";
    13:escape_char="-";14:escape_char="/";15:escape_char="!";
    default:escape_char="0"+ec;
   endcase
   for(integer er=0;er<8;er++)begin
    escape_row=er*2;#1;
    if(dut.ascii_pixels!==escape_pixels)$fatal(1,"escape font mismatch code=%h row=%d",escape_code,er);
   end
  end
  release dut.code;release dut.row1;
  $readmemh("font.hex",fm);$readmemh("text.hex",tm);
  if(!$value$plusargs("F_BYTES=%d",fbytes) || !$value$plusargs("T_BYTES=%d",tbytes))$fatal(1,"sizes");
  #2000;load(0,fbytes);load(1,tbytes);rst=0;fv=1;tv=1;
  repeat(9000)@(negedge clk);if(!available || dut.parser!=4)$fatal(1,"valid parser %d bad=%d",dut.parser,dut.bad);
  en=1;
  for(integer s=0;s<4;s++)begin stage=s;frame(0);frame(1);end
  warn=1;frame(0);
  // Advance blink with short blank frames, then verify the complete border.
  repeat(16)begin @(negedge clk);vs=0;repeat(4)@(negedge clk);vs=1;repeat(4)@(negedge clk);end
  blink=1;frame(0);
  en=0;warn=0;blink=0;frame(0);
  invalid_file(0,0);invalid_file(2,2);invalid_file(3,9);invalid_file(6,32);
  invalid_file(4,0);invalid_file(5,16);invalid_file(7,3);invalid_file(tbytes-2,8'h80);
  load(1,tbytes);tv=1;repeat(9000)@(negedge clk);if(dut.parser!=4)$fatal(1,"reload failed");
  fv=0;repeat(5)@(negedge clk);if(available || active)$fatal(1,"absent font fallback");
  $display("PASS M5 text: %0d pixel/bundle comparisons, four stage titles, village, scrolling, warning, 13 legacy glyphs, malformed/reload/missing resources; actual EG4 BRAM32k",checks);$finish;
 end
 initial begin #100000000;$fatal(1,"text watchdog");end
endmodule
