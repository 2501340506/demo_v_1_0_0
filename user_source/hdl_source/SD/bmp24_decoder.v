module bmp24_decoder #(
    parameter integer EXPECTED_WIDTH = 640,
    parameter integer EXPECTED_HEIGHT = 480,
    parameter integer RUNTIME_DIMENSIONS = 0,
    parameter integer ALLOW_32 = 1,
    parameter integer RANGE_DIMENSIONS = 0,
    parameter integer FLOW_CONTROL = 0,
    // Enable only when offset is stable at least one clock before file_valid.
    // bmp_sector_buffer's FETCH/PRESENT interface provides that lookahead.
    parameter integer HEADER_OFFSET_LOOKAHEAD = 0
) (
    input wire clk, input wire rst,
    input wire [15:0] expected_width, expected_height,
    input wire file_start, input wire [31:0] file_size,
    input wire file_valid, input wire [7:0] file_byte,
    input wire [31:0] file_byte_offset, input wire file_end,
    input wire [7:0] upstream_error,
    output reg header_accepted, output reg pixel_valid,
    output wire [23:0] pixel_rgb, output reg [15:0] pixel_x, pixel_y,
    output reg frame_commit, output reg bmp_done, output reg [2:0] bmp_error,
    input wire pixel_ready, output wire file_ready,
    output wire [15:0] image_width, image_height,
    output reg [31:0] pixel_rgba
);
 wire [15:0] tw=RUNTIME_DIMENSIONS?expected_width:EXPECTED_WIDTH;
 wire [15:0] th=RUNTIME_DIMENSIONS?expected_height:EXPECTED_HEIGHT;
 wire [31:0] declared_size,pixel_offset,width,height,row_stride,expected_pixels;
 wire [33:0] pixel_end;
 wire header_ok,header_complete,is_32;
 reg active,checked,end_pending;
 localparam ROW_BITS=RANGE_DIMENSIONS?11:32;
 localparam BYTE_BITS=RANGE_DIMENSIONS?13:32;
 localparam COUNT_BITS=RANGE_DIMENSIONS?22:32;
 reg [31:0] size_reg;
 reg [BYTE_BITS-1:0] row_byte;
 reg [ROW_BITS-1:0] row,col;
 reg [COUNT_BITS-1:0] pixel_count;
 // Valid range-mode rows are at most 1920*4 bytes. Match the
 // 13-bit byte counter instead of a generic 32-bit payload comparator.
 reg [BYTE_BITS-1:0] row_payload,row_last;
 reg [BYTE_BITS-1:0] payload_last;
 reg payload_active;
 reg header_good;
 reg pixels_started;
 reg rows_done;
 reg [ROW_BITS-1:0] row_limit;
 // Height is fixed before payload acceptance. Test the last row only at a
 // row boundary, rather than placing a width comparator on every byte CE.
 always @(posedge clk)row_limit<=height[ROW_BITS-1:0]-1'b1;
 reg [1:0] phase;
 reg [7:0] blue,green,red;
 // Keep the RGB-only port for legacy bmp_read and decoder test callers.
 assign pixel_rgb = pixel_rgba[31:8];
 wire take_byte = file_valid && file_ready;
 // The header uses offsets 0..53 only. Capture its small address during the
 // upstream FETCH cycle; 63 is an inert address for all non-header bytes.
 // Generic callers may supply consecutive bytes and retain the direct path.
 reg [5:0] header_offset;
 always @(posedge clk)
  header_offset <= (file_byte_offset[31:6]==0) ? file_byte_offset[5:0] : 6'd63;
 wire [31:0] header_byte_offset = HEADER_OFFSET_LOOKAHEAD ?
    {26'd0,header_offset} : file_byte_offset;
 // The range-mode sector buffer delivers every byte in order. Once the
 // payload starts, row completion bounds it without a wide offset comparator
 // on every pixel/row write-enable path. Fixed legacy mode retains its check.
 wire in_pixel_region=RANGE_DIMENSIONS ?
    ((pixels_started || file_byte_offset==pixel_offset) && !rows_done) :
    (file_byte_offset>=pixel_offset && {2'b0,file_byte_offset}<pixel_end);
 // Let header_good settle before accepting the first payload byte, even
 // when a generic flow-controlled caller supplies consecutive header bytes.
 assign file_ready = !FLOW_CONTROL ||
    ((!pixel_valid || pixel_ready) && (!header_complete || checked));
 assign image_width = width[15:0];
 assign image_height = height[15:0];
 wire [15:0] actual_width = RANGE_DIMENSIONS ? width[15:0] : tw;
 wire [17:0] payload_24 = {2'b00,actual_width}+{1'b0,actual_width,1'b0};
 wire [17:0] payload_bytes = is_32 ? {actual_width,2'b00} : payload_24;
 always @(posedge clk) begin
  row_payload <= payload_bytes;
  payload_last <= {14'd0,payload_bytes}-1'b1;
  row_last <= row_stride-1'b1;
 end
 bmp_header_check #(.ALLOW_32(ALLOW_32),.RANGE_DIMENSIONS(RANGE_DIMENSIONS)) u_header (
  .clk(clk),.rst(rst || file_start),.file_valid(active && take_byte),
  .file_byte(file_byte),.file_byte_offset(header_byte_offset),.bmp_width(tw),.bmp_height(th),
  .file_len(declared_size),.pixel_offset(pixel_offset),.width(width),.height(height),
  .required_end(pixel_end),.header_match(header_ok),.skip_format(),
  .expected_pixels(expected_pixels),.header_complete(header_complete),.is_32(is_32),.row_stride(row_stride)
 );
 // Header fields settle before byte 53; split the independent directory-size
 // bound without changing the header-complete or first-payload handshake.
 reg size_hi_gt_end,size_hi_eq_end,size_lo_ge_end;
 always @(posedge clk or posedge rst)begin
  if(rst)begin size_hi_gt_end<=0;size_hi_eq_end<=0;size_lo_ge_end<=0;end
  else begin
   size_hi_gt_end<={2'b0,size_reg[31:16]}>pixel_end[33:16];
   size_hi_eq_end<={2'b0,size_reg[31:16]}==pixel_end[33:16];
   size_lo_ge_end<=size_reg[15:0]>=pixel_end[15:0];
  end
 end
 wire accepted_header=header_ok && (size_hi_gt_end || (size_hi_eq_end && size_lo_ge_end));
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   active<=0;checked<=0;end_pending<=0;size_reg<=0;header_good<=0;pixels_started<=0;rows_done<=0;payload_active<=1;
   header_accepted<=0;pixel_valid<=0;frame_commit<=0;bmp_done<=0;bmp_error<=0;
   pixel_rgba<=0;pixel_x<=0;pixel_y<=0;row_byte<=0;row<=0;col<=0;pixel_count<=0;phase<=0;
   blue<=0;green<=0;red<=0;
  end else begin
   header_accepted<=0;frame_commit<=0;bmp_done<=0;
   if(!FLOW_CONTROL || pixel_ready) pixel_valid<=0;
   if(file_start) begin
    active<=1;checked<=0;end_pending<=0;size_reg<=file_size;bmp_error<=0;header_good<=0;pixels_started<=0;rows_done<=0;payload_active<=1;
    row_byte<=0;row<=0;col<=0;pixel_count<=0;phase<=0;pixel_valid<=0;
   end else if(active) begin
    if(header_complete && !checked) begin
     checked<=1;
     if(accepted_header)begin header_accepted<=1;header_good<=1;end
     else begin bmp_error<=1;active<=0;end
    end
    if(take_byte && (FLOW_CONTROL?header_good:accepted_header) && in_pixel_region) begin
     pixels_started<=1;
     // Predict the next byte's payload membership while advancing the row.
     // This holds across stalls and keeps the row comparator off pixel/col CE.
     // Valid rows have at least one pixel; byte zero is always payload.
     if(RANGE_DIMENSIONS)payload_active <= (row_byte==row_last) || (row_byte<payload_last);
     if(RANGE_DIMENSIONS ? payload_active : row_byte < row_payload) begin
      if(phase==0)blue<=file_byte;
      if(phase==1)green<=file_byte;
      if(phase==2)red<=file_byte;
      // A 32bpp pixel is complete only after its fourth (alpha/T) byte.
      if((!is_32 && phase==2)||(is_32 && phase==3))begin
       pixel_rgba<=is_32 ? {red,green,blue,file_byte} : {file_byte,green,blue,8'hFF};pixel_valid<=1;
       pixel_x<=col;pixel_y<=height-1-row;pixel_count<=pixel_count+1;col<=col+1;
      end
      if((!is_32 && phase==2)||(is_32 && phase==3))phase<=0;else phase<=phase+1;
     end
     if(row_byte==row_last)begin row_byte<=0;row<=row+1;col<=0;phase<=0;rows_done<=row==row_limit;end
     else row_byte<=row_byte+1;
    end
    if(file_end)begin
     end_pending<=1;
    end
    if(end_pending && (!FLOW_CONTROL || !pixel_valid || pixel_ready))begin
     active<=0;end_pending<=0;
     // Check after the final byte has updated both counters. file_end may
     // coincide with that byte, including a 32bpp pixel's alpha byte.
     if(checked && pixel_count==expected_pixels && row==height && row_byte==0)begin
      frame_commit<=1;bmp_done<=1;bmp_error<=0;
     end else bmp_error<=3;
    end
    if(upstream_error!=0)begin active<=0;bmp_error<=2;pixel_valid<=0;end
   end
  end
 end
endmodule
