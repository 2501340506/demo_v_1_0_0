`timescale 1ns/1ps
module tb_switch_mode_panel;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1;
    reg [1:0] switches = 0;
    wire [1:0] mode;
    reg [3:0] state_code = 4;
    reg auto_play = 0;
    reg combo = 0;
    wire [5:0] sel;
    wire [7:0] data;
    switch_mode_control #(.CLK_FREQ_HZ(1000), .DEBOUNCE_MS(20)) control (
        .clk(clk), .rst(rst), .switches(switches), .mode(mode)
    );
    seg7_panel #(.CLK_FREQ(1200), .SCAN_FREQ(100)) panel (
        .clk(clk), .rst_n(!rst), .mode(mode), .state_code(state_code),
        .sd_debug(64'h2200d594d5951100),.combo_event_count(8'd2), .combo_debug_active(combo),
        .auto_play_indicator(auto_play), .seg_sel(sel), .seg_data(data)
    );
    task tick(input integer count);
        repeat (count) begin @(posedge clk); #1; end
    endtask
    task set_switches(input [1:0] value);
        @(negedge clk); switches = value;
    endtask
    task expect_mode(input [1:0] value);
        if (mode !== value) $fatal(1, "mode expected %d got %d", value, mode);
    endtask
    task expect_digit(input [5:0] digit, input [7:0] expected);
        integer found;
        begin
            found = 0;
            repeat (16) begin
                tick(1);
                if (sel == digit) begin
                    found = 1;
                    if (data !== expected) $fatal(1, "digit %b expected %h got %h", digit, expected, data);
                end
            end
            if (!found) $fatal(1, "digit was not scanned");
        end
    endtask
    initial begin
        tick(3); @(negedge clk); rst = 0;
        tick(25); expect_mode(0);
        expect_digit(6'b101111, 8'hc0);
        expect_digit(6'b011111, 8'h99);
        set_switches(1); tick(12); expect_mode(0);
        set_switches(0); tick(4);
        set_switches(1); tick(21); expect_mode(0);
        tick(3); expect_mode(1);
        expect_digit(6'b101111, 8'hf9);
        set_switches(2); tick(24); expect_mode(2);
        expect_digit(6'b101111, 8'ha4);
        // A transient intermediate word must not publish when moving to 11.
        set_switches(0); tick(5); expect_mode(2);
        set_switches(3); tick(21); expect_mode(2);
        tick(3); expect_mode(3);
        expect_digit(6'b101111, 8'hb0);
        @(negedge clk); auto_play = 1;
        expect_digit(6'b011111, 8'h19);
        expect_digit(6'b101111, 8'hb0);
        // Stage 1 keeps legacy combo count on digit 5; digit 4 stays the mode.
        @(negedge clk); combo = 1;
        expect_digit(6'b011111, 8'ha4);
        expect_digit(6'b101111, 8'hb0);
        @(negedge clk); combo = 0; rst = 1;
        tick(2); expect_mode(0);
        if (sel !== 6'b111111) $fatal(1, "reset must blank digit selects");
        @(negedge clk); rst = 0;
        tick(24); expect_mode(3);
        set_switches(0); tick(24); expect_mode(0);
        expect_digit(6'b101111, 8'hc0);
        expect_digit(6'b111110, 8'hff);
        expect_digit(6'b111101, 8'hff);
        expect_digit(6'b111011, 8'hff);
        expect_digit(6'b110111, 8'hff);
        @(negedge clk); state_code=4'hf; auto_play=0;
        expect_digit(6'b111110, 8'hf9); // CMD17 = hex 11
        expect_digit(6'b111101, 8'hf9);
        expect_digit(6'b111011, 8'hc0); // R1 = 00
        expect_digit(6'b110111, 8'hc0);
        expect_digit(6'b101111, 8'hc0);
        expect_digit(6'b011111, 8'h8e);
        tick(2400);
        expect_digit(6'b101111, 8'hf9); // received CRC page 1
        expect_digit(6'b111110, 8'ha1); // d
        expect_digit(6'b111101, 8'h92); // 5
        expect_digit(6'b111011, 8'h90); // 9
        expect_digit(6'b110111, 8'h92); // 5
        tick(2400);
        expect_digit(6'b101111, 8'ha4); // calculated CRC page 2
        expect_digit(6'b110111, 8'h99); // 4
        tick(2400);
        expect_digit(6'b101111, 8'hb0); // error summary page 3
        expect_digit(6'b111110, 8'ha4);
        expect_digit(6'b111101, 8'ha4);
        $display("PASS SD failure panel shows command/R1/mode/F as 11000F");
        $display("PASS switch modes, debounce, reset, panel mapping and legacy indicator");
        $finish;
    end
    initial begin #200000; $fatal(1, "timeout"); end
endmodule
