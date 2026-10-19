module media_player_control #(parameter integer AUTO_PLAY_CYCLES = 300_000_000, parameter UI_GATE=0, parameter PAUSE_ENABLE=0)(
 input clk, rst, enable, scan_done, display_valid, load_busy,
 input pause,
 input first_image_committed, manual_activity, request_accept,
 input [2:0] image_count,
 input [1:0] current_image,
 input [1:0] mode,
 input next_event, previous_event, auto_toggle_event,
 output reg auto_play_en, next_pending, previous_pending,
 output auto_tick, load_request,
 output next_load_request, previous_load_request, auto_load_request,
 output [1:0] target_image
);
 reg [31:0] auto_count;
 reg [1:0] mode_seen;
 wire available = enable && scan_done && display_valid && !load_busy &&
                  first_image_committed && (image_count != 0);
 wire auto_allowed = auto_play_en && (image_count > 1) &&
                     !auto_toggle_event && !next_event && !previous_event &&
                     !manual_activity && !next_pending && !previous_pending;
 assign auto_tick = (auto_count == AUTO_PLAY_CYCLES - 1);
 assign next_load_request = available && next_pending;
 assign previous_load_request = available && !next_pending && previous_pending;
 // A mode change restarts the interval; suppress an expiry before acceptance.
 assign auto_load_request = available && auto_allowed && auto_tick && (mode == mode_seen) && (!UI_GATE || mode==0);
 assign load_request = next_load_request || previous_load_request || auto_load_request;
 // The consumer samples this index on the same edge as request_accept.
 // Busy-time requests store direction only, never an index from an older frame.
 // target_image is consumed only with load_request. Select direction without
 // routing availability through the image/sector mux on the acceptance path.
 assign target_image = (!next_pending && previous_pending) ? prev_index_limited(current_image, image_count) :
                                              next_index_limited(current_image, image_count);
function [1:0] next_index_limited;
    input [1:0] cur;
    input [2:0] count;
    begin
        // Direct bit equations avoid cascaded count/current-index muxes.
        // Equivalent for every 3-bit count and 2-bit current index.
        next_index_limited[0] = (count > 1) && !cur[0] && !(count == 3 && cur[1]);
        next_index_limited[1] = (count > 1) && (cur[1] ^ cur[0]) &&
                                !(count == 2 && !cur[1]) && !(count == 3 && cur[1]);
    end
endfunction

function [1:0] prev_index_limited;
    input [1:0] cur;
    input [2:0] count;
    begin
        prev_index_limited[0] = (count > 1) && !cur[0] && !(count == 3 && !cur[1]);
        prev_index_limited[1] = (count > 1) && ((cur == 3) || ((cur == 0) && count != 2));
    end
endfunction


 always @(posedge clk or posedge rst) begin
   if (rst) begin
     auto_play_en <= 0; auto_count <= 0; next_pending <= 0; previous_pending <= 0; mode_seen <= 0;
   end else if (PAUSE_ENABLE && pause) begin
     // A temporary menu owns the keys/cache. Preserve AUTO for cancellation,
     // but discard queued navigation and restart the playback interval.
     auto_count <= 0; next_pending <= 0; previous_pending <= 0; mode_seen <= mode;
   end else if (!enable) begin
     auto_play_en <= 0; auto_count <= 0; next_pending <= 0; previous_pending <= 0; mode_seen <= mode;
   end else begin
     if (scan_done && image_count > 1 && auto_toggle_event)
       auto_play_en <= ~auto_play_en;
     if(!UI_GATE && (mode==3 || mode_seen==3)) auto_play_en<=0;
     if (mode != mode_seen) begin
       mode_seen <= mode;
       auto_count <= 0;
     end else if (available && auto_allowed && (!UI_GATE || mode==0)) begin
       if (auto_tick) auto_count <= 0;
       else auto_count <= auto_count + 1'b1;
     end else auto_count <= 0;
     if (request_accept && load_request) begin
       // Navigation makes auto_allowed false; an AUTO request has auto_tick
       // set. Both cases already reset above. Avoid feeding cache-ready and
       // preview arbitration back through the 32-bit counter reset mux.
       if (next_load_request) next_pending <= 0;
       else if (previous_load_request) previous_pending <= 0;
     end
     // Capture after consumption: a same-cycle event survives.
     if (scan_done && image_count != 0) begin
       if (next_event) next_pending <= 1;
       if (previous_event) previous_pending <= 1;
     end
     if(UI_GATE && mode!=mode_seen)begin next_pending<=0;previous_pending<=0;end
   end
 end
endmodule
