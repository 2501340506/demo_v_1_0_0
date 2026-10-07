`timescale 1ns/1ps
// The 16-point, +/-12000 LUT is adapted from lesson 3 pcm_test_tone.v.
// Replace the lesson's integer divider/index step with 48 kHz pacing + DDS.
module pcm_test_tone #(
    parameter integer CLOCK_HZ = 25000000,
    parameter integer SAMPLE_HZ = 48000,
    parameter integer TONE_HZ = 440
)(
    input wire clk, rst_n, enable,
    output wire sample_valid,
    input wire sample_ready,
    output wire signed [15:0] sample_left, sample_right,
    output wire sample_tick,
    output reg overflow
);
    localparam integer RATE_BITS = $clog2(CLOCK_HZ + SAMPLE_HZ);
    localparam [31:0] PHASE_STEP = ((64'd4294967296 * TONE_HZ) + SAMPLE_HZ/2) / SAMPLE_HZ;
    reg [RATE_BITS-1:0] rate_acc;
    reg [31:0] phase;
    reg signed [15:0] fifo[0:7];
    reg [2:0] wr_ptr, rd_ptr;
    reg [3:0] count;
    wire pop = sample_valid && sample_ready;
    wire push = sample_tick && (count < 8 || pop);
    assign sample_tick = rst_n && enable && (rate_acc >= CLOCK_HZ - SAMPLE_HZ);
    assign sample_valid = rst_n && enable && count != 0;
    assign sample_left = fifo[rd_ptr];
    assign sample_right = fifo[rd_ptr];

    function signed [15:0] sine_sample;
        input [3:0] index;
        begin
            case (index)
                0: sine_sample=0;
                1: sine_sample=4592;
                2: sine_sample=8485;
                3: sine_sample=11087;
                4: sine_sample=12000;
                5: sine_sample=11087;
                6: sine_sample=8485;
                7: sine_sample=4592;
                8: sine_sample=0;
                9: sine_sample=-4592;
                10: sine_sample=-8485;
                11: sine_sample=-11087;
                12: sine_sample=-12000;
                13: sine_sample=-11087;
                14: sine_sample=-8485;
                default: sine_sample=-4592;
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rate_acc<=0; phase<=0; wr_ptr<=0; rd_ptr<=0; count<=0; overflow<=0;
        end else if (!enable) begin
            rate_acc<=0; phase<=0; wr_ptr<=0; rd_ptr<=0; count<=0; overflow<=0;
        end else begin
            if (sample_tick) begin
                rate_acc <= rate_acc + SAMPLE_HZ - CLOCK_HZ;
                phase <= phase + PHASE_STEP;
                if (!push) overflow <= 1;
            end else rate_acc <= rate_acc + SAMPLE_HZ;
            if (push) begin
                fifo[wr_ptr] <= sine_sample(phase[31:28]);
                wr_ptr <= wr_ptr + 1'b1;
            end
            if (pop) rd_ptr <= rd_ptr + 1'b1;
            case ({push,pop})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end
endmodule
