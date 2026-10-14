// Four clocks, one RGB888 pixel per clock. Sidebands travel with the pixel.
module brightness_contrast_adjust_v015 #(parameter SIDE_WIDTH=1)(
 input clk,rst,input [23:0] rgb_in,input [7:0] brightness,contrast,
 input [SIDE_WIDTH-1:0] side_in,
 output reg [23:0] rgb_out,output wire [SIDE_WIDTH-1:0] side_out
);
 reg [15:0] bright_mul[0:2];
 reg signed [8:0] center[0:2];
 reg signed [17:0] contrast_mul[0:2];
 reg [7:0] contrast_1,contrast_2;
 reg [SIDE_WIDTH-1:0] side[0:3];
 integer i;
 function signed [8:0] centered;
  input [15:0] value;
  begin centered=(value>=16'd32640)?9'sd127:$signed({1'b0,value[14:7]})-9'sd128;end
 endfunction
 function [7:0] saturated;
  input signed [17:0] product;
  reg signed [17:0] value;
  begin
   value=(product>>>7)+18'sd128;
   saturated=value<0?8'd0:value>255?8'd255:value[7:0];
  end
 endfunction
 assign side_out=side[3];
 // Internal arithmetic is ignored until the reset sideband pipeline refills.
 // Keep these registers free-running so DSP registers need no async reset.
 integer channel;
 always @(posedge clk)begin
  for(channel=0;channel<3;channel=channel+1)begin
   bright_mul[channel]<=rgb_in[channel*8+:8]*brightness;
   center[channel]<=centered(bright_mul[channel]);
   contrast_mul[channel]<=center[channel]*$signed({1'b0,contrast_2});
  end
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   rgb_out<=0;contrast_1<=128;contrast_2<=128;
   for(i=0;i<4;i=i+1)side[i]<=0;
  end else begin
   side[0]<=side_in;for(i=1;i<4;i=i+1)side[i]<=side[i-1];
   contrast_1<=contrast;contrast_2<=contrast_1;
   for(i=0;i<3;i=i+1)begin
    rgb_out[i*8+:8]<=saturated(contrast_mul[i]);
   end
  end
 end
endmodule
