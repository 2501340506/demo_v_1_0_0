`timescale 1ns/1ps
module tb_m6_text;
 reg clk=0,wr_clk=0;always #5 clk=~clk;always #7 wr_clk=~wr_clk;
 reg rst=1,hs=1,vs=1,de=0,wen=0,kind=0,fv=0,tv=0,en=0,warn=0,gen=0;
 reg [1:0] stage=0;reg [7:0] tnow=0;reg slow=0;reg [9:0] x=0;reg [11:0] wa=0;reg [7:0] wd=0;
 reg [7:0] fm[0:4095],tm[0:4095];integer fbytes,tbytes,checks=0,switch_card=0;bit switched=0;
 wire [10:0] fa,ta;wire [15:0] fd,td;wire ho,vo,deo,available,active;
 wire [9:0] xo;wire [23:0] rgb;
 wire [8:0] y;wire fs,first;
 reg [7:0] escape_code=0,escape_char=0;reg [3:0] escape_row=0;
 wire [4:0] escape_pixels;
 // Independent 5x7 rows of the sixteen TEXT escapes, captured from osd_font_5x7.
 reg [4:0] escape_rows[0:15][0:7];
 osd_font_5x7 escape_reference(.character(escape_char),.row(escape_row[3:1]),.pixels(escape_pixels));
 osd_pixel_position pos(.clk(clk),.rst(rst),.vs(vs),.de(de),.line_y(y),.frame_start(fs),.first_active(first));
 wire legacy=!en && de && y>=200 && y<216 && x>=8 && x<216;
 wire [7:0] lc=8'h80+((x-8)>>4);
 scene_bram32k fr(.wr_clk(wr_clk),.wr_en(wen && !kind),.wr_addr(wa),.wr_data(wd),.rd_clk(clk),.rd_addr(fa),.rd_data(fd));
 scene_bram32k tr(.wr_clk(wr_clk),.wr_en(wen && kind),.wr_addr(wa),.wr_data(wd),.rd_clk(clk),.rd_addr(ta),.rd_data(td));
 scene_text_overlay dut(.clk(clk),.rst(rst),.hs(hs),.vs(vs),.de(de),.pixel_x(x),.rgb_in(24'h123456),
  .font_valid(fv),.text_valid(tv),.font_count(8'(fbytes/32)),.text_bytes(13'(tbytes)),.resource_generation(gen),.scene_enable(en),.warn_mode(warn),.stage(stage),.t_now(tnow),
  .legacy_region(legacy),.legacy_char(lc),.legacy_row(4'(y-200)),.legacy_col(4'(x-8)),
  .font_available(available),.scene_text_active(active),.text_addr(ta),.text_data(td),.font_addr(fa),.font_data(fd),
  .hs_out(ho),.vs_out(vo),.de_out(deo),.x_out(xo),.rgb_out(rgb));
 task load(input bit text_kind,input integer count);
  begin kind=text_kind;for(integer i=0;i<count;i++)begin @(negedge wr_clk);wen=1;wa=i;wd=text_kind?tm[i]:fm[i];end
   @(negedge wr_clk);wen=0;end
 endtask
 reg [36:0] expected[0:2];integer step=0,blink=0;
 function automatic [23:0] alert_color(input bit w,input [1:0] s);
  begin
   alert_color=w?24'hff2020:s==0?24'h2080ff:s==1?24'hffd000:s==2?24'hff8000:24'hff2020;
  end
 endfunction
 function automatic [23:0] swatch_color(input integer c);
  begin
   case(c)0:swatch_color=24'hd82020;1:swatch_color=24'h20c848;2:swatch_color=24'h00ff00;3:swatch_color=24'h8c6a3c;
    4:swatch_color=24'hffd000;5:swatch_color=24'he83020;6:swatch_color=24'h8e8a84;default:swatch_color=24'hc8d2dc;endcase
  end
 endfunction
 function automatic [23:0] dimmed(input [23:0] c);
  begin dimmed={1'b0,c[23:17],1'b0,c[15:9],1'b0,c[7:1]}; end
 endfunction
 // Scene OSD as drawn by the reference project (tools/scenes/*/out/osd, scene_osd.v), modelled
 // from the layout, not from the RTL: white 16 px text on half-dimmed bands; top-right panel
 // with the alert block, the title (the village name while warning) and the progress bar;
 // bottom-left legend (14-segment TEXT.BIN only); bottom subtitle scrolling 2 px per frame
 // (the warning text there while warning); blinking alert block and red frame while warning.
 function automatic [23:0] reference(input integer px,py);
  integer segment,tx,row,offset,code,at,lseg,lbytes,sseg;bit hit,swatch,dim;
  begin
   reference=24'h123456;segment=-1;tx=0;row=0;hit=0;swatch=0;dim=0;code=0;
   sseg=warn?8:stage*2+1;
   lseg=10+stage;lbytes=(tm[3]==14)?tm[6+lseg*4]:0;
   if(en && py>=32 && py<48 && px>=376)begin segment=warn?9:stage*2;row=py-32;tx=px-376;end
   if(en && lbytes!=0 && py>=416 && py<432)begin segment=lseg;row=py-416;tx=px-8;end
   if(en && py>=444 && py<460)begin segment=sseg;row=py-444;tx=px+step-632;if(px+step<632)tx=-1;end
   if(segment>=0 && px>=8 && px<632 && tx>=0 && tx<tm[6+segment*4]*16)begin
    offset=tm[4+segment*4]+256*tm[5+segment*4];code=tm[offset+tx/16];
    if(code<128)begin at=code*32+row*2+(tx%16)/8;hit=(fm[at]>>(7-tx%8))&1;end
    // Escapes F0-FF: 5x7 glyph doubled in the left 10x14 of the cell.
    else if(code>=240 && tx%16<10 && row<14)hit=escape_rows[code-240][row/2][4-(tx%16)/2];
    // E0-E7: a 12x12 colour swatch in the cell; the refuge swatch (E2) blinks slowly.
    else if(code>=224 && code<232 && tx%16>=2 && tx%16<14 && row>=2 && row<14 && (code!=226 || slow))swatch=1;
   end
   if(legacy)begin at=((px-8)/16)*32+(py-200)*2+((px-8)%16)/8;hit=(fm[at]>>(7-(px-8)%8))&1;end
   // Half-dimmed panel and bands.
   if(en && de)begin
    if(px>=348 && px<636 && py>=28 && py<60)dim=1;
    if(lbytes!=0 && px>=4 && px<12+16*lbytes && py>=412 && py<436)dim=1;
    if(tm[6+sseg*4]!=0 && px>=8 && px<632 && py>=440 && py<464)dim=1;
   end
   if(dim)reference=dimmed(reference);
   // Alert block (blinks while warning) and progress bar: one pixel per t.
   if(en && de && px>=352 && px<368 && py>=32 && py<48 && (!warn || blink))reference=alert_color(warn,stage);
   else if(en && de && px>=376 && px<616 && py>=52 && py<56)reference=(px-376<=tnow)?alert_color(warn,stage):24'h404040;
   if(swatch)reference=swatch_color(code-224);
   if(hit)reference=24'hffffff;
   if(en && warn && blink && de && (px<8 || px>=632 || py<8 || py>=472))reference=24'hff2020;
  end
 endfunction
 always @(posedge clk)begin
  if(rst)begin expected[0]=0;expected[1]=0;expected[2]=0;end
  else begin
   expected[2]=expected[1];expected[1]=expected[0];
   expected[0]={hs,vs,de,x,reference(x,y)};
   #1;if({ho,vo,deo,xo,rgb}!==expected[2])$fatal(1,"M6 pixel got %h expected %h x=%0d y=%0d",{ho,vo,deo,xo,rgb},expected[2],x,y);
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
    escape_rows[ec][er]=escape_pixels;
   end
  end
  release dut.code;release dut.row1;
  $readmemh("font.hex",fm);$readmemh("text.hex",tm);
  if(!$value$plusargs("F_BYTES=%d",fbytes) || !$value$plusargs("T_BYTES=%d",tbytes))$fatal(1,"sizes");
  #2000;load(0,fbytes);load(1,tbytes);rst=0;fv=1;tv=1;
  repeat(9000)@(negedge clk);if(!available || dut.parser!=4)$fatal(1,"valid parser %d bad=%d",dut.parser,dut.bad);
  force dut.frames=0;en=1;
  for(integer s=0;s<4;s++)begin stage=s;tnow=s==0?8'd0:s==1?8'd1:s==2?8'd100:8'd239;frame(0);frame(2);force dut.scroll=400;frame(400);release dut.scroll;end
  // Slow blink on (frames[5]=1, frames[4]=0): the refuge swatch of a legend shows.
  force dut.frames=32;force dut.scroll=0;slow=1;tnow=8'd239;frame(0);slow=0;release dut.scroll;force dut.frames=0;
  warn=1;tnow=8'd239;frame(0);force dut.scroll=300;frame(300);release dut.scroll;
  blink=1;force dut.frames=16;force dut.scroll=500;frame(500);release dut.scroll;
  force dut.frames=0;
  // Card switch as on the board: the first card is showing stage 1 and has been parsed; the
  // SW3 menu picks another scene, which also starts at stage 1, so the stage does not change.
  // Its FONT/TEXT arrive while valid stays high (the load is shorter than a frame, so the
  // pixel side never sees valid drop); only resource_generation toggles. From the first frame
  // after the load every pixel, the legend line included, must come from the new card.
  warn=0;blink=0;force dut.frames=0;
  if($value$plusargs("SWITCH=%d",switch_card) && switch_card)begin
   en=1;stage=0;warn=0;tnow=8'd239;force dut.frames=32;slow=1;
   force dut.scroll=624;frame(624);release dut.scroll;           // first card, stage 1
   if(dut.parser!=4)$fatal(1,"first card not parsed before the switch");
   $readmemh("font2.hex",fm);$readmemh("text2.hex",tm);
   if(!$value$plusargs("F2_BYTES=%d",fbytes) || !$value$plusargs("T2_BYTES=%d",tbytes))$fatal(1,"sizes2");
   load(0,fbytes);load(1,tbytes);gen=!gen;
   repeat(9000)@(negedge clk);
   force dut.scroll=624;frame(624);release dut.scroll;           // second card, still stage 1
   for(integer s=1;s<4;s++)begin stage=s;force dut.scroll=624;frame(624);release dut.scroll;end
   slow=0;force dut.frames=0;switched=1;
  end
  en=0;warn=0;blink=0;frame(0);
  invalid_file(0,0);invalid_file(2,2);invalid_file(3,9);invalid_file(6,8'd255);
  invalid_file(4,0);invalid_file(5,16);invalid_file(7,3);invalid_file(tbytes-2,8'h80);
  // Codes E0-E7 are legend swatches and may appear in any segment; E8-EF are not valid.
  invalid_file(tbytes-2,8'he8);invalid_file(3,11);
  load(1,tbytes);tv=1;repeat(9000)@(negedge clk);if(dut.parser!=4)$fatal(1,"reload failed");
  fv=0;repeat(5)@(negedge clk);if(available || active)$fatal(1,"absent font fallback");
  if(switched)$display("PASS card switch: second card's FONT/TEXT re-parsed without a valid drop, all four stages checked");
  $display("PASS M6 text: %0d pixel/bundle comparisons, four stage titles, village, scrolling, warning, 13 legacy glyphs, malformed/reload/missing resources; actual EG4 BRAM32k",checks);$finish;
 end
 initial begin #150000000;$fatal(1,"text watchdog");end
endmodule
