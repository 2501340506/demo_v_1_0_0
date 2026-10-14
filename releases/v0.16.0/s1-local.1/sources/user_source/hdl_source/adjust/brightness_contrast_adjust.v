// Four clocks, one RGB888 pixel per clock. Sidebands travel with the pixel.
module brightness_contrast_adjust #(parameter SIDE_WIDTH=1)(
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
 // Bit forms of the original adders: value>=32640 is value[15] or
 // value[14:7]==255; value[14:7]-128 inverts bit 14 and sign-extends it.
 function signed [8:0] centered;
  input [15:0] value;
  begin
   centered=(value[15] || &value[14:7])?9'sd127:{~value[14],~value[14],value[13:7]};
  end
 endfunction
 // (product>>>7)+128 stays in 0..255 exactly when product[17:14] agree; the
 // in-range sum inverts bit 14, otherwise the sign selects 0 or 255.
 function [7:0] saturated;
  input signed [17:0] product;
  begin
   if(product[17:14]==4'b0000 || product[17:14]==4'b1111) saturated={~product[14],product[13:7]};
   else saturated=product[17]?8'd0:8'd255;
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
