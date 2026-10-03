`timescale 1ns/1ps
module tb_media_display_control;
 reg clk=0,rst=1,combo_request=0,sd_init_done=0,scan_done=0,display_valid=0,load_busy=0;
 reg write_started_seen=0,source_done_now=0,write_finish_now=0;
 reg auto_play_en=0;
 wire auto_play_indicator, diag_indicator;
 reg [1:0] img_idx=0;
 reg [3:0] bmp_state_code=0;
 wire [3:0] state_code,diag;
 wire [7:0] combo_event_count;
 wire combo_debug_active;
 media_display_control #(.CLK_FREQ_HZ(4)) dut(.*);
 media_display_control #(.CLK_FREQ_HZ(4),.DIAG_DISPLAY(1)) diagnostic(
 .clk(clk),.rst(rst),.combo_request(combo_request),.sd_init_done(sd_init_done),
 .scan_done(scan_done),.display_valid(display_valid),.load_busy(load_busy),
 .write_started_seen(write_started_seen),.source_done_now(source_done_now),
 .write_finish_now(write_finish_now),.img_idx(img_idx),.bmp_state_code(bmp_state_code),
 .state_code(diag),.combo_event_count(),.combo_debug_active(),
 .auto_play_en(auto_play_en),.auto_play_indicator(diag_indicator));
 always #5 clk=~clk;
 task step; begin @(posedge clk); #1; @(negedge clk); end endtask
 task check(input bit ok,input string msg); if(!ok) $fatal(1,"%s",msg); endtask
 integer i;
 initial begin
 step; check(state_code==0 && diag==0 && combo_event_count==0 && !combo_debug_active && auto_play_indicator===0 && diag_indicator===0,"reset");
 rst=0; bmp_state_code=6; step; check(state_code==6 && diag==0,"source status");
 sd_init_done=1; step; check(diag==1,"scan status");
 scan_done=1; step; check(diag==3,"no image");
 auto_play_en=1; step; check(auto_play_indicator===0,"no valid image must keep dot off");
 load_busy=1; step; check(diag==4,"write not started");
 write_started_seen=1; step; check(diag==6,"source pending");
 source_done_now=1; step; check(diag==7,"write pending");
 write_finish_now=1; step; check(diag==5,"commit pending");
 load_busy=0; display_valid=1;
 for(i=0;i<4;i=i+1) begin img_idx=i; step; check(state_code==i+1 && diag==8,"image number"); end
 check(auto_play_indicator===1 && diag_indicator===0,"normal autoplay dot, no diagnostic dot");
 load_busy=1; step; check(auto_play_indicator===1,"loading does not change enabled mode");
 load_busy=0; auto_play_en=0; step; check(auto_play_indicator===0 && state_code==4,"manual dot off preserves number");
 auto_play_en=1;
 combo_request=1; step; combo_request=0; check(combo_debug_active && combo_event_count==1,"combo start");
 check(auto_play_indicator===1,"combo does not hide autoplay mode");
 repeat(3) step; check(combo_debug_active,"hold full duration");
 step; check(!combo_debug_active && state_code==4,"restore image");
 combo_request=1; step; combo_request=0; repeat(2) step;
 combo_request=1; step; combo_request=0; repeat(3) step; check(combo_debug_active,"retrigger hold");
 step; check(!combo_debug_active && combo_event_count==3,"retrigger count");
 combo_request=1; repeat(260) step; combo_request=0; check(combo_event_count==255,"saturation");
 rst=1; #1; check(!combo_debug_active && combo_event_count==0 && state_code==0 && auto_play_indicator===0,"async reset during hint");
 $display("PASS display states, combo duration/retrigger/saturation/reset and autoplay indicator"); $finish;
 end
 initial begin #10000; $fatal(1,"timeout"); end
endmodule
