// Latest complete configuration mailbox. Payload is held through frame ack.
module subtitle_frame_commit_v015(
    input src_clk, src_rst,
    input [119:0] src_text,
    input [3:0] src_length,
    input src_enable,
    input dst_clk, dst_rst, frame_start,
    output reg [119:0] dst_text,
    output reg [3:0] dst_length,
    output reg dst_enable,
    output wire text_changed
);
    localparam [119:0] DEFAULT_TEXT = 120'h0000002041475046208c8b8b8a8389;
    reg [124:0] held;
    reg request, acknowledge;
    (* ASYNC_REG = "TRUE" *) reg [1:0] req_sync, ack_sync;
    wire [124:0] live = {src_enable,src_length,src_text};
    wire apply_now = frame_start && req_sync[1] != acknowledge;
    assign text_changed = apply_now &&
        (held[123:120] != dst_length || held[119:0] != dst_text);
    always @(posedge src_clk or posedge src_rst) begin
        if(src_rst) begin
            held <= {1'b1,4'd12,DEFAULT_TEXT}; request<=0; ack_sync<=0;
        end else begin
            ack_sync <= {ack_sync[0],acknowledge};
            if(request==ack_sync[1] && live!=held) begin held<=live; request<=~request; end
        end
    end
    always @(posedge dst_clk or posedge dst_rst) begin
        if(dst_rst) begin
            req_sync<=0; acknowledge<=0;
            dst_text<=DEFAULT_TEXT; dst_length<=12; dst_enable<=1;
        end else begin
            req_sync <= {req_sync[0],request};
            if(apply_now) begin
                {dst_enable,dst_length,dst_text} <= held;
                acknowledge <= req_sync[1];
            end
        end
    end
endmodule
