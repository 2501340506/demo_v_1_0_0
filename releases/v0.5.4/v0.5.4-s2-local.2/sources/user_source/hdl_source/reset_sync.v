// Asynchronous assertion, three local clock edges before reset release.
module reset_sync(input clk, input async_rst, output rst);
    (* ASYNC_REG = "TRUE" *) reg [2:0] release_pipe = 3'b111;
    always @(posedge clk or posedge async_rst) begin
        if (async_rst) release_pipe <= 3'b111;
        else release_pipe <= {release_pipe[1:0], 1'b0};
    end
    assign rst = release_pipe[2];
endmodule
