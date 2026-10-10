module osd_alpha_band #(parameter integer ENABLE=1)(
 input clk,rst,vs,de,input [9:0] pixel_x,input [23:0] rgb_in,
 output wire [23:0] rgb_out,output wire active);
 reg [8:0] line_y; reg de_q;
 always @(posedge clk or posedge rst) begin if(rst)begin line_y<=0;de_q<=0;end else begin de_q<=de;if(!vs)line_y<=0;else if(de_q&&!de)line_y<=line_y+1'b1;end end
 wire status_band=ENABLE && de && pixel_x>=4 && pixel_x<284 && line_y>=4 && line_y<28;
 wire scroll_band=ENABLE && de && pixel_x>=8 && pixel_x<632 && line_y>=440 && line_y<464;
 wire band=status_band||scroll_band;
 // Preserve the already rendered yellow/red/white glyphs; darken only the image.
 wire glyph=(rgb_in==24'hffff00)||(rgb_in==24'hff4444)||(rgb_in==24'hffffff);
 assign active=band&&!glyph;
 assign rgb_out=active?{1'b0,rgb_in[23:17],1'b0,rgb_in[15:9],1'b0,rgb_in[7:1]}:rgb_in;
endmodule
