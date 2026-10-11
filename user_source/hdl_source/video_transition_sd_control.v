`timescale 1ns/1ps
// S1 adapter-domain controller. Frame ticks arrive as a toggle from video_clk;
// the permit pulse is generated in the same domain as the cache commit.
module video_transition_sd_control #(parameter integer FADE_FRAMES=16)(
 input wire clk, input wire rst, input wire display_request, input wire display_valid,
 input wire frame_toggle, input wire display_ack,
 output wire transition_busy, output reg permit_commit
);
 reg ft1,ft2,ft_seen,ack_seen; reg [5:0] count; reg [1:0] state;
 localparam IDLE=0, OUT=1, WAIT=2, IN=3;
 assign transition_busy=(state!=IDLE);
 always @(posedge clk or posedge rst) begin
  if(rst) begin ft1<=0;ft2<=0;ft_seen<=0;ack_seen<=display_ack;count<=0;state<=IDLE;permit_commit<=0;end
  else begin
   ft1<=frame_toggle; ft2<=ft1; permit_commit<=0;
   case(state)
    IDLE: if(display_request && display_valid) begin state<=OUT; count<=FADE_FRAMES[5:0]; end
    // The first frame after scan/rescan keeps the established hard-cut path.
    // It has no previous displayed bank to fade out from.
    OUT: if(ft2!=ft_seen) begin ft_seen<=ft2; if(count==0) begin permit_commit<=1; state<=WAIT; end else count<=count-1'b1; end
    WAIT: if(display_ack!=ack_seen) begin ack_seen<=display_ack; count<=0; state<=IN; end
    IN: if(ft2!=ft_seen) begin ft_seen<=ft2; if(count>=FADE_FRAMES-1) state<=IDLE; else count<=count+1'b1; end
    default: state<=IDLE;
   endcase
  end
 end
endmodule
