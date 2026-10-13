// Latest-state held-bus mailbox, followed by a frame-boundary commit.
module media_adjust_cdc(
 input src_clk,src_rst,input [23:0] src_state,
 input dst_clk,dst_rst,frame_start,output reg [23:0] frame_state
);
 localparam [23:0] DEFAULT_STATE={2'd0,2'd0,8'd128,8'd128,4'd10};
 reg [23:0] held,pending;
 reg request,acknowledge;
 (* ASYNC_REG="TRUE" *)reg [1:0] req_sync,ack_sync;
 always @(posedge src_clk or posedge src_rst)begin
  if(src_rst)begin held<=DEFAULT_STATE;request<=0;ack_sync<=0;end
  else begin
   ack_sync<={ack_sync[0],acknowledge};
   if(request==ack_sync[1] && src_state!=held)begin held<=src_state;request<=~request;end
  end
 end
 always @(posedge dst_clk or posedge dst_rst)begin
  if(dst_rst)begin pending<=DEFAULT_STATE;frame_state<=DEFAULT_STATE;req_sync<=0;acknowledge<=0;end
  else begin
   req_sync<={req_sync[0],request};
   if(req_sync[1]!=acknowledge)begin pending<=held;acknowledge<=req_sync[1];end
   if(frame_start)frame_state<=pending;
  end
 end
endmodule
