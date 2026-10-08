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
 localparam ERR_NONE=3'd0, ERR_HEADER=3'd1, ERR_TIMEOUT=3'd2, ERR_TRUNCATED=3'd3;
 reg [7:0] h[0:53]; reg active, header_checked; reg end_pending; reg [31:0] row_byte;
 reg [31:0] size_reg, pixel_offset, width, height, dib_size, compression;
 reg [15:0] planes, bit_count; reg [31:0] row_stride, row, col, pixel_count;
 reg [1:0] bpp_bytes, phase; reg [7:0] b0,b1,b2;
 wire [31:0] target_width=RUNTIME_DIMENSIONS?{16'd0,expected_width}:EXPECTED_WIDTH;
 wire [31:0] target_height=RUNTIME_DIMENSIONS?{16'd0,expected_height}:EXPECTED_HEIGHT;
 wire [31:0] ROW24=((target_width*3+3)/4)*4;
 wire [31:0] ROW32=target_width*4;
 wire [32:0] header_dib_end={1'b0,h[17],h[16],h[15],h[14]}+33'd14;
 wire [33:0] header_required={2'b0,h[13],h[12],h[11],h[10]}+
      (({h[29],h[28]}==32)?(34'd1*ROW32*target_height):(34'd1*ROW24*target_height));
 wire [33:0] pixel_end={2'b0,pixel_offset}+
      ((bit_count==32)?(34'd1*ROW32*target_height):(34'd1*ROW24*target_height));
 function [31:0] le32(input integer p); begin le32={h[p+3],h[p+2],h[p+1],h[p]}; end endfunction
 function [15:0] le16(input integer p); begin le16={h[p+1],h[p]}; end endfunction
 always @(posedge clk or posedge rst) begin
   if(rst) begin active<=0;header_checked<=0;end_pending<=0;row_byte<=0;header_accepted<=0;pixel_valid<=0;
     frame_commit<=0;bmp_done<=0;bmp_error<=0;pixel_rgb<=0;pixel_x<=0;pixel_y<=0;
     size_reg<=0;pixel_offset<=0;width<=0;height<=0;dib_size<=0;compression<=0;
     planes<=0;bit_count<=0;row_stride<=0;row<=0;col<=0;pixel_count<=0;phase<=0;bpp_bytes<=0;
   end else begin
     header_accepted<=0;pixel_valid<=0;frame_commit<=0;bmp_done<=0;
     if(file_start) begin active<=1;end_pending<=0;row_byte<=0;header_checked<=0;size_reg<=file_size;bmp_error<=0;
       row<=0;col<=0;pixel_count<=0;phase<=0;end
     if(file_valid && active) begin
       if(file_byte_offset<54) h[file_byte_offset]<=file_byte;
       
       if(!header_checked && file_byte_offset==53) begin
         dib_size<=le32(14);width<=le32(18);height<=le32(22);planes<=le16(26);
         bit_count<=le16(28);compression<=le32(30);pixel_offset<=le32(10);
         bpp_bytes<=(le16(28)==32)?2:1;
         row_stride<=((le16(28)==32)?ROW32:ROW24);
         header_checked<=1;
         if((h[0]=="B")&&(h[1]=="M")&&(le32(14)>=40)&&(le16(26)==1)&&
            ((le16(28)==24)||(ALLOW_32 && le16(28)==32))&&(le32(30)==0)&&
            (le32(18)==target_width)&&(le32(22)==target_height)&&
            ({1'b0,le32(10)}>=header_dib_end)&&(le32(10)<size_reg)&&
            ({2'b0,size_reg}>=header_required))
           header_accepted<=1;
         else begin bmp_error<=ERR_HEADER;active<=0;end
       end else if(header_checked && (file_byte_offset>=pixel_offset) &&
                  ({2'b0,file_byte_offset}<pixel_end)) begin
         if(row_byte < ((bit_count==32)?target_width*4:target_width*3)) begin
           if(phase==0) b0<=file_byte;
           if(phase==1) b1<=file_byte;
           if(phase==2) begin
             pixel_rgb<={file_byte,b1,b0}; pixel_valid<=1;
             pixel_x<=col; pixel_y<=height-1-row;
             pixel_count<=pixel_count+1; col<=col+1;
           end
           if((bit_count==24 && phase==2)||(bit_count==32 && phase==3)) phase<=0;
           else phase<=phase+1;
         end
         if(row_byte+1==row_stride) begin
           row_byte<=0;row<=row+1;col<=0;phase<=0;
         end else row_byte<=row_byte+1;
       end
     end
     if(file_end&&active) end_pending<=1;
     if(end_pending&&active) begin active<=0;end_pending<=0;
       if(header_checked && pixel_count==target_width*target_height && row==height && row_byte==0) begin frame_commit<=1;bmp_done<=1;bmp_error<=0;end
       else if(bmp_error==0) bmp_error<=ERR_TRUNCATED;
     end
     if(upstream_error!=0) begin active<=0;bmp_error<=ERR_TIMEOUT;end
   end
 end
endmodule
