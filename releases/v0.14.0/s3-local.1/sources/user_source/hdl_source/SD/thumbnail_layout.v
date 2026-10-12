module thumbnail_layout (
 input in_de,input [9:0] pixel_x,input [8:0] pixel_y,
 input [1:0] focus_index,input [2:0] image_count,input [3:0] image_complete,
 output thumb_de,output [1:0] source_index,
 output [9:0] source_x,output [8:0] source_y,output focus_border
);
 wire [9:0] lx=pixel_x>=320?pixel_x-10'd320:pixel_x;
 wire [8:0] ly=pixel_y>=240?pixel_y-9'd240:pixel_y;
 wire in_window=in_de && pixel_x<640 && pixel_y<480;
 assign source_index={pixel_y>=240,pixel_x>=320};
 assign source_x={lx[8:0],1'b0};
 assign source_y={ly[7:0],1'b0};
 assign thumb_de=in_window && image_complete[source_index];
 assign focus_border=in_window && {1'b0,source_index}<image_count && source_index==focus_index &&
   (lx<2 || lx>=318 || ly<2 || ly>=238);
endmodule
