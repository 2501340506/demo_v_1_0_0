// Latest-state mailbox. The held bus stays fixed until the pixel domain
// acknowledges it. Changes while busy are coalesced into the next transfer.
module osd_status_cdc (
    input src_clk, src_rst,
    input src_auto,
    input [7:0] src_error,
    input dst_clk, dst_rst,
    output reg dst_auto,
    output reg [7:0] dst_error
);
    reg [8:0] held_status;
    reg request, acknowledge;
    (* ASYNC_REG = "TRUE" *) reg [1:0] req_sync, ack_sync;
    wire [8:0] live_status = {src_auto, src_error};
    always @(posedge src_clk or posedge src_rst) begin
        if (src_rst) begin
            held_status <= 0;
            request <= 0;
            ack_sync <= 0;
        end else begin
            ack_sync <= {ack_sync[0], acknowledge};
            if (request == ack_sync[1] && live_status != held_status) begin
                held_status <= live_status;
                request <= ~request;
            end
        end
    end
    always @(posedge dst_clk or posedge dst_rst) begin
        if (dst_rst) begin
            req_sync <= 0;
            acknowledge <= 0;
            dst_auto <= 0;
            dst_error <= 0;
        end else begin
            req_sync <= {req_sync[0], request};
            if (req_sync[1] != acknowledge) begin
                {dst_auto, dst_error} <= held_status;
                acknowledge <= req_sync[1];
            end
        end
    end
endmodule
