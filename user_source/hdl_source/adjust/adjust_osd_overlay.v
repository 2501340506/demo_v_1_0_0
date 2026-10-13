module adjust_osd_overlay #(parameter ENABLE=1)(
 input clk,rst,vs,de,input [9:0] pixel_x,input [23:0] rgb_in,
 input [1:0] mode,selected,input [7:0] brightness,contrast,input [3:0] volume_level,
 output [23:0] rgb_out,output active
);
 wire [8:0] y;
 osd_pixel_position position(.clk(clk),.rst(rst),.vs(vs),.de(de),.line_y(y),.frame_start(),.first_active());
 wire [9:0] dx=pixel_x-10'd8;wire [8:0] dy=y-9'd32;
 wire visible=ENABLE && (mode==1 || mode==2);
 wire region=visible && de && pixel_x>=8 && pixel_x<296 && y>=32 && y<48;
 wire band=visible && de && pixel_x>=4 && pixel_x<300 && y>=28 && y<52;
 // Decimal conversion is outside the pixel address mux.
 wire [7:0] volume={4'd0,volume_level}*8'd10;
 function [23:0] decimal;
  input [7:0] value;reg [7:0] remnant,h,t;
  begin
   h=value>=200?2:value>=100?1:0;remnant=value-h*8'd100;
   t=remnant>=90?9:remnant>=80?8:remnant>=70?7:remnant>=60?6:remnant>=50?5:
     remnant>=40?4:remnant>=30?3:remnant>=20?2:remnant>=10?1:0;
   decimal={8'd48+h,8'd48+t,8'd48+remnant-t*8'd10};
  end
 endfunction
 wire [23:0] b_digits=decimal(brightness),c_digits=decimal(contrast),v_digits=decimal(volume);
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
 end
 wire [4:0] glyph;
 osd_font_5x7 font(.character(character),.row(dy[3:1]),.pixels(glyph));
 assign active=region && dx[3:1]<5 && dy[3:1]<7 && glyph[3'd4-dx[3:1]];
 assign rgb_out=active?(item==selected?24'hffff00:24'hffffff):
  band?{1'b0,rgb_in[23:17],1'b0,rgb_in[15:9],1'b0,rgb_in[7:1]}:rgb_in;
endmodule
