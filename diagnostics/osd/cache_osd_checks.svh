// Included in the existing real-data system bench. The stimulus and complete
// SDRAM pixel scoreboard remain unchanged; observe the added production path.
wire osd_auto;
wire [7:0] osd_error;
wire [23:0] osd_base = display_valid ? rgb : 24'd0;
wire [23:0] osd_pixels;
osd_status_cdc status_crossing(.src_clk(src_clk),.src_rst(rst),
 .src_auto(app.auto_play_indicator),.src_error(app.osd_error_code),
 .dst_clk(pix_clk),.dst_rst(rst),.dst_auto(osd_auto),.dst_error(osd_error));
status_osd_overlay overlay(.clk(pix_clk),.rst(rst),.vs(vs),.de(de),.pixel_x(x),
 .rgb_in(osd_base),.image_index(media_id),.image_valid(media_enable),
 .auto_enabled(osd_auto),.error_code(osd_error),.rgb_out(osd_pixels));
integer osd_y=0,osd_frames=0,osd_checked=0;
reg osd_de_prev=0;
reg [11:0] osd_frame_snapshot;
always @(negedge pix_clk) if(!rst) begin
 if(!vs)osd_y=0;
 else if(osd_de_prev && !de)osd_y=osd_y+1;
 osd_de_prev=de;
 if(de && x==1 && osd_y==0) begin
  if(overlay.valid_frame!==display_valid || (display_valid && overlay.image_frame!==app.img_idx))
   $fatal(1,"OSD picture commit missed first line: OSD=%0d actual=%0d",overlay.image_frame,app.img_idx);
  if(overlay.auto_frame!==osd_auto || overlay.error_frame!==osd_error)
   $fatal(1,"OSD status snapshot mismatch");
  osd_frame_snapshot={overlay.valid_frame,overlay.image_frame,overlay.auto_frame,overlay.error_frame};
  osd_frames=osd_frames+1;
 end
 if(de && osd_y>=1 && {overlay.valid_frame,overlay.image_frame,overlay.auto_frame,overlay.error_frame}!==osd_frame_snapshot)
  $fatal(1,"OSD status changed within visible frame");
 if(!de || x<8 || x>=280 || osd_y<8 || osd_y>=24) begin
  if(osd_pixels!==osd_base)$fatal(1,"OSD changed original pixel outside text region");
 end else if(osd_pixels!==osd_base && osd_pixels!==(overlay.error_frame==0?24'hffff00:24'hff4444))
  $fatal(1,"OSD unexpected foreground color");
 osd_checked=osd_checked+1;
end
// These are actual existing error states, not synthetic UART event codes.
always @(negedge src_clk) if(!rst) begin
 if(state_code==4'he && app.osd_error_code!==1)$fatal(1,"no-image OSD error");
 if(state_code==4'hf && app.osd_error_code!==2)$fatal(1,"communication OSD error");
 if(state_code==4'hd && app.osd_error_code!==3)$fatal(1,"load OSD error");
end
final $display("OSD system observations: %0d frame snapshots, %0d pixel/blanking checks",osd_frames,osd_checked);
