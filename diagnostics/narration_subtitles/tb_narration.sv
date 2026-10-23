`timescale 1ns/1ps
`include "narration_params.svh"
module tb_narration;
 reg clk=0,wr_clk=0;always #5 clk=~clk;always #7 wr_clk=~wr_clk;
 reg rst=1,hs=1,vs=1,de=0,tv=0,en=0,playing=0,restart=0,wen=0,done=0;
 reg [1:0] page=0;reg [9:0] x=0;reg [11:0] wa;reg [7:0] wd;
 reg [15:0] words[0:`NARR_WORDS-1];reg [20:0] font[0:`NARR_ROWS-1];
 wire [10:0] ta;wire [15:0] td;wire ho,vo,deo;wire [9:0] xo;wire [23:0] rgb;
 scene_bram32k ram(.wr_clk(wr_clk),.wr_en(wen),.wr_addr(wa),.wr_data(wd),
  .rd_clk(clk),.rd_addr(ta),.rd_data(td));
 publicity_subtitle_overlay dut(.clk(clk),.rst(rst),.hs(hs),.vs(vs),.de(de),.pixel_x(x),.rgb_in(24'h789abc),
  .text_valid(tv),.text_bytes(13'd`NARR_BYTES),.resource_generation(1'b0),.enable(en),.playing(playing),.restart(restart),.done(done),.page(page),
  .text_addr(ta),.text_data(td),.hs_out(ho),.vs_out(vo),.de_out(deo),.x_out(xo),.rgb_out(rgb));
 integer py=0,scroll=0,checks=0,ink=0,visible_chars=0;
 bit compare=0;
 reg [36:0] expect_pipe[0:2];reg [2:0] compare_pipe=0;
 function automatic [23:0] reference(input integer px,yy);
  integer at,tx,code,count;
  begin
   reference=24'h789abc;
   if(en && tv && dut.parser==4 && de && yy>=422 && yy<443 && px<640)begin
    tx=px+scroll-632;count=words[3+page*5];
    if(px>=8 && px<632 && tx>=0 && tx<count*21)begin
     at=words[2+page*5]/2+tx/21;code=words[at];
     if(font[code*21+yy-422] & (21'h100000>>(tx%21)))reference=24'h000000;
    end
   end
  end
 endfunction
 always @(posedge clk)begin
  expect_pipe[2]=expect_pipe[1];expect_pipe[1]=expect_pipe[0];
  expect_pipe[0]={hs,vs,de,x,reference(x,py)};
  compare_pipe={compare_pipe[1:0],compare && !rst};
  #1;
  if(compare_pipe[2])begin
   if({ho,vo,deo,xo,rgb}!==expect_pipe[2])$fatal(1,"pixel page=%d y=%d x=%d got=%h expected=%h",page,py,x,{ho,vo,deo,xo,rgb},expect_pipe[2]);
   checks++;if(rgb==24'h000000)ink++;
  end
 end
 task write_word(input integer at,input reg [15:0] value);
  begin
   @(negedge wr_clk);wen=1;wa=at*2;wd=value[7:0];
   @(negedge wr_clk);wa=at*2+1;wd=value[15:8];
   @(negedge wr_clk);wen=0;
  end
 endtask
 task wait_ready;
  begin
   repeat(2000)@(negedge clk);
   if(dut.parser!=4)$fatal(1,"PS1 not ready page=%d parser=%d",page,dut.parser);
   if(dut.length!=words[3+page*5] || dut.offset!=words[2+page*5])$fatal(1,"descriptor mismatch");
  end
 endtask
 task tick_frame;
  begin vs=0;repeat(3)@(negedge clk);vs=1;repeat(3)@(negedge clk);end
 endtask
 // Tile the full strings through the real TEXT/ROM pixel pipeline. This
 // covers every 21px Song glyph row, punctuation, transparent background,
 // both edges, the removed band area and the gap above maximum waveform.
 integer forced_phase;
 task pixels(input integer amount);
  begin
   scroll=amount;forced_phase=amount*256;force dut.phase=forced_phase;
   compare=1;
   for(integer yy=418;yy<480;yy++)begin
    py=yy;force dut.pos.line_y=py;
    for(integer xx=0;xx<650;xx++)begin x=xx;de=xx<640;@(negedge clk);end
   end
   de=0;repeat(5)@(negedge clk);compare=0;release dut.phase;release dut.pos.line_y;
  end
 endtask
 task invalid(input integer at,input reg [15:0] value);
  begin
   tv=0;repeat(5)@(negedge clk);write_word(at,value);tv=1;
   repeat(2000)@(negedge clk);
   if(dut.parser!=5)$fatal(1,"invalid PS1 accepted word=%d",at);
   en=1;pixels(624);en=0;
   tv=0;repeat(5)@(negedge clk);write_word(at,words[at]);tv=1;wait_ready();
  end
 endtask
 integer expected_phase,limit,step,n,chars,previous,covered;
 initial begin
  $readmemh("text_words.hex",words);$readmemh("font_rows.hex",font);
  repeat(6)@(negedge clk);rst=0;
  for(integer i=0;i<`NARR_WORDS;i++)write_word(i,words[i]);
  tv=1;wait_ready();
  for(integer p=0;p<4;p++)begin
   page=p;en=1;playing=0;wait_ready();
   for(integer chunk=0;chunk<words[3+p*5];chunk+=29)pixels(624+chunk*21);
   pixels(0);pixels(624+words[3+p*5]*21);
   // Real frame events, no phase forcing: each character must cross the
   // left edge before the audio duration expires. Pause holds position.
   playing=1;repeat(3)@(negedge clk);
   if(dut.phase!=0)$fatal(1,"play/replay did not reset");
   step=words[4+p*5];limit=(624+words[3+p*5]*21)*256;
   expected_phase=0;covered=0;previous=-1;
   for(n=0;n<words[5+p*5];n++)begin
    tick_frame();expected_phase=expected_phase+step;if(expected_phase>limit)expected_phase=limit;
    if(dut.phase!=expected_phase)$fatal(1,"scroll step page=%d frame=%d",p,n);
    chars=((expected_phase/256)-624)/21;
    if(expected_phase>=624*256 && chars>=0 && chars<words[3+p*5] && chars!=previous)begin covered++;previous=chars;end
    if(n==300)begin
     playing=0;repeat(3)@(negedge clk);repeat(7)tick_frame();
     if(dut.phase!=expected_phase)$fatal(1,"pause moved");
     // A new playing session is replay, so it intentionally resets.
     playing=1;repeat(3)@(negedge clk);expected_phase=0;
     covered=0;previous=-1;n=-1;
     // Execute pause/replay once per page.
     break;
    end
   end
   for(n=0;n<words[5+p*5];n++)begin
    tick_frame();expected_phase=expected_phase+step;if(expected_phase>limit)expected_phase=limit;
    if(dut.phase!=expected_phase)$fatal(1,"full scroll page=%d frame=%d",p,n);
    chars=((expected_phase/256)-624)/21;
    if(expected_phase>=624*256 && chars>=0 && chars<words[3+p*5] && chars!=previous)begin covered++;previous=chars;end
   end
   if(covered!=words[3+p*5] || dut.phase!=limit)$fatal(1,"incomplete passage %d covered=%d",p,covered);
   visible_chars+=covered;playing=0;repeat(4)tick_frame();
   if(dut.phase!=limit)$fatal(1,"end did not hold");
   restart=1;@(negedge clk);restart=0;@(negedge clk);
   if(dut.phase!=0)$fatal(1,"media commit did not reset");
   en=0;pixels(800);
  end
  // v0.27: the voice ends while text is still on screen (frames were lost at
  // the start). Once done, the rest scrolls off at the same speed; a pause
  // (playing low, not done) still holds; done alone never starts a pass.
  page=0;en=1;restart=1;@(negedge clk);restart=0;wait_ready();
  step=words[4];limit=(624+words[3]*21)*256;
  done=1;repeat(5)tick_frame();if(dut.phase!=0)$fatal(1,"done started a pass");done=0;
  playing=1;repeat(3)@(negedge clk);
  for(n=0;n<words[5]-200;n++)tick_frame();
  expected_phase=(words[5]-200)*step;if(dut.phase!=expected_phase)$fatal(1,"short voice phase");
  playing=0;repeat(3)@(negedge clk);repeat(5)tick_frame();
  if(dut.phase!=expected_phase)$fatal(1,"pause before done moved");
  done=1;
  for(n=0;n<200;n++)begin
   tick_frame();expected_phase=expected_phase+step;if(expected_phase>limit)expected_phase=limit;
   if(dut.phase!=expected_phase)$fatal(1,"tail scroll frame=%d",n);
  end
  if(dut.phase!=limit)$fatal(1,"tail did not reach the end");
  pixels(624+words[3]*21);  // nothing left on screen (reference draws the same)
  // Hidden (enable low) frames still advance while the voice plays.
  done=0;restart=1;@(negedge clk);restart=0;playing=1;repeat(3)@(negedge clk);
  en=0;repeat(10)tick_frame();en=1;
  if(dut.phase!=10*step)$fatal(1,"hidden frames did not advance");
  playing=0;en=0;restart=1;@(negedge clk);restart=0;
  invalid(0,16'h5854);invalid(1,16'h0402);invalid(2,16'd45);
  invalid(3,16'd256);invalid(4,16'd0);invalid(5,16'd0);invalid(6,16'd128);
  invalid(22,16'd`NARR_GLYPHS);invalid(17,16'd`NARR_BYTES-16'd2);
  tv=0;en=1;pixels(624);en=0;
  if(visible_chars!=`NARR_CHARS || ink<1000 || checks<1000000)$fatal(1,"coverage counters");
  $display("PASS narration: %0d pixel/timing checks, %0d black Song 21px ink pixels; all %0d characters/%0d glyphs; transparent background/no band, four full-duration scrolls, pause/replay/commit, short-voice tail scroll and hidden-frame sync, 9 invalid resources, hidden/invalid bypass, wave gap",checks,ink,`NARR_CHARS,`NARR_GLYPHS);
  $finish;
 end
 initial begin #100000000;$fatal(1,"watchdog");end
endmodule
