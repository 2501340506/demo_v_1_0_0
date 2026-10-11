`timescale 1ns/1ps
// All brightness updates occur in the pixel domain, during frame blanking.
module video_transition_control (
 input wire clk, rst, request, commit_done, frame_start,
 input wire request_wipe,
 output reg wipe_active,
 output wire busy, output reg permit_commit, output reg done,
 output reg [4:0] level
);
 localparam IDLE=0, OUT=1, HOLD=2, IN=3;
 reg [1:0] state;
 reg committed,kind_wipe;
 assign busy=(state!=IDLE);
 always @(posedge clk or posedge rst) begin
  if(rst) begin state<=IDLE;level<=16;permit_commit<=0;done<=0;committed<=0;wipe_active<=0;kind_wipe<=0;end
  else begin
   permit_commit<=0;done<=0;
   case(state)
    IDLE: if(request) begin state<=OUT;committed<=0;kind_wipe<=request_wipe;end
    OUT: if(frame_start) begin
     level<=level-1'b1;
     if(level==1) begin state<=HOLD;permit_commit<=1;end
    end
    HOLD: begin
     if(commit_done) committed<=1;
     if(frame_start && (committed || commit_done)) begin state<=IN;level<=1;wipe_active<=kind_wipe;end
    end
    IN: if(frame_start) begin
     level<=level+1'b1;
     if(level==15) begin state<=IDLE;done<=1;wipe_active<=0;end
    end
   endcase
  end
 end
endmodule
