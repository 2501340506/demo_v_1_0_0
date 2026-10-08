module bmp24_decoder #(
    parameter integer EXPECTED_WIDTH = 640,
    parameter integer EXPECTED_HEIGHT = 480,
    parameter integer RUNTIME_DIMENSIONS = 0,
    parameter integer ALLOW_32 = 1
) (
    input wire clk, input wire rst,
    input wire [15:0] expected_width, expected_height,
    input wire file_start, input wire [31:0] file_size,
    input wire file_valid, input wire [7:0] file_byte,
    input wire [31:0] file_byte_offset, input wire file_end,
    input wire [7:0] upstream_error,
    output reg header_accepted, output reg pixel_valid,
    output reg [23:0] pixel_rgb, output reg [15:0] pixel_x, pixel_y,
    output reg frame_commit, output reg bmp_done, output reg [2:0] bmp_error
);
 wire [15:0] tw=RUNTIME_DIMENSIONS?expected_width:EXPECTED_WIDTH;
 wire [15:0] th=RUNTIME_DIMENSIONS?expected_height:EXPECTED_HEIGHT;
 wire [31:0] declared_size,pixel_offset,width,height,row_stride,expected_pixels;
 wire [33:0] pixel_end;
 wire header_ok,header_complete,is_32;
 reg active,checked,end_pending;
 reg [31:0] size_reg,row_byte,row,col,pixel_count;
 reg [1:0] phase;
 reg [7:0] blue,green;
 bmp_header_check #(.ALLOW_32(ALLOW_32)) u_header (
  .clk(clk),.rst(rst || file_start),.file_valid(active && file_valid),
  .file_byte(file_byte),.file_byte_offset(file_byte_offset),.bmp_width(tw),.bmp_height(th),
  .file_len(declared_size),.pixel_offset(pixel_offset),.width(width),.height(height),
  .required_end(pixel_end),.header_match(header_ok),.skip_format(),
  .expected_pixels(expected_pixels),.header_complete(header_complete),.is_32(is_32),.row_stride(row_stride)
 );
 wire accepted_header=header_ok && {2'b0,size_reg}>=pixel_end;
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   active<=0;checked<=0;end_pending<=0;size_reg<=0;
   header_accepted<=0;pixel_valid<=0;frame_commit<=0;bmp_done<=0;bmp_error<=0;
   pixel_rgb<=0;pixel_x<=0;pixel_y<=0;row_byte<=0;row<=0;col<=0;pixel_count<=0;phase<=0;
   blue<=0;green<=0;
  end else begin
   header_accepted<=0;pixel_valid<=0;frame_commit<=0;bmp_done<=0;
   if(file_start) begin
    active<=1;checked<=0;end_pending<=0;size_reg<=file_size;bmp_error<=0;
    row_byte<=0;row<=0;col<=0;pixel_count<=0;phase<=0;
   end else if(active) begin
    if(header_complete && !checked) begin
     checked<=1;
     if(accepted_header) header_accepted<=1;
     else begin bmp_error<=1;active<=0;end
    end
    if(file_valid && accepted_header && file_byte_offset>=pixel_offset && {2'b0,file_byte_offset}<pixel_end) begin
     if(row_byte < (is_32?{16'd0,tw}*4:{16'd0,tw}*3)) begin
      if(phase==0)blue<=file_byte;
      if(phase==1)green<=file_byte;
      if(phase==2)begin
       pixel_rgb<={file_byte,green,blue};pixel_valid<=1;
       pixel_x<=col;pixel_y<=height-1-row;pixel_count<=pixel_count+1;col<=col+1;
      end
      if((!is_32 && phase==2)||(is_32 && phase==3))phase<=0;else phase<=phase+1;
     end
     if(row_byte+1==row_stride)begin row_byte<=0;row<=row+1;col<=0;phase<=0;end
     else row_byte<=row_byte+1;
    end
    if(file_end)end_pending<=1;
    if(end_pending)begin
     active<=0;end_pending<=0;
     if(checked && pixel_count==expected_pixels && row==height && row_byte==0)begin
      frame_commit<=1;bmp_done<=1;bmp_error<=0;
     end else bmp_error<=3;
    end
    if(upstream_error!=0)begin active<=0;bmp_error<=2;pixel_valid<=0;end
   end
  end
 end
endmodule
