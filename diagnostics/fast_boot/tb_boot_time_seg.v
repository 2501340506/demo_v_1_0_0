`timescale 1ns/1ps
// CLK_FREQ=10000 -> 1 ms = 10 clocks. Load at 123 ms, frame at 1234 ms.
module tb_boot_time_seg;
    reg clk = 0, rst_n = 0, valid = 0; reg [3:0] st = 4'd2;
    wire [5:0] sel; wire [7:0] dat;
    boot_time_seg #(.CLK_FREQ(10000)) dut(.clk(clk), .rst_n(rst_n), .state_code(st),
        .display_valid(valid), .seg_sel(sel), .seg_data(dat));
    always #5 clk = ~clk;
    initial begin
        #20 rst_n = 1;
        #(123*100) st = 4'd3;
        #(5*100) st = 4'd1;
        #((1234-128)*100) valid = 1;
        #(300*100);
        if (dut.load_bcd !== 16'h0123 && dut.load_bcd !== 16'h0122) begin $display("FAIL load %h", dut.load_bcd); $finish; end
        if (dut.frame_bcd !== 16'h1234 && dut.frame_bcd !== 16'h1233) begin $display("FAIL frame %h", dut.frame_bcd); $finish; end
        if (dut.now_bcd !== dut.frame_bcd) begin $display("FAIL counter kept running %h", dut.now_bcd); $finish; end
        valid = 0; #100; dut.now_bcd = 16'h9998; dut.frame_seen = 0; #(30*100);
        if (dut.now_bcd !== 16'h9999) begin $display("FAIL saturate %h", dut.now_bcd); $finish; end
        $display("PASS tb_boot_time_seg load=%h frame=%h", dut.load_bcd, dut.frame_bcd);
        $finish;
    end
endmodule
