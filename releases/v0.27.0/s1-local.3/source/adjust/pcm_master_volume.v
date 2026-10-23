// Elastic stereo sample register. Gain advances only when input is accepted.
// v0.27: levels 0..20 give 0..200% in 10% steps; above 100% the output saturates.
module pcm_master_volume(
 input clk,rst,input [4:0] volume_level,input fade_mute,output muted,
 input in_valid,output wire in_ready,input signed [15:0] in_left,in_right,
 output reg out_valid,input out_ready,output reg signed [15:0] out_left,out_right
);
 reg [17:0] gain;
 reg [17:0] target,next_gain;
 reg fade_q,fade_recover;
 wire [17:0] step=(fade_mute || fade_q || fade_recover)?18'd14:18'd256;
 assign muted=gain==0 && (!out_valid || (out_left==0 && out_right==0));
 always @*begin
  // round(level*65536/10)
  case(volume_level)
   0:target=0;1:target=6554;2:target=13107;3:target=19661;4:target=26214;
   5:target=32768;6:target=39322;7:target=45875;8:target=52429;9:target=58982;
   10:target=65536;11:target=72090;12:target=78643;13:target=85197;14:target=91750;
   15:target=98304;16:target=104858;17:target=111411;18:target=117965;19:target=124518;
   default:target=131072;
  endcase
  if(fade_mute)target=0;
  if(gain<target)next_gain=(target-gain>step)?gain+step:target;
  else next_gain=(gain-target>step)?gain-step:target;
 end
 wire signed [34:0] left_product=in_left*$signed({1'b0,next_gain});
 wire signed [34:0] right_product=in_right*$signed({1'b0,next_gain});
 wire signed [18:0] left_scaled=left_product>>>16,right_scaled=right_product>>>16;
 function signed [15:0] clip(input signed [18:0] v);
  clip=(v > 19'sd32767) ? 16'sd32767 : (v < -19'sd32768) ? -16'sd32768 : v[15:0];
 endfunction
 assign in_ready=!rst && (!out_valid || out_ready);
 always @(posedge clk or posedge rst)begin
  if(rst)begin gain<=65536;out_valid<=0;out_left<=0;out_right<=0;fade_q<=0;fade_recover<=0;end
  else begin
   fade_q<=fade_mute;
   if(fade_q && !fade_mute)fade_recover<=1;
   else if(in_ready && in_valid && next_gain==target)fade_recover<=0;
   if(in_ready)begin
    out_valid<=in_valid;
    if(in_valid)begin gain<=next_gain;out_left<=clip(left_scaled);out_right<=clip(right_scaled);end
   end
  end
 end
endmodule
