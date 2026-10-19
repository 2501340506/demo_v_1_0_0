`timescale 1ns/1ps
// SD-clock UI state and an independent frame-description mailbox.
module media_preview_control(
 input clk,rst,input [1:0] mode,
 input scan_busy,first_image_committed,transition_busy,foreground_busy,rescan_wait,
 input next_event,previous_event,toggle_event,
 input [1:0] current_image,input [2:0] image_count,
 input [3:0] cache_valid,input [7:0] cache_banks,
 input request_ready,request_failed,storage_stopped,display_request,display_committed,
 output request_valid,output [1:0] request_image,output target_select,
 output preview_intent,output selecting,output fullscreen_ready,
 output reg preview_request,output reg [17:0] preview_descriptor,input preview_ack
);
 reg entered,full_view,select_pending,offer;
 reg [1:0] focus,target;
 reg [1:0] ack_sync;
 wire mailbox_idle=ack_sync[1]==preview_request;
 assign preview_intent=entered && !full_view && mode==3 && !scan_busy && !rescan_wait;
 assign selecting=select_pending;
 assign request_valid=offer && !rescan_wait;
 // Target selection is independent of same-cycle request inhibition. The
 // owner suppresses every competing non-scene offer during rescan_wait.
 assign target_select=offer;
 assign request_image=target;
 assign fullscreen_ready=mailbox_idle && !preview_descriptor[17] && !preview_intent;
 wire [17:0] desired={preview_intent,focus,image_count,cache_valid,cache_banks};
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   entered<=0;full_view<=0;select_pending<=0;offer<=0;focus<=0;target<=0;
   ack_sync<=0;preview_request<=0;preview_descriptor<=0;
  end else begin
   ack_sync<={ack_sync[0],preview_ack};
   if(mailbox_idle && desired!=preview_descriptor)begin
    preview_descriptor<=desired;preview_request<=~preview_request;
   end
   if(mode!=3 || scan_busy || rescan_wait)begin
    entered<=0;full_view<=0;offer<=0;
    if(offer && !request_ready)select_pending<=0;
   end
   else if(!entered && first_image_committed && !transition_busy && !foreground_busy)begin
    entered<=1;full_view<=0;focus<=current_image;
   end else if(entered && !select_pending)begin
    if(preview_intent)begin
     if(next_event && image_count!=0)focus<=({1'b0,focus}+1>=image_count)?2'd0:focus+1'b1;
     else if(previous_event && image_count!=0)focus<=focus==0?image_count-1'b1:focus-1'b1;
     if(toggle_event && image_count!=0 && !foreground_busy)begin
      target<=focus;offer<=1;select_pending<=1;
     end
    end else if(toggle_event && !transition_busy && !foreground_busy)begin full_view<=0;focus<=current_image;end
   end
   if(offer && request_ready)offer<=0;
   if(offer && storage_stopped && !cache_valid[target])begin offer<=0;select_pending<=0;end
   // Keep preview visible throughout an uncached foreground load. Switch its
   // descriptor off only once the cache actually offers the completed image.
   if(select_pending && display_request)full_view<=1;
   if(display_committed || request_failed || scan_busy)begin select_pending<=0;offer<=0;end
  end
 end
endmodule
