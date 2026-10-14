// Address follows issued memory requests, not live HDMI coordinates.
module thumbnail_address_v015 (
 input clk,rst,reload,advance, input preview,
 input [7:0] bank_map, input [1:0] fullscreen_bank,
 output [20:0] address
);
 reg [9:0] x; reg [8:0] y;
 reg active_preview; reg [7:0] banks; reg [1:0] full_bank;
 wire [1:0] image_id={y>=240,x>=320};
 wire [1:0] bank=active_preview ? (banks >> {image_id,1'b0}) : full_bank;
 wire [9:0] local_x=x>=320?x-10'd320:x;
 wire [8:0] local_y=y>=240?y-9'd240:y;
 // The protected controller returns contiguous BL4 words. Thumbnails are
 // packed during loading in the unused region following the four full frames.
 wire [18:0] offset=active_preview ? local_y*19'd320+local_x : y*19'd640+x;
 assign address=active_preview ? 21'd1228800+bank*21'd76800+offset : bank*21'd307200+offset;
 always @(posedge clk or posedge rst) begin
  if(rst) begin x<=0;y<=0;active_preview<=0;banks<=0;full_bank<=0;end
  else if(reload) begin x<=0;y<=0;active_preview<=preview;banks<=bank_map;full_bank<=fullscreen_bank;end
  else if(advance) begin
   if(x==639) begin x<=0;y<=y==479?9'd0:y+1'b1;end
   else x<=x+1'b1;
  end
 end
endmodule
