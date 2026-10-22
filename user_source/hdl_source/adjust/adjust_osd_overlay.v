module adjust_osd_overlay #(parameter ENABLE=1,SCENE_ENABLE=0)(
 input clk,rst,vs,de,input [9:0] pixel_x,input [23:0] rgb_in,
 input [1:0] mode,selected,input [7:0] brightness,contrast,input [3:0] volume_level,
 input scene_enable,input [1:0] scene_speed,
 output [23:0] rgb_out,output active,
 output [11:0] bright_bcd,contrast_bcd,volume_bcd // v0.27: shared with the panel
);
 wire [8:0] y;wire frame_start;
 osd_pixel_position position(.clk(clk),.rst(rst),.vs(vs),.de(de),.line_y(y),.frame_start(frame_start),.first_active());
 wire [9:0] dx=pixel_x-10'd8;wire [8:0] dy=y-9'd32;
 wire speed_visible=SCENE_ENABLE && scene_enable && mode==0;
 wire visible=ENABLE && (mode==1 || mode==2 || speed_visible);
 wire region=visible && de && pixel_x>=8 && pixel_x<296 && y>=32 && y<48;
 wire band=visible && de && pixel_x>=4 && pixel_x<300 && y>=28 && y<52;
 // Shared eight-step binary-to-BCD converter runs in vertical blanking.
 // Values are frame-stable; all three fields finish long before text line 32.
 reg [11:0] b_bcd,c_bcd,v_bcd;
 reg [19:0] shift;
 reg [1:0] phase;
 reg [2:0] bit_count;
 reg [19:0] corrected;
 always @*begin
  corrected=shift;
  if(shift[11:8]>=5)corrected[11:8]=shift[11:8]+4'd3;
  if(shift[15:12]>=5)corrected[15:12]=shift[15:12]+4'd3;
  if(shift[19:16]>=5)corrected[19:16]=shift[19:16]+4'd3;
 end
 wire [19:0] shifted=corrected<<1;
 wire [7:0] volume={4'd0,volume_level}*8'd10;
 always @(posedge clk or posedge rst)begin
  if(rst)begin b_bcd<=12'h128;c_bcd<=12'h128;v_bcd<=12'h100;shift<=0;phase<=3;bit_count<=0;end
  else if(frame_start)begin shift<={12'd0,brightness};phase<=0;bit_count<=0;end
  else if(phase!=3)begin
   if(bit_count==7)begin
    bit_count<=0;phase<=phase+1'b1;
    case(phase)
     0:begin b_bcd<=shifted[19:8];shift<={12'd0,contrast};end
     1:begin c_bcd<=shifted[19:8];shift<={12'd0,volume};end
     2:begin v_bcd<=shifted[19:8];shift<=0;end
    endcase
   end else begin shift<=shifted;bit_count<=bit_count+1'b1;end
  end
 end
 assign bright_bcd=b_bcd;assign contrast_bcd=c_bcd;assign volume_bcd=v_bcd;
 wire [23:0] b_digits={4'h3,b_bcd[11:8],4'h3,b_bcd[7:4],4'h3,b_bcd[3:0]};
 wire [23:0] c_digits={4'h3,c_bcd[11:8],4'h3,c_bcd[7:4],4'h3,c_bcd[3:0]};
 wire [23:0] v_digits={4'h3,v_bcd[11:8],4'h3,v_bcd[7:4],4'h3,v_bcd[3:0]};
 reg [7:0] character;reg [1:0] item;
 always @*begin
  character=" ";item=3;
  case(dx[8:4])
   0:begin character="B";item=0;end
   1:begin character=":";item=0;end
   2:begin character=b_digits[23:16];item=0;end
   3:begin character=b_digits[15:8];item=0;end
   4:begin character=b_digits[7:0];item=0;end
   6:begin character="C";item=1;end
   7:begin character=":";item=1;end
   8:begin character=c_digits[23:16];item=1;end
   9:begin character=c_digits[15:8];item=1;end
   10:begin character=c_digits[7:0];item=1;end
   12:begin character="V";item=2;end
   13:begin character=":";item=2;end
   14:begin character=v_digits[23:16];item=2;end
   15:begin character=v_digits[15:8];item=2;end
   16:begin character=v_digits[7:0];item=2;end
   17:begin character="%";item=2;end
  endcase
  if(speed_visible)begin
   item=selected;
   case(dx[8:4])
    0:character="S";1:character="P";2:character="E";3:character="E";4:character="D";
    5:character=":";7:character=scene_speed==0?"1":scene_speed==1?"2":"4";
    8:character="X";default:character=" ";
   endcase
  end
 end
 wire [4:0] glyph;
 osd_font_5x7 font(.character(character),.row(dy[3:1]),.pixels(glyph));
 assign active=region && dx[3:1]<5 && dy[3:1]<7 && glyph[3'd4-dx[3:1]];
 assign rgb_out=active?(item==selected?24'hffff00:24'hffffff):
  band?{1'b0,rgb_in[23:17],1'b0,rgb_in[15:9],1'b0,rgb_in[7:1]}:rgb_in;
endmodule

// v0.27 adjust panel (SW4): 336x200 at x=296,y=120, slides in from the right
// over eight frames. Two columns: categories, then the items of the current
// category with value text and bars. Rendered through two registers, so the
// panel lands 2 px right of its nominal place; video latency is unchanged.
module adjust_panel_overlay #(parameter ENABLE=1)(
 input clk,rst,vs,de,input [9:0] pixel_x,input [23:0] rgb_in,
 input panel,focus,input [3:0] item,
 input [7:0] brightness,contrast,input [3:0] volume_level,
 input wave_on,input [1:0] wave_height,wash_level,input osd_on,scroll_on,fade_on,
 input [11:0] bright_bcd,contrast_bcd,volume_bcd,
 output [23:0] rgb_out
);
 localparam [9:0] X0=10'd296;
 localparam [8:0] Y0=9'd120;
 localparam [23:0] C_BG=24'h102030,C_BLUE=24'h3c82f0,C_DIM=24'h1c3c6c,
                   C_TRACK=24'h2a3c54,C_WHITE=24'hffffff,C_GRAY=24'h8ca0b8;
 wire [8:0] y;wire frame_start;
 osd_pixel_position position(.clk(clk),.rst(rst),.vs(vs),.de(de),.line_y(y),.frame_start(frame_start),.first_active());
 reg [8:0] off;reg [9:0] x0;
 always @(posedge clk or posedge rst)
  if(rst)begin off<=9'd336;x0<=10'd632;end
  else if(frame_start)begin
   if(ENABLE && panel)off<=off>=42?off-9'd42:9'd0;
   else off<=off>=294?9'd336:off+9'd42;
   x0<=X0+off;
  end
 wire shown=ENABLE && off!=9'd336;
 // Category layout of the item list.
 reg [2:0] cat;reg [3:0] first;reg [1:0] count;
 always @*begin
  case(item)0,1:cat=0;2:cat=1;3,4,5:cat=2;6,7,8:cat=3;default:cat=4;endcase
  case(cat)0:begin first=0;count=2;end 1:begin first=2;count=1;end
   2:begin first=3;count=3;end 3:begin first=6;count=3;end default:begin first=9;count=1;end
  endcase
 end
 function [7:0] digit(input [3:0] d);digit={4'h3,d};endfunction
 function [31:0] onoff(input on);onoff=on?"  ON":" OFF";endfunction
 function [7:0] level_fill(input [1:0] v);
  case(v)0:level_fill=0;1:level_fill=58;2:level_fill=117;default:level_fill=176;endcase
 endfunction
 // Vertical decode once per line (y only changes in horizontal blanking).
 wire [8:0] ly=y-Y0;
 reg n_in,n_frame,n_title_band,n_title,n_hint,n_cat_text,n_cat_hl,n_item_text,n_item_hl,n_bar,n_body;
 reg [2:0] n_cat,n_grow;reg [1:0] n_row;reg [8:0] t,s;
 integer i;
 always @*begin
  n_in=y>=Y0 && y<Y0+9'd200;n_frame=ly<2 || ly>=198;n_title_band=ly<22;n_body=ly<9'd176;
  n_title=0;n_hint=0;n_cat_text=0;n_cat_hl=0;n_item_text=0;n_item_hl=0;n_bar=0;
  n_cat=0;n_row=0;n_grow=0;t=0;s=0;
  if(ly>=4 && ly<18)begin n_title=1;t=ly-9'd4;n_grow=t[3:1];end
  if(ly>=180 && ly<194)begin n_hint=1;t=ly-9'd180;n_grow=t[3:1];end
  for(i=0;i<5;i=i+1)begin
   s=9'd32+9'd24*i;
   if(ly+9'd4>=s && ly<s+9'd18)begin n_cat_hl=1;n_cat=i;end
   if(ly>=s && ly<s+9'd14)begin n_cat_text=1;t=ly-s;n_grow=t[3:1];end
  end
  for(i=0;i<3;i=i+1)begin
   s=9'd32+9'd48*i;
   if(ly+9'd4>=s && ly<s+9'd44)n_row=i;
   if(ly+9'd4>=s && ly<s+9'd18)n_item_hl=1;
   if(ly>=s && ly<s+9'd14)n_item_text=1;
   if(ly>=s+9'd20 && ly<s+9'd28)n_bar=1;
  end
 end
 wire [3:0] n_item=first+n_row;
 reg [31:0] n_value;reg [7:0] n_fill;reg n_has_bar;
 always @*begin
  n_has_bar=0;n_fill=0;n_value="  1S";
  case(n_item)
   0:begin n_value={" ",digit(bright_bcd[11:8]),digit(bright_bcd[7:4]),digit(bright_bcd[3:0])};
      n_has_bar=1;n_fill=({4'd0,brightness}*12'd11)>>4;end
   1:begin n_value={" ",digit(contrast_bcd[11:8]),digit(contrast_bcd[7:4]),digit(contrast_bcd[3:0])};
      n_has_bar=1;n_fill=({4'd0,contrast}*12'd11)>>4;end
   2:begin n_value={digit(volume_bcd[11:8]),digit(volume_bcd[7:4]),digit(volume_bcd[3:0]),"%"};
      n_has_bar=1;n_fill={4'd0,volume_level}*8'd17;end
   3:n_value=onoff(wave_on);
   4:begin n_value={"   ",digit({2'd0,wave_height})};n_has_bar=1;n_fill=level_fill(wave_height);end
   5:begin n_value={"   ",digit({2'd0,wash_level})};n_has_bar=1;n_fill=level_fill(wash_level);end
   6:n_value=onoff(osd_on);
   7:n_value=onoff(scroll_on);
   8:n_value=onoff(fade_on);
  endcase
 end
 reg v_body,v_in,v_frame,v_title_band,v_title,v_hint,v_cat_text,v_cat_hl,v_item_text,v_item_hl,v_bar,v_valid,v_has_bar,v_cur_cat,v_cur_item;
 reg [2:0] v_cat,v_grow;reg [3:0] v_item;reg [31:0] v_value;reg [7:0] v_fill;
 always @(posedge clk or posedge rst)
  if(rst)begin
   v_body<=0;v_in<=0;v_frame<=0;v_title_band<=0;v_title<=0;v_hint<=0;v_cat_text<=0;v_cat_hl<=0;
   v_item_text<=0;v_item_hl<=0;v_bar<=0;v_valid<=0;v_has_bar<=0;v_cur_cat<=0;v_cur_item<=0;
   v_cat<=0;v_grow<=0;v_item<=0;v_value<=0;v_fill<=0;
  end else begin
   v_body<=n_body;v_in<=n_in;v_frame<=n_frame;v_title_band<=n_title_band;v_title<=n_title;v_hint<=n_hint;
   v_cat_text<=n_cat_text;v_cat_hl<=n_cat_hl;v_item_text<=n_item_text;v_item_hl<=n_item_hl;v_bar<=n_bar;
   v_valid<=n_row<count;v_has_bar<=n_has_bar;v_cur_cat<=n_cat==cat;v_cur_item<=n_item==item;
   v_cat<=n_cat;v_grow<=n_grow;v_item<=n_item;v_value<=n_value;v_fill<=n_fill;
  end
 // Text: 19-character rows starting at cell 1, or 12 at cell 9 for items.
 function [7:0] pick(input [151:0] str,input [4:0] p);pick=str[151-8*p -: 8];endfunction
 reg [151:0] cat_str,item_str;
 always @*begin
  case(v_cat)
   0:cat_str="PICTURE            ";1:cat_str="AUDIO              ";2:cat_str="WAVE               ";
   3:cat_str="FEATURE            ";default:cat_str="RESET              ";
  endcase
  case(v_item)
   0:item_str={"BRIGHT  ",v_value,"       "};1:item_str={"CONTRAST",v_value,"       "};
   2:item_str={"VOLUME  ",v_value,"       "};3:item_str={"WAVE    ",v_value,"       "};
   4:item_str={"HEIGHT  ",v_value,"       "};5:item_str={"WASH    ",v_value,"       "};
   6:item_str={"OSD     ",v_value,"       "};7:item_str={"SCROLL  ",v_value,"       "};
   8:item_str={"FADE    ",v_value,"       "};default:item_str={"HOLD K4 ",v_value,"       "};
  endcase
 end
 wire [9:0] lx=pixel_x-x0;
 wire in_x=pixel_x>=x0 && lx<10'd336;
 wire [4:0] cx=lx[8:4];
 reg [7:0] ch;reg [1:0] ink,paper;
 always @*begin
  ch=" ";ink=1;
  if(v_title && cx>=1 && cx<20)ch=pick("ADJUST PANEL    SW4",cx-5'd1);
  else if(v_hint && cx>=1 && cx<20)begin
   ink=2;ch=pick(focus?"K1 K2 SET   K4 BACK":"K1/K2 MOVE  K4 EDIT",cx-5'd1);
  end else if(v_cat_text && cx>=1 && cx<8)ch=pick(cat_str,cx-5'd1);
  else if(v_item_text && v_valid && cx>=9)ch=pick(item_str,cx-5'd9);
  // paper 0 bg, 1 blue, 2 dim, 3 bar track
  paper=0;
  if(v_frame || lx<2 || lx>=334 || v_title_band || (v_body && lx>=128 && lx<130))paper=1;
  else if(v_cat_hl && v_cur_cat && lx>=8 && lx<124)paper=focus?2'd2:2'd1;
  else if(v_item_hl && v_valid && v_cur_item && lx>=134 && lx<330)paper=focus?2'd1:2'd2;
  else if(v_bar && v_valid && v_has_bar && lx>=144 && lx<320)paper=(lx-10'd144)<{2'd0,v_fill}?2'd1:2'd3;
 end
 reg hit1;reg [7:0] ch1;reg [2:0] grow1,gx1;reg [1:0] ink1,paper1;
 reg hit2;reg [23:0] color2;
 wire [4:0] glyph;
 osd_font_5x7 font(.character(ch1),.row(grow1),.pixels(glyph));
 wire glyph_on=gx1<5 && glyph[3'd4-gx1];
 always @(posedge clk or posedge rst)
  if(rst)begin hit1<=0;ch1<=" ";grow1<=0;gx1<=0;ink1<=0;paper1<=0;hit2<=0;color2<=0;end
  else begin
   hit1<=shown && de && v_in && in_x;ch1<=ch;grow1<=v_grow;gx1<=lx[3:1];ink1<=ink;paper1<=paper;
   hit2<=hit1;
   color2<=glyph_on?(ink1==2?C_GRAY:C_WHITE):
    paper1==1?C_BLUE:paper1==2?C_DIM:paper1==3?C_TRACK:C_BG;
  end
 assign rgb_out=hit2?color2:rgb_in;
endmodule
