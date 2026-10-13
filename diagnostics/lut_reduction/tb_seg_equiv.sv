`timescale 1ns/1ps
// Old/new seg7_panel + seg_scan: random inputs, seg_sel/seg_data every cycle,
// for scaled timing (debug pages roll) and production timing.
module tb_seg_equiv;
 reg clk=0, rst_n=0;
 reg [1:0] mode=0; reg [3:0] state=4'hf; reg [63:0] dbg=0; reg [7:0] combo=0; reg combo_act=0, autop=0;
 always #5 clk=~clk;
 wire [5:0] rs0,ns0,rs1,ns1; wire [7:0] rd0,nd0,rd1,nd1;
 seg7_panel_ref #(.CLK_FREQ(12000)) r0(.clk(clk),.rst_n(rst_n),.mode(mode),.state_code(state),.sd_debug(dbg),.combo_event_count(combo),.combo_debug_active(combo_act),.auto_play_indicator(autop),.seg_sel(rs0),.seg_data(rd0));
 seg7_panel     #(.CLK_FREQ(12000)) n0(.clk(clk),.rst_n(rst_n),.mode(mode),.state_code(state),.sd_debug(dbg),.combo_event_count(combo),.combo_debug_active(combo_act),.auto_play_indicator(autop),.seg_sel(ns0),.seg_data(nd0));
 seg7_panel_ref r1(.clk(clk),.rst_n(rst_n),.mode(mode),.state_code(state),.sd_debug(dbg),.combo_event_count(combo),.combo_debug_active(combo_act),.auto_play_indicator(autop),.seg_sel(rs1),.seg_data(rd1));
 seg7_panel     n1(.clk(clk),.rst_n(rst_n),.mode(mode),.state_code(state),.sd_debug(dbg),.combo_event_count(combo),.combo_debug_active(combo_act),.auto_play_indicator(autop),.seg_sel(ns1),.seg_data(nd1));
 integer cycle=0, errors=0, pages=0, digits=0, resets=0;
 always @(negedge clk) begin
  if({rs0,rd0,rs1,rd1}!=={ns0,nd0,ns1,nd1}) begin errors++; if(errors<10) $display("MISMATCH cycle=%0d",cycle); end
  if(r0.debug_timer==0 && r0.debug_page!=0 && r0.show_sd_failure) pages++;
  if(rs1!=6'h3f) digits++;
 end
 always @(posedge clk) begin
  cycle<=cycle+1; #1;
  if($urandom%200000==0) state = ($urandom%3) ? 4'hf : $urandom;
  if($urandom%300==0) dbg = {$urandom,$urandom};
  if($urandom%700==0) begin mode=$urandom; combo=$urandom; combo_act=$urandom; autop=$urandom; end
  if(cycle>100 && $urandom%400000==0) begin rst_n=0; resets++; end
  else if(cycle==5 || ($urandom%4==0)) rst_n=1;
 end
 initial begin
  wait(cycle==1500000);
  if(pages<20 || digits<1000 || resets<2) $display("** Error: insufficient coverage pages=%0d digits=%0d resets=%0d",pages,digits,resets);
  else if(errors) $display("** Error: %0d mismatches",errors);
  else $display("PASS seg equivalence cycles=%0d debug_page_steps=%0d production_digit_cycles=%0d resets=%0d",cycle,pages,digits,resets);
  $finish;
 end
endmodule
