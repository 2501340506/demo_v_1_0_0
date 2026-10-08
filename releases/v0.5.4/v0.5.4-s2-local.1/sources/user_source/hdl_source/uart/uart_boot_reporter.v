// S1 sends a single version line after reset. Playback never waits for UART.
module uart_boot_reporter #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer BAUD_RATE = 115200
)(
    input wire clk, rst,
    output wire uart_tx
);
localparam integer CLKS_PER_BIT = (CLK_FREQ_HZ + BAUD_RATE / 2) / BAUD_RATE;
localparam integer MESSAGE_BYTES = 24;
localparam [MESSAGE_BYTES*8-1:0] MESSAGE = "BOOT v0.5.4-s1-local.1\r\n";
reg [4:0] index;
reg start, waiting, sent;
wire done;
wire [7:0] data = MESSAGE[(MESSAGE_BYTES-1-index)*8 +: 8];
uart_tx_byte #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx (
    .clk(clk), .rst(rst), .start(start), .data(data),
    .tx(uart_tx), .busy(), .done(done)
);
always @(posedge clk or posedge rst) begin
    if (rst) begin
        index <= 0;
        start <= 0;
        waiting <= 0;
        sent <= 0;
    end else begin
        start <= 0;
        if (!sent && !waiting) begin
            start <= 1;
            waiting <= 1;
        end else if (waiting && done) begin
            waiting <= 0;
            if (index == MESSAGE_BYTES - 1) sent <= 1;
            else index <= index + 1'b1;
        end
    end
end
endmodule
