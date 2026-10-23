// Parameter state in the SD control domain, driven only by the SW4 panel (v0.27;
// the SW1/SW2 adjust modes are gone, mode and selected are kept for the ports).
// Panel items: 0 bright, 1 contrast, 2 volume, 3 wave, 4 height, 5 wash,
// 6 OSD, 7 scroll, 8 fade, 9 reset all. focus 0 moves the cursor, 1 edits.
module media_adjust_control(
 input clk,rst,input [1:0] mode,
 input decrease,increase,restore,select_next,
 output reg [7:0] brightness,contrast,
 output reg [4:0] volume_level,output reg [1:0] selected,
 input panel,hold_select,
 output reg focus,output reg [3:0] item,
 output reg wave_on,output reg [1:0] wave_height,wash_level,
 output reg osd_on,scroll_on,fade_on
);
 reg panel_q;
 function [7:0] step;
  input [7:0] value;input up;
  begin step=up ? (value>239?8'd255:value+8'd16) : (value<16?8'd0:value-8'd16);end
 endfunction
 function [1:0] level;
  input [1:0] value;input up;
  begin level=up ? (value==3?2'd3:value+2'd1) : (value==0?2'd0:value-2'd1);end
 endfunction
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   brightness<=128;contrast<=128;volume_level<=10;selected<=0;
   panel_q<=0;focus<=0;item<=0;
   wave_on<=1;wave_height<=3;wash_level<=2;osd_on<=1;scroll_on<=1;fade_on<=1;
  end else begin
   panel_q<=panel;
   if(panel!=panel_q)focus<=0;
   else if(panel)begin
    if(hold_select && item==9)begin
     brightness<=128;contrast<=128;volume_level<=10;
     wave_on<=1;wave_height<=3;wash_level<=2;osd_on<=1;scroll_on<=1;fade_on<=1;
    end else if(select_next)focus<=!focus;
    else if(restore)begin
     case(item)
      0:brightness<=128; 1:contrast<=128; 2:volume_level<=10;
      3:wave_on<=1; 4:wave_height<=3; 5:wash_level<=2;
      6:osd_on<=1; 7:scroll_on<=1; 8:fade_on<=1;
     endcase
    end else if(!focus)begin
     if(increase)item<=item==9?4'd0:item+4'd1;
     else if(decrease)item<=item==0?4'd9:item-4'd1;
    end else if(decrease || increase)begin
     case(item)
      0:brightness<=step(brightness,increase);
      1:contrast<=step(contrast,increase);
      2:if(increase && volume_level<20)volume_level<=volume_level+1'b1;
        else if(decrease && volume_level>0)volume_level<=volume_level-1'b1;
      3:wave_on<=increase;
      4:wave_height<=level(wave_height,increase);
      5:wash_level<=level(wash_level,increase);
      6:osd_on<=increase;
      7:scroll_on<=increase;
      8:fade_on<=increase;
     endcase
    end
   end
  end
 end
endmodule

// v0.27 panel keys: own debounce and gestures, armed only while the panel
// owns the keys (the main key path sees them released meanwhile).
module adjust_panel_keys #(parameter integer CLK_FREQ_HZ=100_000_000)(
 input clk,rst,active,key1,key2,key4,
 output decrease,increase,restore,select_next,hold_select
);
 localparam integer MS_CYCLES=CLK_FREQ_HZ/1000;
 localparam integer MS_BITS=MS_CYCLES>1?$clog2(MS_CYCLES):1;
 localparam integer TICK_ADJ=MS_CYCLES>1?1:0;
 reg [MS_BITS-1:0] ms_count;
 wire ms_tick=MS_CYCLES<=1 || ms_count==MS_CYCLES-1;
 always @(posedge clk or posedge rst)
  if(rst)ms_count<=0;
  else if(ms_tick)ms_count<=0;
  else ms_count<=ms_count+1'b1;
 wire s1,s2,s4;
 key_ms_debounce k1(.clk(clk),.rst(rst),.ms_tick(ms_tick),.button_in(key1),.press_pulse(),.button_stable_out(s1));
 key_ms_debounce k2(.clk(clk),.rst(rst),.ms_tick(ms_tick),.button_in(key2),.press_pulse(),.button_stable_out(s2));
 key_ms_debounce k4(.clk(clk),.rst(rst),.ms_tick(ms_tick),.button_in(key4),.press_pulse(),.button_stable_out(s4));
 adjust_key_gestures #(.TICK_ADJ(TICK_ADJ)) gestures(.clk(clk),.rst(rst),.ms_tick(ms_tick),
  .mode(active?2'd1:2'd0),.stable1(s1),.stable2(s2),.stable4(s4),
  .decrease(decrease),.increase(increase),.restore(restore),.select_next(select_next),.hold_select(hold_select));
endmodule
