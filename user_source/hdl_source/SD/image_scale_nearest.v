`timescale 1ns/1ps
// Bottom-up source and destination streams. One synchronous source line RAM.
// Setup uses bounded repeated subtraction, never a pixel-rate divider.
module image_scale_nearest (
 input clk,rst,start, input [15:0] image_width,image_height,
 input in_valid, output in_ready,
 input [31:0] in_rgb, input [15:0] in_x,in_y,
 output out_valid, input out_ready, output [31:0] out_rgb,
 output reg done
);
 localparam IDLE=0,ASPECT=1,ASPECT_DIV=2,X_DIV=3,Y_DIV=4,SETUP=5,
            ROW=6,CAPTURE=7,FETCH=8,EMIT=9,DRAIN=10,ROW_CHECK=11,ASPECT_COMPARE=12;
 reg [3:0] state;
 reg [10:0] sw,sh,dw,dh,left,top,x,y;
 reg [10:0] source_last_x; // Frame-constant row endpoint, computed before capture.
 reg [10:0] right_edge,bottom_edge;
 reg [20:0] dividend;
 reg [10:0] divisor,quotient;
 reg width_fit;
 reg [20:0] width_product,height_product;
 reg aspect_hi_gt,aspect_hi_eq,aspect_lo_ge;
 reg [10:0] xq,xr,yq,yr,sx,xrem,sy,yrem;
 reg [10:0] buffered_y;
 reg row_valid;
 reg [31:0] line [0:1919];
 reg [31:0] ram_pixel;
 // Preserve a combinational delay on the measured short BRAM data path.
 // INIT and EQN both describe identity; this does not add a clock of latency.
 // TD27 also measured short paths on input bits 1 and 28.
 wire [31:0] ram_input_rgb;
 genvar data_bit;
 generate for(data_bit=0;data_bit<32;data_bit=data_bit+1)begin:g_line_data_hold
  if(data_bit==1 || data_bit==13 || data_bit==28)begin:g_delay
   (* keep = "true" *) AL_MAP_LUT1 #(.INIT(2'b10),.EQN("A"))
    u_hold (.o(ram_input_rgb[data_bit]),.a(in_rgb[data_bit]));
  end else assign ram_input_rgb[data_bit]=in_rgb[data_bit];
 end endgenerate
 wire [10:0] ram_input_x;
 assign ram_input_x[10:6]=in_x[10:6];
 assign ram_input_x[4]=in_x[4];
 assign ram_input_x[2:0]=in_x[2:0];
 // TD10: raw_pipe_x[3] -> line RAM hold was -0.020 ns.
 (* keep = "true" *) AL_MAP_LUT1 #(.INIT(2'b10),.EQN("A"))
  u_line_address3_hold (.o(ram_input_x[3]),.a(in_x[3]));
 (* keep = "true" *) AL_MAP_LUT1 #(.INIT(2'b10),.EQN("A"))
  u_line_address_hold (.o(ram_input_x[5]),.a(in_x[5]));
 reg pixel_black;
 reg row_inside,row_not_top;
 wire col_inside = x>=left && x<right_edge;
 wire [11:0] xsum={1'b0,xrem}+{1'b0,xr};
 wire [11:0] yborrow={1'b0,yrem}+{1'b0,dh}-{1'b0,yr};
 assign in_ready=state==CAPTURE || state==DRAIN;
 assign out_valid=state==EMIT;
 assign out_rgb=pixel_black ? {24'd0,8'hFF} : ram_pixel;
 always @(posedge clk) begin
  if(in_valid && in_ready && state==CAPTURE) line[ram_input_x]<=ram_input_rgb;
  if(state==FETCH) ram_pixel<=line[sx];
 end
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   state<=IDLE;source_last_x<=0;right_edge<=0;bottom_edge<=0;sw<=0;sh<=0;dw<=0;dh<=0;left<=0;top<=0;x<=0;y<=0;
   dividend<=0;divisor<=1;quotient<=0;width_fit<=0;
   width_product<=0;height_product<=0;aspect_hi_gt<=0;aspect_hi_eq<=0;aspect_lo_ge<=0;
   xq<=0;xr<=0;yq<=0;yr<=0;sx<=0;xrem<=0;sy<=0;yrem<=0;
   buffered_y<=0;row_valid<=0;pixel_black<=1;done<=0;row_inside<=0;row_not_top<=0;
  end else begin
   done<=0;
   if(start) begin
    sw<=image_width[10:0];sh<=image_height[10:0];source_last_x<=image_width[10:0]-11'd1;
    // Constant shifts/adds avoid a DSP output followed by a wide compare.
    width_product<=({10'd0,image_width[10:0]}<<9)-({10'd0,image_width[10:0]}<<5);
    height_product<=({10'd0,image_height[10:0]}<<9)+({10'd0,image_height[10:0]}<<7);
    row_valid<=0;state<=ASPECT_COMPARE;
   end else case(state)
    ASPECT_COMPARE: begin
     aspect_hi_gt<=width_product[20:10]>height_product[20:10];
     aspect_hi_eq<=width_product[20:10]==height_product[20:10];
     aspect_lo_ge<=width_product[9:0]>=height_product[9:0];
     state<=ASPECT;
    end
    ASPECT: begin
     width_fit<=aspect_hi_gt || (aspect_hi_eq && aspect_lo_ge);
     if(aspect_hi_gt || (aspect_hi_eq && aspect_lo_ge)) begin dividend<=height_product;divisor<=sw;end
     else begin dividend<=width_product;divisor<=sh;end
     quotient<=0;state<=ASPECT_DIV;
    end
    ASPECT_DIV: if(dividend>=divisor) begin dividend<=dividend-divisor;quotient<=quotient+1'b1;end
     else begin
      dw<=width_fit?11'd640:(quotient==0?11'd1:quotient);
      dh<=width_fit?(quotient==0?11'd1:quotient):11'd480;
      dividend<=sw;divisor<=width_fit?11'd640:(quotient==0?11'd1:quotient);
      quotient<=0;state<=X_DIV;
     end
    X_DIV: if(dividend>=divisor) begin dividend<=dividend-divisor;quotient<=quotient+1'b1;end
     else begin xq<=quotient;xr<=dividend[10:0];dividend<=sh;divisor<=dh;quotient<=0;state<=Y_DIV;end
    Y_DIV: if(dividend>=divisor) begin dividend<=dividend-divisor;quotient<=quotient+1'b1;end
     else begin yq<=quotient;yr<=dividend[10:0];state<=SETUP;end
    SETUP: begin
     left<=(11'd640-dw)>>1;top<=(11'd480-dh)>>1;
     right_edge<=((11'd640-dw)>>1)+dw;
     bottom_edge<=((11'd480-dh)>>1)+dh;
     x<=0;y<=479;sx<=0;xrem<=0;
     sy<=sh-yq-(yr!=0);yrem<=yr==0?11'd0:dh-yr;
     state<=ROW_CHECK;
    end
    // Compare row bounds before enabling the vertical coordinate arithmetic.
    ROW_CHECK: begin
     row_inside<=y>=top && y<bottom_edge;
     row_not_top<=y!=top;
     state<=ROW;
    end
    ROW: begin
     x<=0;sx<=0;xrem<=0;
     if(!row_inside || (row_valid && buffered_y==sy)) state<=FETCH;
     else state<=CAPTURE;
    end
    CAPTURE: if(in_valid && in_ready && in_x=={5'd0,source_last_x}) begin
     buffered_y<=in_y[10:0];row_valid<=1;
     if(in_y==sy) state<=FETCH;
    end
    FETCH: begin pixel_black<=!row_inside || !col_inside;state<=EMIT;end
    EMIT: if(out_ready) begin
     if(x==639) begin
      if(y==0) begin done<=1;state<=DRAIN;end
      else begin
       y<=y-1'b1;
       if(row_inside && row_not_top) begin
        if(yrem<yr) begin sy<=sy-yq-1'b1;yrem<=yborrow[10:0];end
        else begin sy<=sy-yq;yrem<=yrem-yr;end
       end
       state<=ROW_CHECK;
      end
     end else begin
      x<=x+1'b1;
      if(col_inside) begin
       if(xsum>=dw) begin sx<=sx+xq+1'b1;xrem<=xsum-dw;end
       else begin sx<=sx+xq;xrem<=xsum[10:0];end
      end
      state<=FETCH;
     end
    end
    default: ;
   endcase
  end
 end
endmodule
