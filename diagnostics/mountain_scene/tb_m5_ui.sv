`timescale 1ns/1ps
module tb_m5_ui;
 reg clk=0;always #5 clk=~clk;reg rst=1,vs=1,de=0,en=1,warn=0;
 reg [9:0] x=0;reg [1:0] stage=0,speed=0;reg [3:0] state=1;
 wire [5:0] sel;wire [7:0] seg;wire [23:0] rgb;integer digits=0,pixels=0;
 wire [63:0] debug_bus=64'h123456789abcdef0;wire [1:0] debug_page;
 seg7_panel #(.CLK_FREQ(1200),.SCAN_FREQ(20),.SCENE_ENABLE(1)) panel(
  .clk(clk),.rst_n(!rst),.mode(2'd0),.scene_enable(en),.scene_warn(warn),.scene_stage(stage),
  .state_code(state),.debug_word(debug_bus[16*debug_page+:16]),.combo_event_count(8'd0),.combo_debug_active(1'b0),
  .auto_play_indicator(1'b1),.seg_sel(sel),.seg_data(seg),.debug_page(debug_page));
 adjust_osd_overlay #(.SCENE_ENABLE(1)) osd(.clk(clk),.rst(rst),.vs(vs),.de(de),.pixel_x(x),.rgb_in(24'h204060),
  .mode(2'd0),.selected(2'd0),.brightness(8'd128),.contrast(8'd128),.volume_level(4'd10),
  .scene_enable(en),.scene_speed(speed),.rgb_out(rgb),.active());
 function [7:0] stage_digit(input integer n);
  case(n)0:stage_digit=8'hf9;1:stage_digit=8'ha4;2:stage_digit=8'hb0;3:stage_digit=8'h99;endcase
 endfunction
 task display_check(input reg [7:0] expected);
  begin repeat(100)begin @(negedge clk);if(sel==6'b011111)begin if(seg!==expected)$fatal(1,"panel %h expected %h",seg,expected);digits++;end end end
 endtask
 task frame;
  begin
   @(negedge clk);vs=0;de=0;repeat(40)@(negedge clk);vs=1;
   for(integer yy=0;yy<55;yy++)begin
    for(integer xx=0;xx<320;xx++)begin
     @(negedge clk);de=1;x=xx;#1;
     if(en && yy==32 && xx>=8 && xx<152)begin
      if(xx>=120 && xx<136 && osd.character!==(speed==0?"1":speed==1?"2":"4"))$fatal(1,"speed character");
      if(osd.active && rgb!==24'hffff00)$fatal(1,"speed highlight");pixels++;
     end
     if(!en && rgb!==24'h204060)$fatal(1,"scene exit bypass");
    end
    @(negedge clk);de=0;
   end
  end
 endtask
 initial begin
  repeat(5)@(negedge clk);rst=0;
  for(integer s=0;s<4;s++)begin stage=s;speed=s%3;repeat(2)@(negedge clk);display_check(stage_digit(s));frame();end
  warn=1;repeat(2)@(negedge clk);display_check(8'h88);
  state=15;repeat(2)@(negedge clk);display_check(8'h8e);
  state=1;en=0;repeat(2)@(negedge clk);display_check(8'h79);frame();
  $display("PASS M5 UI: %0d physical segment samples, stages 1..4/A/error priority/legacy auto point, %0d speed text pixels at 1X/2X/4X, scene exit",digits,pixels);$finish;
 end
 initial begin #3000000;$fatal(1,"UI watchdog");end
endmodule
