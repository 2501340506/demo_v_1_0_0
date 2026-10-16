// Three independent active-low keys. Mode gates new picture events only.
module mode_key_control #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer RESCAN_HOLD_MS = 2000,
    parameter integer PREVIEW_ENABLE = 0,
    parameter integer SCENE_ENABLE = 0,
    parameter integer PUBLICITY_ENABLE = 0
)(
    input wire clk, rst, enable,
    input wire key1, key2, key4,
    input wire [1:0] mode,
    output wire next_event,output reg rescan_event,
    output wire previous_event,
    output reg auto_toggle_event,
    output wire adjust_decrease,adjust_increase,adjust_restore,adjust_select,
    output wire manual_activity,
    input scene_allowed,output wire scene_mode,scene_next,scene_warn,scene_speed,
    input scene_active,application_busy,
    output wire application_toggle
);
    wire press1, press2, press4;
    wire stable1, stable2, stable4;
    key_press_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) u_key1 (
        .clk(clk), .rst(rst), .button_in(key1),
        .press_pulse(press1), .button_stable_out(stable1)
    );
    key_press_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) u_key2 (
        .clk(clk), .rst(rst), .button_in(key2),
        .press_pulse(press2), .button_stable_out(stable2)
    );
    key_press_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) u_key4 (
        .clk(clk), .rst(rst), .button_in(key4),
        .press_pulse(press4), .button_stable_out(stable4)
    );
    // Capture the mode at the debounced press edge, even if mode changes on
    // that same clock. Holding a key across a mode change never creates a press.
    reg [1:0] press_mode;
    always @(posedge clk or posedge rst) begin
        if (rst) press_mode <= 0;
        else press_mode <= mode;
    end
    reg playback_armed;
    always @(posedge clk or posedge rst)begin
     if(rst)playback_armed<=0;
     else if(press_mode!=mode || application_busy)playback_armed<=0;
     else if(stable1 && stable2 && stable4)playback_armed<=1;
    end
    assign previous_event = !scene_mode && enable && (!PUBLICITY_ENABLE || playback_armed) && (press_mode == 0 || (PREVIEW_ENABLE && press_mode == 3)) && press_mode==mode && press1;
    reg next_raw;
    assign next_event=next_raw && !scene_mode;
    assign scene_next=next_raw && scene_mode;
    reg warn_event;
    assign scene_warn=SCENE_ENABLE && warn_event;
    localparam integer HOLD_CYCLES = (CLK_FREQ_HZ / 1000) * RESCAN_HOLD_MS;
    localparam integer HOLD_BITS = $clog2(HOLD_CYCLES + 1);
    reg [HOLD_BITS-1:0] held_cycles;
    reg stable2_d, long_fired, short_allowed, rescan_allowed;
    reg [1:0] short_mode;
    // Track KEY2 independently of media readiness. Only release re-arms it.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            short_mode<=0; stable2_d <= 1; held_cycles <= 0; long_fired <= 0;
            rescan_allowed <= 0; short_allowed <= 0; next_raw <= 0; rescan_event <= 0;
        end else begin
            stable2_d <= stable2;
            next_raw <= 0; rescan_event <= 0;
            if (stable2_d && !stable2) begin
                short_allowed <= enable && (!PUBLICITY_ENABLE || playback_armed) && (mode == 0 || (PREVIEW_ENABLE && mode == 3));
                short_mode<=mode; rescan_allowed <= (mode==0 || mode==3) && (!PUBLICITY_ENABLE || (!application_busy && playback_armed));
                held_cycles <= 1;
            end else if (!stable2) begin
                if (!enable || mode != short_mode) short_allowed <= 0;
                if(mode!=short_mode || (PUBLICITY_ENABLE && application_busy))rescan_allowed<=0;
                if (!long_fired && rescan_allowed && mode==short_mode) begin
                    if (held_cycles >= HOLD_CYCLES - 1) begin
                        rescan_event <= 1;
                        long_fired <= 1;
                        short_allowed <= 0;
                    end else held_cycles <= held_cycles + 1'b1;
                end
            end else begin
                if (!stable2_d && !long_fired && short_allowed && enable && mode == short_mode)
                    next_raw <= 1;
                held_cycles <= 0; long_fired <= 0; short_allowed <= 0;
            end
        end
    end
    adjust_key_gestures #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) adjust_keys(
        .clk(clk),.rst(rst || (PUBLICITY_ENABLE && application_busy)),.mode(mode),.stable1(stable1),.stable2(stable2),.stable4(stable4),
        .decrease(adjust_decrease),.increase(adjust_increase),.restore(adjust_restore),.select_next(adjust_select));
    // Register the media toggle to break mode -> preview -> cache request logic.
    generate if(PUBLICITY_ENABLE)begin:g_publicity
     reg application_event;
     assign application_toggle=application_event;
     reg tracking4,long4,s4q,tracking1,long1,s1q;
     reg [$clog2(CLK_FREQ_HZ+1)-1:0] hold4,hold1;
     reg speed_event;
     assign scene_mode=scene_active;
     assign scene_speed=speed_event;
     always @(posedge clk or posedge rst)begin
      if(rst)begin
       tracking4<=0;long4<=0;s4q<=1;tracking1<=0;long1<=0;s1q<=1;
       hold4<=0;hold1<=0;application_event<=0;auto_toggle_event<=0;warn_event<=0;speed_event<=0;
      end else begin
       s4q<=stable4;s1q<=stable1;application_event<=0;auto_toggle_event<=0;warn_event<=0;speed_event<=0;
       if(!enable || !playback_armed || press_mode!=mode || rescan_event)begin
        tracking4<=0;tracking1<=0;hold4<=0;hold1<=0;
       end else begin
        if(mode==0)begin
         if(s4q && !stable4)begin tracking4<=1;hold4<=1;long4<=0;end
         else if(!stable4 && tracking4 && !long4)begin
          if(hold4>=CLK_FREQ_HZ-1)begin long4<=1;application_event<=1;end
          else hold4<=hold4+1'b1;
         end else if(stable4 && tracking4)begin
          if(!long4)auto_toggle_event<=1;
          tracking4<=0;
         end
         if(scene_active)begin
          if(s1q && !stable1)begin tracking1<=1;hold1<=1;long1<=0;end
          else if(!stable1 && tracking1 && !long1)begin
           if(hold1>=CLK_FREQ_HZ-1)begin long1<=1;speed_event<=1;end
           else hold1<=hold1+1'b1;
          end else if(stable1 && tracking1)begin
           if(!long1)warn_event<=1;
           tracking1<=0;
          end
         end
        end else begin
         tracking4<=0;tracking1<=0;
         if(mode==3 && press4)auto_toggle_event<=1;
        end
       end
      end
     end
    end else if(SCENE_ENABLE==0)begin:g_legacy
    assign application_toggle=0;
    assign scene_mode=0;assign scene_speed=0;
    always @(posedge clk or posedge rst)warn_event<=0;
    always @(posedge clk or posedge rst)
        if(rst)auto_toggle_event<=0;
        else auto_toggle_event<=enable && press4 && press_mode==mode && (mode==0 || mode==3);
    end else begin:g_scene
     assign application_toggle=0;
     reg active,armed,tracking,long4,s4q;
     reg s1q,tracking1,long1;
     reg [$clog2(CLK_FREQ_HZ+1)-1:0] hold1;
     reg [$clog2(CLK_FREQ_HZ+1)-1:0] hold4;
     reg speed_event;
     assign scene_mode=active;
     assign scene_speed=speed_event;
     always @(posedge clk or posedge rst)begin
      if(rst)begin active<=0;armed<=0;tracking<=0;long4<=0;s4q<=1;hold4<=0;
       speed_event<=0;auto_toggle_event<=0;warn_event<=0;s1q<=1;tracking1<=0;long1<=0;hold1<=0;end
      else begin
       s4q<=stable4;s1q<=stable1;speed_event<=0;auto_toggle_event<=0;warn_event<=0;
       if(!active || !enable || mode!=0 || press_mode!=mode || rescan_event)begin tracking1<=0;hold1<=0;end
       else if(s1q && !stable1)begin tracking1<=1;hold1<=1;long1<=0;end
       else if(!stable1 && tracking1 && !long1)begin
        if(hold1>=CLK_FREQ_HZ-1)begin speed_event<=1;long1<=1;end
        else hold1<=hold1+1'b1;
       end else if(stable1 && tracking1)begin
        if(!long1)warn_event<=1;
        tracking1<=0;hold1<=0;
       end
       if(mode!=0 || !scene_allowed)active<=0;
       if(press_mode!=mode || rescan_event)begin armed<=0;tracking<=0;end
       else if(stable4 && !tracking)armed<=1;
       if(mode==0 && armed && enable)begin
        if(s4q && !stable4)begin tracking<=1;hold4<=1;long4<=0;end
        else if(!stable4 && tracking && !long4)begin
         if(hold4>=CLK_FREQ_HZ-1)begin
          long4<=1;if(scene_allowed)active<=!active;
         end else hold4<=hold4+1'b1;
        end else if(stable4 && tracking)begin
         if(!long4)auto_toggle_event<=1;
         tracking<=0;hold4<=0;
        end
       end else begin
        tracking<=0;hold4<=0;
        if(mode==3 && enable && press4 && press_mode==mode)auto_toggle_event<=1;
       end
      end
     end
    end endgenerate
    assign manual_activity = enable &&
        (!stable1 || !stable2 || !stable4 || press1 || press2 || press4);
endmodule

// All inputs are already debounced. Wait for release after mode changes.
module adjust_key_gestures #(parameter CLK_FREQ_HZ=100_000_000)(
 input clk,rst,input [1:0] mode,input stable1,stable2,stable4,
 output reg decrease,increase,restore,select_next
);
 localparam WINDOW=CLK_FREQ_HZ/10;
 localparam LONG=CLK_FREQ_HZ;
 reg [1:0] mode_q,state;
 reg armed,s1_q,s2_q,s4_q,key4_active;
 reg [$clog2(WINDOW+1)-1:0] count;
 reg [$clog2(LONG+1)-1:0] hold4;
 wire p1=s1_q && !stable1,p2=s2_q && !stable2;
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   mode_q<=0;state<=0;armed<=0;s1_q<=1;s2_q<=1;s4_q<=1;
   key4_active<=0;count<=0;hold4<=0;
   decrease<=0;increase<=0;restore<=0;select_next<=0;
  end else begin
   mode_q<=mode;s1_q<=stable1;s2_q<=stable2;s4_q<=stable4;
   decrease<=0;increase<=0;restore<=0;select_next<=0;
   if(mode!=mode_q || !(mode==1 || mode==2))begin
    armed<=0;state<=0;count<=0;key4_active<=0;hold4<=0;
   end else if(!armed)begin
    if(stable1 && stable2 && stable4)armed<=1;
   end else begin
    case(state)
     0:begin
      count<=0;
      if(p1 && p2)begin restore<=1;state<=3;end
      else if(p1)begin state<=1;count<=1;end
      else if(p2)begin state<=2;count<=1;end
     end
     1,2:begin
      if((state==1 && p2) || (state==2 && p1))begin restore<=1;state<=3;end
      else if(count>=WINDOW-1 || (state==1 && stable1) || (state==2 && stable2))begin
       decrease<=state==1;increase<=state==2;state<=3;
      end else count<=count+1'b1;
     end
     3:if(stable1 && stable2)state<=0;
    endcase
    if(s4_q && !stable4)begin key4_active<=1;hold4<=1;end
    else if(!stable4 && key4_active)begin if(hold4<LONG)hold4<=hold4+1'b1;end
    else if(stable4 && key4_active)begin
     if(hold4<LONG && state==0 && stable1 && stable2)select_next<=1;
     key4_active<=0;hold4<=0;
    end
   end
  end
 end
endmodule
