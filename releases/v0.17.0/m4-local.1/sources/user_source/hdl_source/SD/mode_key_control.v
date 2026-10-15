// Three independent active-low keys. Mode gates new picture events only.
module mode_key_control #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer RESCAN_HOLD_MS = 2000,
    parameter integer PREVIEW_ENABLE = 0,
    parameter integer SCENE_ENABLE = 0
)(
    input wire clk, rst, enable,
    input wire key1, key2, key4,
    input wire [1:0] mode,
    output wire next_event,output reg rescan_event,
    output wire previous_event,
    output reg auto_toggle_event,
    output wire adjust_decrease,adjust_increase,adjust_restore,adjust_select,
    output wire manual_activity,
    input scene_allowed,output wire scene_mode,scene_next,scene_warn,scene_speed
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
    assign previous_event = !scene_mode && enable && (press_mode == 0 || (PREVIEW_ENABLE && press_mode == 3)) && press_mode==mode && press1;
    reg next_raw;
    assign next_event=next_raw && !scene_mode;
    assign scene_next=next_raw && scene_mode;
    assign scene_warn=scene_mode && enable && press_mode==mode && press1;
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
                short_allowed <= enable && (mode == 0 || (PREVIEW_ENABLE && mode == 3));
                short_mode<=mode; rescan_allowed <= (mode==0 || mode==3);
                held_cycles <= 1;
            end else if (!stable2) begin
                if (!enable || mode != short_mode) short_allowed <= 0;
                if(mode!=short_mode)rescan_allowed<=0;
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
        .clk(clk),.rst(rst),.mode(mode),.stable1(stable1),.stable2(stable2),.stable4(stable4),
        .decrease(adjust_decrease),.increase(adjust_increase),.restore(adjust_restore),.select_next(adjust_select));
    // Register the media toggle to break mode -> preview -> cache request logic.
    generate if(SCENE_ENABLE==0)begin:g_legacy
    assign scene_mode=0;assign scene_speed=0;
    always @(posedge clk or posedge rst)
        if(rst)auto_toggle_event<=0;
        else auto_toggle_event<=enable && press4 && press_mode==mode && (mode==0 || mode==3);
    end else begin:g_scene
     reg active,armed,tracking,long4,s4q;
     reg [$clog2(CLK_FREQ_HZ+1)-1:0] hold4;
     reg speed_event;
     assign scene_mode=active;
     assign scene_speed=speed_event;
     always @(posedge clk or posedge rst)begin
      if(rst)begin active<=0;armed<=0;tracking<=0;long4<=0;s4q<=1;hold4<=0;
       speed_event<=0;auto_toggle_event<=0;end
      else begin
       s4q<=stable4;speed_event<=0;auto_toggle_event<=0;
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
         if(!long4)begin if(active)speed_event<=1;else auto_toggle_event<=1;end
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
