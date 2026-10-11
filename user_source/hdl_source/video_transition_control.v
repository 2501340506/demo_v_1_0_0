`timescale 1ns/1ps

// S1 frame-level transition sequencer. The display owner starts a transition
// only after the target bank is ready; permit_commit is asserted at black.
module video_transition_control #(
    parameter integer FADE_FRAMES = 16
) (
    input wire clk, input wire rst,
    input wire request, input wire request_ready,
    input wire commit_done,
    input wire frame_start,
    output wire busy, output wire permit_commit,
    output wire active, output wire [4:0] level
);
    localparam [2:0] IDLE=0, OUT=1, WAIT_COMMIT=2, IN=3;
    reg [2:0] state;
    reg [5:0] count;
    reg permit_r;
    assign busy = state != IDLE;
    assign active = state != IDLE;
    assign permit_commit = permit_r;
    assign level = (state == OUT) ? count[4:0] :
                   (state == IN) ? count[4:0] :
                   (state == WAIT_COMMIT) ? 5'd0 : 5'd16;
    always @(posedge clk or posedge rst) begin
        if (rst) begin state<=IDLE; count<=0; permit_r<=0; end
        else begin
            permit_r <= 1'b0;
            case (state)
            IDLE: if (request && request_ready) begin state<=OUT; count<=FADE_FRAMES[5:0]; end
            OUT: if (frame_start) begin
                if (count == 0) begin state<=WAIT_COMMIT; permit_r<=1'b1; end
                else count<=count-1'b1;
            end
            WAIT_COMMIT: if (commit_done) begin state<=IN; count<=0; end
            IN: if (frame_start) begin
                if (count >= FADE_FRAMES-1) state<=IDLE;
                else count<=count+1'b1;
            end
            default: state<=IDLE;
            endcase
        end
    end
endmodule
