`timescale 1ns/1ps
// Renders one frame of the scene OSD through the real scene_text_overlay, over a real picture
// (bg.hex: 640x480 RGB, one 24-bit hex word per pixel), and writes it to frame.hex.
// +STAGE=n +WARN=0/1 +T=t +SCROLL=px +FRAMES=frames-counter (blink: 0 steady, 16 fast blink on, 32 slow on)
// +HUD=0/1 +SUB=0/1 (v0.27 panel OSD / SCROLL switches, default 1)
module tb_osd_render;
 reg clk=0,wr_clk=0;always #5 clk=~clk;always #7 wr_clk=~wr_clk;
 reg rst=1,hs=1,vs=1,de=0,wen=0,kind=0,fv=0,tv=0,en=0,warn=0,hud=1,sub=1;
 reg [1:0] stage=0;reg [7:0] tnow=0;reg [9:0] x=0;reg [11:0] wa=0;reg [7:0] wd=0;
 reg [7:0] fm[0:4095],tm[0:4095];reg [23:0] bg[0:307199];integer fbytes,tbytes;
 wire [10:0] fa,ta;wire [15:0] fd,td;wire ho,vo,deo,available,active;wire [9:0] xo;wire [23:0] rgb;
 wire [8:0] y;wire fs,first;
 osd_pixel_position pos(.clk(clk),.rst(rst),.vs(vs),.de(de),.line_y(y),.frame_start(fs),.first_active(first));
 scene_bram32k fr(.wr_clk(wr_clk),.wr_en(wen && !kind),.wr_addr(wa),.wr_data(wd),.rd_clk(clk),.rd_addr(fa),.rd_data(fd));
 scene_bram32k tr(.wr_clk(wr_clk),.wr_en(wen && kind),.wr_addr(wa),.wr_data(wd),.rd_clk(clk),.rd_addr(ta),.rd_data(td));
 wire [23:0] pic=(de && y<480 && x<640)?bg[y*640+x]:24'h000000;
 scene_text_overlay dut(.clk(clk),.rst(rst),.hs(hs),.vs(vs),.de(de),.pixel_x(x),.rgb_in(pic),
  .font_valid(fv),.text_valid(tv),.font_count(8'(fbytes/32)),.text_bytes(13'(tbytes)),.resource_generation(1'b0),.scene_enable(en),.warn_mode(warn),.stage(stage),.t_now(tnow),
  .legacy_region(1'b0),.legacy_char(8'd0),.legacy_row(4'd0),.legacy_col(4'd0),
  .font_available(available),.scene_text_active(active),.text_addr(ta),.text_data(td),.font_addr(fa),.font_data(fd),
  .hs_out(ho),.vs_out(vo),.de_out(deo),.x_out(xo),.rgb_out(rgb),.hud_enable(hud),.subtitle_enable(sub));
 task load(input bit text_kind,input integer count);
  begin kind=text_kind;for(integer i=0;i<count;i++)begin @(negedge wr_clk);wen=1;wa=i;wd=text_kind?tm[i]:fm[i];end
   @(negedge wr_clk);wen=0;end
 endtask
 integer out,st,wr,tt,sc,fc,yy,xx,hv,sv;
 reg [23:0] cap[0:307199];integer cy,cx;
 // The overlay output is three clocks behind its input: capture by the output's own x and a line counter.
 integer oline=-1;reg deo_q=0;
 always @(posedge clk)begin
  if(deo && !deo_q)oline=oline+1;     // blocking: the first pixel of a line already belongs to the new line
  deo_q<=deo;
  if(deo && oline>=0 && oline<480 && xo<640)cap[oline*640+xo]<=rgb;
 end
 task frame;
  begin
   @(negedge clk);vs=0;de=0;repeat(12)@(negedge clk);vs=1;
   for(yy=0;yy<480;yy++)begin
    for(xx=0;xx<650;xx++)begin @(negedge clk);de=xx<640;x=xx;end
    @(negedge clk);de=0;
   end
   repeat(12)@(negedge clk);
  end
 endtask
 initial begin
  $readmemh("font.hex",fm);$readmemh("text.hex",tm);$readmemh("bg.hex",bg);
  if(!$value$plusargs("F_BYTES=%d",fbytes) || !$value$plusargs("T_BYTES=%d",tbytes))$fatal(1,"sizes");
  if(!$value$plusargs("STAGE=%d",st))st=0;if(!$value$plusargs("WARN=%d",wr))wr=0;
  if($value$plusargs("HUD=%d",hv))hud=hv!=0;if($value$plusargs("SUB=%d",sv))sub=sv!=0;
  if(!$value$plusargs("T=%d",tt))tt=239;if(!$value$plusargs("SCROLL=%d",sc))sc=0;if(!$value$plusargs("FRAMES=%d",fc))fc=0;
  #2000;load(0,fbytes);load(1,tbytes);rst=0;fv=1;tv=1;
  repeat(9000)@(negedge clk);
  en=1;stage=st;warn=wr;tnow=tt;
  force dut.frames=fc;
  frame();          // settle the parser and the scroll position
  force dut.scroll=sc;
  oline=-1;frame();
  out=$fopen("frame.hex","w");
  for(cy=0;cy<480;cy++)for(cx=0;cx<640;cx++)$fwrite(out,"%06x\n",cap[cy*640+cx]);
  $fclose(out);
  $display("RENDERED stage=%0d warn=%0d t=%0d scroll=%0d",st,wr,tt,sc);$finish;
 end
 initial begin #900000000;$fatal(1,"render watchdog");end
endmodule
