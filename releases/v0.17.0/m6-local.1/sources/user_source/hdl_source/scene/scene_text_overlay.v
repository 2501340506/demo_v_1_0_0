// Synchronous TEXT -> FONT -> RGB pipeline. All video fields travel together.
// Resource metadata is an acknowledged mailbox, held stable after loading.
module scene_text_overlay(
 input clk,rst,hs,vs,de,input [9:0] pixel_x,input [23:0] rgb_in,
 input font_valid,text_valid,input [7:0] font_count,input [12:0] text_bytes,
 input scene_enable,warn_mode,input [1:0] stage,
 input legacy_region,input [7:0] legacy_char,input [3:0] legacy_row,legacy_col,
 output font_available,scene_text_active,
 output [10:0] text_addr,input [15:0] text_data,
 output [10:0] font_addr,input [15:0] font_data,
 output reg hs_out,vs_out,de_out,output reg [9:0] x_out,output reg [23:0] rgb_out
);
 wire [8:0] y;wire frame_start,first_active;
 osd_pixel_position position(.clk(clk),.rst(rst),.vs(vs),.de(de),.line_y(y),
  .frame_start(frame_start),.first_active(first_active));
 // Cache only the three displayed descriptors. Re-parse on a stage/mode
 // change in blanking; this avoids a ten-way offset/length register mux.
 reg [11:0] title_offset,subtitle_offset,village_offset;
 reg [4:0] title_length,subtitle_length,village_length,descriptor_length;
 reg [1:0] parse_stage;reg parse_warning;
 localparam IDLE=0,REQ=1,BYTE=2,CHECK=3,READY=4,BAD=5;
 reg [2:0] parser;
 reg [11:0] cursor;reg bad;
 reg [7:0] low_offset,high_offset;
 wire [7:0] parse_byte=cursor[0]?text_data[15:8]:text_data[7:0];
 wire [11:0] descriptor_byte=cursor-12'd4;
 wire [3:0] descriptor=descriptor_byte[5:2];
 wire [11:0] descriptor_offset={high_offset[3:0],low_offset};
 wire [12:0] segment_end={1'b0,descriptor_offset}+{8'd0,descriptor_length};
 assign font_available=font_valid && font_count>=13 && font_count<=128;
 // A bad TEXT file does not disable a successfully loaded FONT for UART OSD.
 always @(posedge clk or posedge rst)begin
  if(rst)begin parser<=IDLE;cursor<=0;bad<=0;low_offset<=0;high_offset<=0;
   parse_stage<=0;parse_warning<=0;title_offset<=0;subtitle_offset<=0;village_offset<=0;
   title_length<=0;subtitle_length<=0;village_length<=0;descriptor_length<=0;end
  else if(!font_available || !text_valid)begin parser<=IDLE;cursor<=0;bad<=0;end
  else if(parser!=IDLE && (stage!=parse_stage || warn_mode!=parse_warning))parser<=IDLE;
  else case(parser)
   IDLE:begin cursor<=0;bad<=text_bytes<44 || text_bytes>4096;parse_stage<=stage;parse_warning<=warn_mode;parser<=REQ;end
   REQ:parser<=BYTE;
   BYTE:begin
    case(cursor)
     0:if(parse_byte!="T")bad<=1;
     1:if(parse_byte!="X")bad<=1;
     2:if(parse_byte!=1)bad<=1;
     3:if(parse_byte!=10)bad<=1;
     default:begin
      if(cursor<44)case(descriptor_byte[1:0])
       0:low_offset<=parse_byte;
       1:high_offset<=parse_byte;
       2:begin
        descriptor_length<=parse_byte[4:0];
        if(high_offset[7:4]!=0 || parse_byte>31)bad<=1;
       end
       3:begin
        if(parse_byte!=(descriptor<8?{7'd0,descriptor[0]}:descriptor==8?8'd2:8'd3) || descriptor_offset<44 || segment_end>text_bytes)bad<=1;
        if(descriptor=={1'b0,parse_stage,1'b0})begin title_offset<=descriptor_offset;title_length<=descriptor_length;end
        if(descriptor==(parse_warning?4'd8:{1'b0,parse_stage,1'b1}))begin subtitle_offset<=descriptor_offset;subtitle_length<=descriptor_length;end
        if(descriptor==9)begin village_offset<=descriptor_offset;village_length<=descriptor_length;end
       end
      endcase
      else if(parse_byte<128 ? {1'b0,parse_byte}>= {1'b0,font_count} : parse_byte<240)bad<=1;
     end
    endcase
    if({1'b0,cursor}+13'd1>=text_bytes)parser<=CHECK;
    else begin cursor<=cursor+1'b1;parser<=REQ;end
   end
   CHECK:parser<=bad?BAD:READY;
   default:;
  endcase
 end
 reg enabled_q,warn_q;reg [1:0] stage_q;reg [5:0] frames;
 wire enabled=first_active?scene_enable:enabled_q;
 wire warning=first_active?warn_mode:warn_q;
 reg [10:0] scroll;
 wire changed=scene_enable!=enabled_q || warn_mode!=warn_q || stage!=stage_q;
 wire [10:0] scroll_end=11'd624+{1'd0,subtitle_length,5'd0};
 always @(posedge clk or posedge rst)begin
  if(rst)begin enabled_q<=0;warn_q<=0;stage_q<=0;scroll<=0;frames<=0;end
  else begin
   if(first_active)begin
    enabled_q<=scene_enable;warn_q<=warn_mode;stage_q<=stage;
    if(changed)scroll<=0;
   end
   if(frame_start)begin
    frames<=frames+1'b1;
    if(scroll>=scroll_end)scroll<=0;else scroll<=scroll+1'b1;
   end
  end
 end
 assign scene_text_active=enabled && parser==READY;
 reg [11:0] segment_offset;reg [4:0] segment_length;
 reg [10:0] local_x;reg [3:0] row;reg region;
 wire signed [12:0] subtitle_x=$signed({2'b0,scroll})+$signed({3'b0,pixel_x})-13'sd632;
 // Power-of-two nearest-neighbour scaling keeps the glyph address path small.
 // Long card warnings reduce scale so the complete message remains visible.
 wire [1:0] warning_shift=subtitle_length>19?2'd0:
                         frames[4] && subtitle_length<=9?2'd2:2'd1;
 wire [10:0] warning_width={2'd0,subtitle_length,4'd0}<<warning_shift;
 wire [9:0] warning_left=10'd320-warning_width[10:1];
 wire [8:0] warning_height=9'd16<<warning_shift;
 wire [8:0] warning_top=9'd240-(warning_height>>1);
 always @*begin
  segment_offset=title_offset;segment_length=title_length;local_x=({1'b0,pixel_x}-11'd8)>>1;row=0;region=0;
  if(scene_text_active && de)begin
   if(warning)begin
    segment_offset=subtitle_offset;segment_length=subtitle_length;
    local_x=({1'b0,pixel_x}-{1'b0,warning_left})>>warning_shift;
    row=(y-warning_top)>>warning_shift;
    region=y>=warning_top && y<warning_top+warning_height && pixel_x>=warning_left;
   end else if(y>=64 && y<96)begin row=(y-64)>>1;region=1;end
   else if(y>=112 && y<144)begin segment_offset=village_offset;segment_length=village_length;row=(y-112)>>1;region=1;end
   else if(y>=416 && y<448)begin
    segment_offset=subtitle_offset;segment_length=subtitle_length;row=(y-416)>>1;
    local_x=subtitle_x[11:1];region=subtitle_x>=0;
   end
   region=region && pixel_x>=8 && pixel_x<632 && local_x<{2'd0,segment_length,4'd0};
  end
 end
 wire border=enabled && warning && frames[4] && de &&
   (pixel_x<8 || pixel_x>=632 || y<8 || y>=472);
 wire [11:0] render_addr=segment_offset+{5'd0,local_x[10:4]};
 assign text_addr=(parser==REQ || parser==BYTE)?cursor[11:1]:render_addr[11:1];
 reg [26:0] video1,video2;
 reg [9:0] x1,x2;
 reg text_lane1,region1,legacy1,border1,region2,cn2,ascii2,border2;
 reg scene1,scene2,red1,red2;
 reg [3:0] row1,col1,col2;
 reg [7:0] legacy1_char;
 wire [7:0] code=text_lane1?text_data[15:8]:text_data[7:0];
 // TEXT has exactly sixteen escapes. Decode their original 5x7 bitmaps
 // directly, avoiding an eight-bit ASCII decode and wide variable index.
 reg [34:0] ascii_bits;
 reg [4:0] ascii_pixels;
 always @*begin
  case(code[3:0])
   0:ascii_bits=35'h3a33ae62e;1:ascii_bits=35'h11842108e;
   2:ascii_bits=35'h3a211111f;3:ascii_bits=35'h78217043e;
   4:ascii_bits=35'h08ca97c42;5:ascii_bits=35'h7e10f043e;
   6:ascii_bits=35'h3a10f462e;7:ascii_bits=35'h7c2222108;
   8:ascii_bits=35'h3a317462e;9:ascii_bits=35'h3a317842e;
   10:ascii_bits=0;11:ascii_bits=35'h008401080;
   12:ascii_bits=35'h000000084;13:ascii_bits=35'h0000f8000;
   14:ascii_bits=35'h044222110;15:ascii_bits=35'h108420080;
  endcase
  case(row1[3:1])
   0:ascii_pixels=ascii_bits[34:30];1:ascii_pixels=ascii_bits[29:25];
   2:ascii_pixels=ascii_bits[24:20];3:ascii_pixels=ascii_bits[19:15];
   4:ascii_pixels=ascii_bits[14:10];5:ascii_pixels=ascii_bits[9:5];
   6:ascii_pixels=ascii_bits[4:0];default:ascii_pixels=0;
  endcase
 end
 wire [2:0] ascii_column=3'd4-col1[3:1];
 assign font_addr={legacy1?legacy1_char[6:0]:code[6:0],row1};
 // Original UART IDs 80..8c map to font slots 0..12.
 wire [15:0] font_row={font_data[7:0],font_data[15:8]};
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   video1<=0;video2<=0;x1<=0;x2<=0;text_lane1<=0;region1<=0;legacy1<=0;
   row1<=0;col1<=0;legacy1_char<=0;border1<=0;region2<=0;cn2<=0;ascii2<=0;border2<=0;col2<=0;
   hs_out<=0;vs_out<=0;de_out<=0;x_out<=0;rgb_out<=0;scene1<=0;scene2<=0;red1<=0;red2<=0;
  end else begin
   video1<={hs,vs,de,rgb_in};x1<=pixel_x;text_lane1<=render_addr[0];region1<=region;
   scene1<=region;red1<=warning;scene2<=scene1;red2<=red1;
   legacy1<=!region && legacy_region && font_available;
   legacy1_char<=legacy_char-8'h80;
   row1<=region?row:legacy_row;col1<=region?local_x[3:0]:legacy_col;border1<=border;
   video2<=video1;x2<=x1;col2<=col1;border2<=border1;
   region2<=region1 || legacy1;cn2<=legacy1 || code<128;
   ascii2<=region1 && code>=240 && col1[3:1]<5 && row1[3:1]<7 && ascii_pixels[ascii_column];
   {hs_out,vs_out,de_out}<=video2[26:24];x_out<=x2;
   rgb_out<=border2?24'hff0000:region2 && ((cn2 && font_row[~col2]) || ascii2)?
     (scene2?(red2?24'hff0000:24'h000000):24'hffffff):video2[23:0];
  end
 end
endmodule
