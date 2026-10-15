// Playback samples are counted where ready/valid is accepted. Gray transfer
// preserves events; the 100 MHz consumer drains one per cycle (48 kHz source).
module scene_event_cdc(
 input pix_clk,pix_rst,sample_accept,frame_start,
 input clk,rst,output sample_tick,output frame_tick
);
 reg [7:0] count,gray;
 reg frame_toggle;
 (* ASYNC_REG="TRUE" *) reg [7:0] gray0,gray1;
 (* ASYNC_REG="TRUE" *) reg [1:0] frame_sync;
 reg [7:0] consumed;
 reg frame_seen;
 wire [7:0] next_count=count+1'b1;
 wire [7:0] received;
 assign received[7]=gray1[7];
 genvar i;
 generate for(i=0;i<7;i=i+1)begin:g_decode
  assign received[i]=received[i+1]^gray1[i];
 end endgenerate
 assign sample_tick=received!=consumed;
 assign frame_tick=frame_sync[1]!=frame_seen;
 always @(posedge pix_clk or posedge pix_rst)begin
  if(pix_rst)begin count<=0;gray<=0;frame_toggle<=0;end
  else begin
   if(sample_accept)begin count<=next_count;gray<=(next_count>>1)^next_count;end
   if(frame_start)frame_toggle<=!frame_toggle;
  end
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin gray0<=0;gray1<=0;consumed<=0;frame_sync<=0;frame_seen<=0;end
  else begin
   gray0<=gray;gray1<=gray0;frame_sync<={frame_sync[0],frame_toggle};frame_seen<=frame_sync[1];
   if(sample_tick)consumed<=consumed+1'b1;
  end
 end
endmodule
