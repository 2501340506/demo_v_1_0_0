`timescale 1ns/1ps
module tb_mode_key_equivalence;
reg clk=0,rst=1,enable=1,key1=1,key2=1,key4=1,scene=1,busy=0;
reg [1:0] mode=0;
always #5 clk=~clk;
genvar g;
generate for(g=0;g<6;g=g+1)begin:pair
localparam integer FREQ=g/2==0?1000:g/2==1?2000:100000000;
wire [14:0] actual,expected;
mode_key_control #(.CLK_FREQ_HZ(FREQ),.PREVIEW_ENABLE(g%2),.SCENE_ENABLE(1),.PUBLICITY_ENABLE(1)) dut(
.clk(clk),
.rst(rst),
.enable(enable),
.key1(key1),
.key2(key2),
.key4(key4),
.mode(mode),
.scene_active(scene),
.scene_allowed(1'b1),
.application_busy(busy),
.next_event(actual[0]),
.rescan_event(actual[1]),
.previous_event(actual[2]),
.auto_toggle_event(actual[3]),
.adjust_decrease(actual[4]),
.adjust_increase(actual[5]),
.adjust_restore(actual[6]),
.adjust_select(actual[7]),
.manual_activity(actual[8]),
.scene_mode(actual[9]),
.scene_next(actual[10]),
.scene_warn(actual[11]),
.scene_speed(actual[12]),
.application_toggle(actual[13]));
mode_key_control_reference #(.CLK_FREQ_HZ(FREQ),.PREVIEW_ENABLE(g%2),.SCENE_ENABLE(1),.PUBLICITY_ENABLE(1)) ref_dut(
.clk(clk),
.rst(rst),
.enable(enable),
.key1(key1),
.key2(key2),
.key4(key4),
.mode(mode),
.scene_active(scene),
.scene_allowed(1'b1),
.application_busy(busy),
.next_event(expected[0]),
.rescan_event(expected[1]),
.previous_event(expected[2]),
.auto_toggle_event(expected[3]),
.adjust_decrease(expected[4]),
.adjust_increase(expected[5]),
.adjust_restore(expected[6]),
.adjust_select(expected[7]),
.manual_activity(expected[8]),
.scene_mode(expected[9]),
.scene_next(expected[10]),
.scene_warn(expected[11]),
.scene_speed(expected[12]),
.application_toggle(expected[13]));
assign actual[14]=0;assign expected[14]=0;
always @(negedge clk)if(!rst)begin
if(actual!==expected)$fatal(1,"config %d output mismatch %h %h",g,actual,expected);
if(dut.g_publicity.hold1!==ref_dut.g_publicity.hold1 || dut.g_publicity.hold4!==ref_dut.g_publicity.hold4)$fatal(1,"config %d counter mismatch",g);
end
end endgenerate
integer i,j,seed=32'h178123;
task cycles(input integer n);repeat(n)@(negedge clk);#1;endtask
initial begin
cycles(4);rst=0;cycles(45);
key4=0;cycles(4100);key4=1;cycles(45);
key1=0;cycles(4100);key1=1;cycles(45);
key2=0;cycles(4100);key2=1;cycles(45);
for(i=0;i<350;i=i+1)begin
cycles(1);key1=$random(seed);key2=$random(seed);key4=$random(seed);
mode=$random(seed);enable=$random(seed);scene=$random(seed);busy=$random(seed);
cycles(40+($unsigned($random(seed))%3000));
if(i%31==30)begin rst=1;cycles(2);rst=0;end
end
// Exercise the production-width carry and long-press boundary without simulating a full second.
rst=1;cycles(2);rst=0;mode=0;scene=1;enable=1;busy=0;key1=1;key2=1;key4=1;cycles(45);
force pair[4].dut.stable1=0;force pair[4].ref_dut.stable1=0;
force pair[4].dut.stable4=0;force pair[4].ref_dut.stable4=0;
cycles(3);
pair[4].dut.g_publicity.hold1=65534;pair[4].ref_dut.g_publicity.hold1=65534;
pair[4].dut.g_publicity.hold4=65534;pair[4].ref_dut.g_publicity.hold4=65534;
cycles(5);
pair[4].dut.g_publicity.hold1=99999997;pair[4].ref_dut.g_publicity.hold1=99999997;
pair[4].dut.g_publicity.hold4=99999997;pair[4].ref_dut.g_publicity.hold4=99999997;
cycles(10);
release pair[4].dut.stable1;release pair[4].ref_dut.stable1;
release pair[4].dut.stable4;release pair[4].ref_dut.stable4;
cycles(45);
$display("PASS mode key equivalence: all outputs/counters, 6 frequency/preview configurations, long/short, busy/mode/reset, production carry/expiry");$finish;
end
endmodule
