`timescale 1ns/1ps
// v0.24 S1 digit-panel page selection.
// exact:    new seg7_panel fed by a combinational page select must match the
//           original 64-bit panel on every cycle.
// pipeline: the top-level crossing (copied from top_tf_hdmi_audio.v) selects
//           the page in the SD domain. Outputs may differ only shortly after
//           a page or debug-value change; all other cycles must match.
module tb_seg_page_s1;
 parameter integer SEED=3, CYCLES=600000, WINDOW=12;
 reg clk=0, sd_clk=0;
 always #10 clk=~clk;       // panel 50 MHz
 always #5 sd_clk=~sd_clk;   // SD 100 MHz, same PLL edges
 reg rst=1;
 reg [63:0] sd_debug=64'h0123456789abcdef;
 reg [3:0] state=4'hf; reg [1:0] mode=0; reg [7:0] combo=0; reg combo_active=0, autop=0;
 reg scene_en=0, scene_warn=0; reg [1:0] scene_stage=0;
 integer seed=SEED;
 function integer urand(input integer n); begin urand=$unsigned($random(seed))%n; end endfunction

 // Original: whole bus through the half-cycle stage and two panel registers.
 reg [63:0] r_half,r_panel0,r_panel1;
 always @(negedge sd_clk or posedge rst) if(rst) r_half<=0; else r_half<=sd_debug;
 always @(posedge clk or posedge rst) if(rst) begin r_panel0<=0;r_panel1<=0; end else begin r_panel0<=r_half;r_panel1<=r_panel0; end
 wire [5:0] r_sel; wire [7:0] r_seg;
 seg7_panel_reference #(.CLK_FREQ(1200),.SCAN_FREQ(100),.SCENE_ENABLE(1)) ref_panel(
  .clk(clk),.rst_n(!rst),.mode(mode),.scene_enable(scene_en),.scene_warn(scene_warn),.scene_stage(scene_stage),
  .state_code(state),.sd_debug(r_panel1),.combo_event_count(combo),.combo_debug_active(combo_active),
  .auto_play_indicator(autop),.seg_sel(r_sel),.seg_data(r_seg));

 // Exact: same delayed bus, page selected combinationally in the panel domain.
 wire [1:0] x_page; wire [5:0] x_sel; wire [7:0] x_seg;
 seg7_panel #(.CLK_FREQ(1200),.SCAN_FREQ(100),.SCENE_ENABLE(1)) exact_panel(
  .clk(clk),.rst_n(!rst),.mode(mode),.scene_enable(scene_en),.scene_warn(scene_warn),.scene_stage(scene_stage),
  .state_code(state),.debug_word(r_panel1[16*x_page+:16]),.combo_event_count(combo),.combo_debug_active(combo_active),
  .auto_play_indicator(autop),.seg_sel(x_sel),.seg_data(x_seg),.debug_page(x_page));

 // Pipeline: production crossing.
 wire [1:0] p_page; wire [5:0] p_sel; wire [7:0] p_seg;
 reg [1:0] page_sd0,page_sd1; reg [15:0] p_word,p_half,p_panel0,p_panel1;
 always @(posedge sd_clk or posedge rst)
  if(rst) begin page_sd0<=0;page_sd1<=0;p_word<=0; end
  else begin page_sd0<=p_page;page_sd1<=page_sd0;p_word<=sd_debug[16*page_sd1+:16]; end
 always @(negedge sd_clk or posedge rst) if(rst) p_half<=0; else p_half<=p_word;
 always @(posedge clk or posedge rst) if(rst) begin p_panel0<=0;p_panel1<=0; end else begin p_panel0<=p_half;p_panel1<=p_panel0; end
 seg7_panel #(.CLK_FREQ(1200),.SCAN_FREQ(100),.SCENE_ENABLE(1)) pipe_panel(
  .clk(clk),.rst_n(!rst),.mode(mode),.scene_enable(scene_en),.scene_warn(scene_warn),.scene_stage(scene_stage),
  .state_code(state),.debug_word(p_panel1),.combo_event_count(combo),.combo_debug_active(combo_active),
  .auto_play_indicator(autop),.seg_sel(p_sel),.seg_data(p_seg),.debug_page(p_page));

 integer cycles=0,exact_bad=0,pipe_bad=0,pipe_late=0,since_change=1000,page_changes=0,failure_cycles=0;
 reg [1:0] last_page=0; reg [63:0] last_debug=0;
 always @(negedge clk) if(!rst) begin
  cycles=cycles+1;
  if({x_sel,x_seg}!=={r_sel,r_seg})begin exact_bad=exact_bad+1;if(exact_bad<=5)$display("EXACT MISMATCH t=%0t",$time);end
  if(ref_panel.debug_page!=last_page || sd_debug!=last_debug)begin
   since_change=0;if(ref_panel.debug_page!=last_page)page_changes=page_changes+1;
  end else since_change=since_change+1;
  last_page=ref_panel.debug_page;last_debug=sd_debug;
  if(state==4'hf)failure_cycles=failure_cycles+1;
  if({p_sel,p_seg}!=={r_sel,r_seg})begin
   if(since_change>WINDOW)begin pipe_bad=pipe_bad+1;if(pipe_bad<=5)$display("PIPE MISMATCH t=%0t since=%0d",$time,since_change);end
   else pipe_late=pipe_late+1;
  end
 end
 initial begin
  repeat(3)@(posedge clk);rst<=0;
  repeat(CYCLES)begin
   @(posedge clk);
   // Debug values hold for a while, as SD status does; display context varies slowly.
   if(urand(900)==0)sd_debug<={$random(seed),$random(seed)};
   if(urand(20000)==0)state<=urand(3)==0?urand(16):4'hf;
   if(urand(5000)==0)mode<=urand(4);
   if(urand(4000)==0)begin combo_active<=urand(4)==0;combo<=$random(seed);end
   if(urand(3000)==0)begin scene_en<=urand(2);scene_warn<=urand(2);scene_stage<=urand(4);autop<=urand(2);end
  end
  $display("COVERAGE cycles=%0d failure_cycles=%0d page_changes=%0d settle_mismatches=%0d",cycles,failure_cycles,page_changes,pipe_late);
  if(exact_bad!=0 || pipe_bad!=0)$display("FAIL seg page exact=%0d pipeline=%0d",exact_bad,pipe_bad);
  else if(page_changes<40 || failure_cycles<CYCLES/2)$display("FAIL seg page coverage");
  else $display("PASS seg page S1");
  $finish;
 end
endmodule
