// UI transaction boundary. SW3 is level debounced, keys are active low.
// Backend owns resource scanning/restoration and acknowledges exit only once
// its display descriptor has actually committed at a frame boundary.
module disaster_menu_control #(parameter CLK_FREQ_HZ=100000000)(
 input clk,rst,sw3,key1,key2,key4,input [1:0] switch_mode,
 input safe_idle,backend_ready,exit_done,input [3:0] scene_valid,
 output reg pending,active,enter,confirm,cancel,
 output reg [1:0] focus,output blocked,
 output reg [1:0] effective_mode
);
 wire [1:0] sw;
 switch_mode_control #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) switch_filter(
  .clk(clk),.rst(rst),.switches({1'b0,sw3}),.mode(sw));
 wire p1,p2,p4,s1,s2,s4;
 key_press_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) k1(clk,rst,key1,p1,s1);
 key_press_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) k2(clk,rst,key2,p2,s2);
 key_press_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) k4(clk,rst,key4,p4,s4);
 reg sw_q,armed,exiting,fullscreen_override;
 reg [1:0] saved_switch,saved_page,override_page;
 assign blocked=pending || active || exiting || !armed;
 // Page identity crosses into cache arbitration only through this register.
 // Exit is still blocked until the backend commits and the keys are released.
 always @(posedge clk or posedge rst)begin
  if(rst)effective_mode<=0;
  else effective_mode<=fullscreen_override?override_page:(pending || active)?saved_page:switch_mode;
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   sw_q<=0;armed<=0;exiting<=0;fullscreen_override<=0;saved_switch<=0;saved_page<=0;override_page<=0;
   pending<=0;active<=0;enter<=0;confirm<=0;cancel<=0;focus<=0;
  end else begin
   sw_q<=sw[0];enter<=0;confirm<=0;cancel<=0;
   if(fullscreen_override && !pending && !active && !exiting && switch_mode!=saved_switch)fullscreen_override<=0;
   if(!armed && !pending && !active && !exiting && key1 && key2 && key4 && s1 && s2 && s4)armed<=1;
   if(sw[0] && !sw_q)begin pending<=1;armed<=0;saved_page<=effective_mode;end
   if(pending)begin
    if(!sw[0])pending<=0;
    else if(safe_idle)begin pending<=0;active<=1;enter<=1;focus<=0;armed<=0;end
   end
   if(active && !exiting)begin
    if(!armed && key1 && key2 && key4 && s1 && s2 && s4)armed<=1;
    if(!sw[0])begin cancel<=1;exiting<=1;armed<=0;fullscreen_override<=1;override_page<=saved_page;end
    else if(armed)begin
     if(p1)focus<=focus-1'b1;
     else if(p2)focus<=focus+1'b1;
     else if(p4 && backend_ready && scene_valid[focus])begin
      confirm<=1;exiting<=1;armed<=0;
      fullscreen_override<=1;override_page<=0;saved_switch<=switch_mode;
     end
    end
   end
   if(exiting && exit_done)begin active<=0;exiting<=0;armed<=0;saved_switch<=switch_mode;end
  end
 end
endmodule
