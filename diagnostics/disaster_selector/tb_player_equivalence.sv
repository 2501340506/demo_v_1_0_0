`timescale 1ns/1ps
module tb_player_equivalence;
 reg clk=0,rst=1;always #5 clk=~clk;
 reg  enable=0;
 reg  scan_done=0;
 reg  display_valid=0;
 reg  load_busy=0;
 reg  pause=0;
 reg  first_image_committed=0;
 reg  manual_activity=0;
 reg  request_accept=0;
 reg [2:0] image_count=0;
 reg [1:0] current_image=0;
 reg [1:0] mode=0;
 reg  next_event=0;
 reg  previous_event=0;
 reg  auto_toggle_event=0;
genvar g;generate for(g=0;g<4;g=g+1)begin:pair
 wire  auto_play_en[0:1];
 wire  next_pending[0:1];
 wire  previous_pending[0:1];
 wire  auto_tick[0:1];
 wire  load_request[0:1];
 wire  next_load_request[0:1];
 wire  previous_load_request[0:1];
 wire  auto_load_request[0:1];
 wire [1:0] target_image[0:1];
media_player_control #(.AUTO_PLAY_CYCLES(11),.UI_GATE(g%2),.PAUSE_ENABLE(g/2)) dut(.clk(clk),.rst(rst),.enable(enable),.scan_done(scan_done),.display_valid(display_valid),.load_busy(load_busy),.pause(pause),.first_image_committed(first_image_committed),.manual_activity(manual_activity),.request_accept(request_accept),.image_count(image_count),.current_image(current_image),.mode(mode),.next_event(next_event),.previous_event(previous_event),.auto_toggle_event(auto_toggle_event),.auto_play_en(auto_play_en[0]),.next_pending(next_pending[0]),.previous_pending(previous_pending[0]),.auto_tick(auto_tick[0]),.load_request(load_request[0]),.next_load_request(next_load_request[0]),.previous_load_request(previous_load_request[0]),.auto_load_request(auto_load_request[0]),.target_image(target_image[0]));
media_player_control_reference #(.AUTO_PLAY_CYCLES(11),.UI_GATE(g%2),.PAUSE_ENABLE(g/2)) ref_dut(.clk(clk),.rst(rst),.enable(enable),.scan_done(scan_done),.display_valid(display_valid),.load_busy(load_busy),.pause(pause),.first_image_committed(first_image_committed),.manual_activity(manual_activity),.request_accept(request_accept),.image_count(image_count),.current_image(current_image),.mode(mode),.next_event(next_event),.previous_event(previous_event),.auto_toggle_event(auto_toggle_event),.auto_play_en(auto_play_en[1]),.next_pending(next_pending[1]),.previous_pending(previous_pending[1]),.auto_tick(auto_tick[1]),.load_request(load_request[1]),.next_load_request(next_load_request[1]),.previous_load_request(previous_load_request[1]),.auto_load_request(auto_load_request[1]),.target_image(target_image[1]));
always @(negedge clk)if(!rst)begin
 if(auto_play_en[0]!==auto_play_en[1])$fatal(1,"config=%d auto_play_en",g);
 if(next_pending[0]!==next_pending[1])$fatal(1,"config=%d next_pending",g);
 if(previous_pending[0]!==previous_pending[1])$fatal(1,"config=%d previous_pending",g);
 if(auto_tick[0]!==auto_tick[1])$fatal(1,"config=%d auto_tick",g);
 if(load_request[0]!==load_request[1])$fatal(1,"config=%d load_request",g);
 if(next_load_request[0]!==next_load_request[1])$fatal(1,"config=%d next_load_request",g);
 if(previous_load_request[0]!==previous_load_request[1])$fatal(1,"config=%d previous_load_request",g);
 if(auto_load_request[0]!==auto_load_request[1])$fatal(1,"config=%d auto_load_request",g);
 if(target_image[0]!==target_image[1])$fatal(1,"config=%d target_image",g);
 if(dut.auto_count!==ref_dut.auto_count)$fatal(1,"config=%d auto_count",g);
 if(dut.mode_seen!==ref_dut.mode_seen)$fatal(1,"config=%d mode_seen",g);
end
end endgenerate
integer i;integer seed=32'h131499;initial begin
repeat(3)@(negedge clk);rst=0;
for(i=0;i<200000;i=i+1)begin
@(negedge clk);#1;
 enable=$random(seed);
 scan_done=$random(seed);
 display_valid=$random(seed);
 load_busy=$random(seed);
 pause=$random(seed);
 first_image_committed=$random(seed);
 manual_activity=$random(seed);
 request_accept=$random(seed);
 image_count=$random(seed);
 current_image=$random(seed);
 mode=$random(seed);
 next_event=$random(seed);
 previous_event=$random(seed);
 auto_toggle_event=$random(seed);
rst=(i%997==996);
end
// Directed steady AUTO intervals and navigation acceptance.
rst=1;@(negedge clk);#1;rst=0;enable=1;scan_done=1;display_valid=1;load_busy=0;pause=0;first_image_committed=1;manual_activity=0;image_count=4;current_image=0;mode=0;next_event=0;previous_event=0;auto_toggle_event=1;request_accept=1;
@(negedge clk);#1;auto_toggle_event=0;repeat(100)@(negedge clk);
#1;next_event=1;@(negedge clk);#1;next_event=0;repeat(20)@(negedge clk);
$display("PASS player equivalence 200000 cycles x four UI/PAUSE configurations plus AUTO expiry");$finish;end
endmodule
