// Held-data request/ack transfer: source bus stays fixed until returned ack.
module media_commit_cdc #(parameter WIDTH=2)(
 input src_clk, input dst_clk, input src_rst, input dst_rst,
 input [WIDTH-1:0] src_image, input src_valid, output src_ready,
 output reg [WIDTH-1:0] media_id, output reg media_update, output reg media_enable
);
 reg [WIDTH-1:0] held_image;
 reg request, acknowledge;
 (* ASYNC_REG = "TRUE" *) reg [1:0] ack_sync, req_sync;
 assign src_ready = request == ack_sync[1];
 always @(posedge src_clk or posedge src_rst) begin
  if (src_rst) begin held_image<=0; request<=0; ack_sync<=0; end
  else begin
   ack_sync <= {ack_sync[0], acknowledge};
   if (src_valid && src_ready) begin
    held_image <= src_image;
    request <= ~request;
   end
  end
 end
 always @(posedge dst_clk or posedge dst_rst) begin
  if (dst_rst) begin
   req_sync<=0; acknowledge<=0; media_id<=0; media_update<=0; media_enable<=0;
  end else begin
   req_sync <= {req_sync[0], request};
   media_update <= 0;
   if (req_sync[1] != acknowledge) begin
    media_id <= held_image;
    media_update <= 1;
    media_enable <= 1;
    acknowledge <= req_sync[1];
   end
  end
 end
endmodule
