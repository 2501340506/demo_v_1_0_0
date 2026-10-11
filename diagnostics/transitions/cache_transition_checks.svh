// Checks the real production adapter, CDC, SDRAM pixels and final effect.
wire [23:0] transition_rgb;
video_transition_pixels effect(.level(transition_level),.wipe_active(transition_wipe),.de(de),.pixel_x(x),
 .rgb_in(display_valid?rgb:24'd0),.rgb_out(transition_rgb));
reg [4:0] level_expected=16;
reg [1:0] effect_phase=0;
reg commit_observed=0;
integer fade_count=0,effect_pixels=0,black_frames=0;
reg old_commit_request=0,old_audio_update=0;
reg source_auto=0,expected_wipe_kind=0;
integer wipe_count=0,manual_count=0;
always @(posedge src_clk) if(!rst) begin
 if(app.ctrl_request_accept)source_auto=app.ctrl_auto_load_request;
 if(commit_req!=old_commit_request && app.transition_busy && transition_level!==0)
  $fatal(1,"reader request issued before black");
 old_commit_request=commit_req;
 if(app.ctrl_request_accept && app.transition_busy)$fatal(1,"accepted next request during transition");
 if(app.rescan_event && app.transition_busy)$fatal(1,"rescan passed active transition");
end
// Independent ramp model starts when local pixel busy becomes visible;
// brightness must not change until the next frame boundary.
always @(posedge pix_clk) begin
 if(rst) begin level_expected=16;effect_phase=0;commit_observed=0;end
 else begin
  if(effect_phase==0 && transition_active) begin effect_phase=1;fade_count=fade_count+1;expected_wipe_kind=source_auto;
   if(source_auto)wipe_count=wipe_count+1;else manual_count=manual_count+1;end
  if(effect_phase==2 && media_update)commit_observed=1;
  if(transition_frame_start) case(effect_phase)
   1: begin level_expected=level_expected-1; if(level_expected==0)begin effect_phase=2;commit_observed=0;end end
   2: begin black_frames=black_frames+1;if(commit_observed) begin level_expected=1;effect_phase=3;end end
   3: begin level_expected=level_expected+1;if(level_expected==16)effect_phase=0;end
  endcase
  #1;
  if(transition_wipe!==(effect_phase==3 && expected_wipe_kind))$fatal(1,"wrong effect source or frame boundary");
  if(transition_level!==level_expected)$fatal(1,"production ramp %d expected %d",transition_level,level_expected);
 end
end
reg [23:0] effect_expected;
integer base_r,base_g,base_b;
always @(negedge pix_clk) if(!rst && de) begin
 base_r=display_valid?rgb[23:16]:0;
 base_g=display_valid?rgb[15:8]:0;
 base_b=display_valid?rgb[7:0]:0;
 effect_expected={8'(base_r*level_expected/16),8'(base_g*level_expected/16),8'(base_b*level_expected/16)};
 if(effect_phase==3 && expected_wipe_kind)effect_expected=x<level_expected*40?rgb:24'd0;
 if(transition_rgb!==effect_expected)$fatal(1,"effect pixel x=%0d level=%0d",x,level_expected);
 effect_pixels=effect_pixels+1;
end
final begin
 if(wipe_count<2 || manual_count<10)$error("insufficient manual/AUTO coverage");
 if(fade_count<10 || black_frames<fade_count || effect_pixels<307200)$error("insufficient transition coverage");
 $display("PASS S2 origin: %0d AUTO wipes, %0d manual fades",wipe_count,manual_count);
 $display("PASS transition system: %0d fades, %0d black frames, %0d pixels",fade_count,black_frames,effect_pixels);
end
