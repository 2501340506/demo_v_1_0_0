// Latest complete configuration mailbox. Payload is held through frame ack.
module subtitle_frame_commit(
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
    // A new payload is taken only after the previous one was applied, and both
    // sides reset to the same default, so dst always holds the previous payload
    // when the next applies; the text/length change is decided at load time.
    reg held_changed;
    (* ASYNC_REG = "TRUE" *) reg [1:0] req_sync, ack_sync;
    wire [124:0] live = {src_enable,src_length,src_text};
    wire apply_now = frame_start && req_sync[1] != acknowledge;
    assign text_changed = apply_now && held_changed;
    always @(posedge src_clk or posedge src_rst) begin
        if(src_rst) begin
            held <= {1'b1,4'd12,DEFAULT_TEXT}; held_changed<=0; request<=0; ack_sync<=0;
        end else begin
            ack_sync <= {ack_sync[0],acknowledge};
            if(request==ack_sync[1] && live!=held) begin
                held<=live; held_changed<=live[123:0]!=held[123:0]; request<=~request;
            end
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
