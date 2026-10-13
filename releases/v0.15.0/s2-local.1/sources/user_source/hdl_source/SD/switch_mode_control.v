// Synchronize and debounce the complete SW2/SW1 word before publishing a mode.
module switch_mode_control #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer DEBOUNCE_MS = 20
)(
    input wire clk,
    input wire rst,
    input wire [1:0] switches,
    output reg [1:0] mode
);
    localparam integer STABLE_CYCLES = (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;
    localparam integer COUNT_WIDTH = (STABLE_CYCLES > 1) ? $clog2(STABLE_CYCLES + 1) : 1;
    reg [1:0] sync0, sync1, candidate;
    reg [COUNT_WIDTH-1:0] stable_count;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sync0 <= 0;
            sync1 <= 0;
            candidate <= 0;
            stable_count <= 0;
            mode <= 0;
        end else begin
            sync0 <= switches;
            sync1 <= sync0;
            if (sync1 != candidate) begin
                candidate <= sync1;
                stable_count <= 1;
            end else if (stable_count < STABLE_CYCLES) begin
                stable_count <= stable_count + 1'b1;
                if (stable_count == STABLE_CYCLES - 1)
                    mode <= candidate;
            end
        end
    end
endmodule
