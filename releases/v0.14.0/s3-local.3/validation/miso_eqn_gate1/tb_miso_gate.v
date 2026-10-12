`timescale 1ns/1ps
module tb_miso_gate;
reg miso=0;
wire [1:0] result;
EG_PHY_LSLICE #(
    //.LUTF0("(B*~(~D*~A*~(0*~C)))"),
    //.LUTF1(":D"),
    //.LUTG0("(B*~(~D*~A*~(1*~C)))"),
    //.LUTG1(":D"),
    .CEMUX("CE"),
    .CLKMUX("CLK"),
    .DFFMODE("FF"),
    .INIT_LUTF0(16'b1100110010001000),
    .INIT_LUTF1(16'b1111111100000000),
    .INIT_LUTG0(16'b1100110010001100),
    .INIT_LUTG1(16'b1111111100000000),
    .LSFMUX0("FUNC5"),
    .LSFMUX1("FUNC5"),
    .MODE("LOGIC"),
    .REG0_REGSET("RESET"),
    .REG0_SD("MI"),
    .REG1_REGSET("RESET"),
    .REG1_SD("MI"),
    .SRMODE("ASYNC"),
    .SRMUX("SR")) dut(.a({1'b0,1'b0}),.b({1'b0,1'b0}),.c({1'b0,1'b0}),.ce({1'b0}),.clk({1'b0}),.d({miso,1'b0}),.e({1'b0,1'b0}),.mi({1'b0,1'b0}),.sr({1'b0}),.f(result),.q());
initial begin
 #1000;
 repeat(4)begin
  miso=0;#10;if(result[1]!==miso)$fatal(1,"MISO low mismatch");
  miso=1;#10;if(result[1]!==miso)$fatal(1,"MISO high mismatch");
 end
 $display("PASS routed MISO identity 0/1");$finish;
end
endmodule
