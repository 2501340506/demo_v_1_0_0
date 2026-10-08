// 8N1 byte transmitter, adapted from lesson 4 uart_tx_byte.
module uart_tx_byte #(
    parameter integer CLKS_PER_BIT = 868
)(
    input wire clk, rst,
    input wire start,
    input wire [7:0] data,
    output reg tx, busy, done
);
localparam integer COUNT_BITS = (CLKS_PER_BIT > 1) ? $clog2(CLKS_PER_BIT) : 1;
reg [COUNT_BITS-1:0] clk_count;
reg [3:0] bit_index;
reg [9:0] frame;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        clk_count <= 0;
        bit_index <= 0;
        frame <= 10'h3ff;
        tx <= 1;
        busy <= 0;
        done <= 0;
    end else begin
        done <= 0;
        if (!busy) begin
            tx <= 1;
            clk_count <= 0;
            bit_index <= 0;
            if (start) begin
                frame <= {1'b1, data, 1'b0};
                tx <= 0;
                busy <= 1;
            end
        end else if (clk_count == CLKS_PER_BIT - 1) begin
            clk_count <= 0;
            if (bit_index == 9) begin
                tx <= 1;
                busy <= 0;
                done <= 1;
            end else begin
                bit_index <= bit_index + 1'b1;
                tx <= frame[bit_index + 1'b1];
            end
        end else clk_count <= clk_count + 1'b1;
    end
end
endmodule
