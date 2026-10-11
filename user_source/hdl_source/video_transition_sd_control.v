`timescale 1ns/1ps
// One outstanding transition. Only event toggles cross clock domains.
// The caller keeps display_request asserted until the real reader ack.
module video_transition_sd_control #(parameter integer ENABLE=1)(
 input wire clk,rst,display_request,display_valid,request_wipe,
 input wire pix_clk,pix_rst,frame_start,commit_done,
 output wire transition_busy,output wire transition_active,
 output wire [4:0] transition_level,output wire permit_commit,
 output wire wipe_active
);
 generate if(ENABLE==0) begin:g_off
  assign transition_busy=0;assign transition_active=0;
  assign wipe_active=0;assign transition_level=16;assign permit_commit=1;
 end else begin:g_on
  reg request_toggle,request_seen,occupied,permit;
  reg black_toggle,done_toggle;
  // Held with request toggle until the returned done: bundled-data CDC.
  reg held_wipe;
  (* ASYNC_REG="TRUE" *) reg [1:0] request_sync,black_sync,done_sync;
  reg black_seen,done_seen;
  wire pixel_busy,black_pulse,done_pulse;
  assign transition_busy=occupied;
  assign transition_active=pixel_busy;
  assign permit_commit=permit;
  always @(posedge clk or posedge rst) begin
   if(rst) begin
    request_toggle<=0;occupied<=0;permit<=0;held_wipe<=0;
    black_sync<=0;done_sync<=0;black_seen<=0;done_seen<=0;
   end else begin
    black_sync<={black_sync[0],black_toggle};done_sync<={done_sync[0],done_toggle};
    if(!occupied && display_request && display_valid) begin
     occupied<=1;permit<=0;request_toggle<=~request_toggle;held_wipe<=request_wipe;
    end
    if(black_sync[1]!=black_seen) begin black_seen<=black_sync[1];permit<=1;end
    if(done_sync[1]!=done_seen) begin done_seen<=done_sync[1];occupied<=0;permit<=0;end
   end
  end
  always @(posedge pix_clk or posedge pix_rst) begin
   if(pix_rst) begin request_sync<=0;request_seen<=0;black_toggle<=0;done_toggle<=0;end
   else begin
    request_sync<={request_sync[0],request_toggle};request_seen<=request_sync[1];
    if(black_pulse) black_toggle<=~black_toggle;
    if(done_pulse) done_toggle<=~done_toggle;
   end
  end
  video_transition_control pixels(.clk(pix_clk),.rst(pix_rst),
   .request(request_sync[1]!=request_seen),.commit_done(commit_done),.frame_start(frame_start),
   .request_wipe(held_wipe),.wipe_active(wipe_active),
   .busy(pixel_busy),.permit_commit(black_pulse),.done(done_pulse),.level(transition_level));
 end endgenerate
endmodule
