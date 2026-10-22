`timescale 1ns/1ps
// v0.25 S5: scene_text_overlay with BAR_ENABLE=0, LEGEND_ENABLE=0 against the frozen
// v0.25 S3 module, every clock, on a 10-segment card: switching the HUD and legend
// off must give exactly the old overlay. Both see the same random frame terms
// (scene_enable, warn, stage) and the same font/text files; each has its own BRAMs.
module tb_overlay_lockstep;
 parameter integer FRAMES=14;
 reg clk=0,wr_clk=0;always #5 clk=~clk;always #7 wr_clk=~wr_clk;
 reg rst=1,hs=1,vs=1,de=0,wen=0,kind=0,fv=0,tv=0,en=0,warn=0;
 reg [1:0] stage=0;reg [7:0] tnow=0;reg [9:0] x=0;reg [11:0] wa=0;reg [7:0] wd=0;
 reg [7:0] fm[0:4095],tm[0:4095];integer fbytes,tbytes,checks=0,seed=250750;
 wire [10:0] fa0,fa1,ta0,ta1;wire [15:0] fd0,fd1,td0,td1;
 wire ho0,vo0,deo0,av0,ac0,ho1,vo1,deo1,av1,ac1;wire [9:0] xo0,xo1;wire [23:0] rgb0,rgb1;
 wire [8:0] y;wire fs,first;
 osd_pixel_position pos(.clk(clk),.rst(rst),.vs(vs),.de(de),.line_y(y),.frame_start(fs),.first_active(first));
 wire legacy=!en && de && y>=200 && y<216 && x>=8 && x<216;
 wire [7:0] lc=8'h80+((x-8)>>4);
 scene_bram32k fr0(.wr_clk(wr_clk),.wr_en(wen && !kind),.wr_addr(wa),.wr_data(wd),.rd_clk(clk),.rd_addr(fa0),.rd_data(fd0));
 scene_bram32k tr0(.wr_clk(wr_clk),.wr_en(wen && kind),.wr_addr(wa),.wr_data(wd),.rd_clk(clk),.rd_addr(ta0),.rd_data(td0));
 scene_bram32k fr1(.wr_clk(wr_clk),.wr_en(wen && !kind),.wr_addr(wa),.wr_data(wd),.rd_clk(clk),.rd_addr(fa1),.rd_data(fd1));
 scene_bram32k tr1(.wr_clk(wr_clk),.wr_en(wen && kind),.wr_addr(wa),.wr_data(wd),.rd_clk(clk),.rd_addr(ta1),.rd_data(td1));
 scene_text_overlay #(.BAR_ENABLE(0),.LEGEND_ENABLE(0)) dut(.clk(clk),.rst(rst),.hs(hs),.vs(vs),.de(de),.pixel_x(x),.rgb_in(24'h123456),
  .font_valid(fv),.text_valid(tv),.font_count(8'(fbytes/32)),.text_bytes(13'(tbytes)),.scene_enable(en),.warn_mode(warn),.stage(stage),.t_now(tnow),
  .legacy_region(legacy),.legacy_char(lc),.legacy_row(4'(y-200)),.legacy_col(4'(x-8)),
  .font_available(av0),.scene_text_active(ac0),.text_addr(ta0),.text_data(td0),.font_addr(fa0),.font_data(fd0),
  .hs_out(ho0),.vs_out(vo0),.de_out(deo0),.x_out(xo0),.rgb_out(rgb0));
 scene_text_overlay_v025s3 ref_(.clk(clk),.rst(rst),.hs(hs),.vs(vs),.de(de),.pixel_x(x),.rgb_in(24'h123456),
  .font_valid(fv),.text_valid(tv),.font_count(8'(fbytes/32)),.text_bytes(13'(tbytes)),.scene_enable(en),.warn_mode(warn),.stage(stage),
  .legacy_region(legacy),.legacy_char(lc),.legacy_row(4'(y-200)),.legacy_col(4'(x-8)),
  .font_available(av1),.scene_text_active(ac1),.text_addr(ta1),.text_data(td1),.font_addr(fa1),.font_data(fd1),
  .hs_out(ho1),.vs_out(vo1),.de_out(deo1),.x_out(xo1),.rgb_out(rgb1));
 task load(input bit text_kind,input integer count);
  begin kind=text_kind;for(integer i=0;i<count;i++)begin @(negedge wr_clk);wen=1;wa=i;wd=text_kind?tm[i]:fm[i];end
   @(negedge wr_clk);wen=0;end
 endtask
 always @(posedge clk)if(!rst)begin
  #1;if({ho0,vo0,deo0,xo0,rgb0,av0,ac0,ta0,fa0}!=={ho1,vo1,deo1,xo1,rgb1,av1,ac1,ta1,fa1})
   $fatal(1,"overlay differs from the S3 module: en=%0d warn=%0d stage=%0d x=%0d y=%0d rgb %h vs %h",en,warn,stage,x,y,rgb0,rgb1);
  if({dut.title_offset,dut.subtitle_offset,dut.village_offset,dut.title_length,dut.subtitle_length,dut.village_length,dut.parser,dut.scroll,dut.frames}!==
     {ref_.title_offset,ref_.subtitle_offset,ref_.village_offset,ref_.title_length,ref_.subtitle_length,ref_.village_length,ref_.parser,ref_.scroll,ref_.frames})
   $fatal(1,"overlay parser state differs from the S3 module");
  checks++;
 end
 task frame;
  begin
   @(negedge clk);vs=0;de=0;repeat(12)@(negedge clk);vs=1;
   for(integer yy=0;yy<480;yy++)begin
    for(integer xx=0;xx<650;xx++)begin @(negedge clk);de=xx<640;x=xx;end
    @(negedge clk);de=0;
   end
   repeat(12)@(negedge clk);
  end
 endtask
 integer f;
 initial begin
  $readmemh("font.hex",fm);$readmemh("text.hex",tm);
  if(!$value$plusargs("F_BYTES=%d",fbytes) || !$value$plusargs("T_BYTES=%d",tbytes))$fatal(1,"sizes");
  #2000;load(0,fbytes);load(1,tbytes);rst=0;fv=1;tv=1;
  repeat(9000)@(negedge clk);
  for(f=0;f<FRAMES;f=f+1)begin
   en=($random(seed)&3)!=0;warn=($random(seed)&3)==0;stage=$random(seed);tnow=$random(seed);
   frame();
  end
  $display("PASS overlay lockstep: %0d frames, %0d clocks, HUD and legend off equal the S3 overlay",FRAMES,checks);$finish;
 end
 initial begin #400000000;$fatal(1,"lockstep watchdog");end
endmodule
