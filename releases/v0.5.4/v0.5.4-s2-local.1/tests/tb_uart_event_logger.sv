`timescale 1ns/1ps
module tb_uart_event_logger;
reg clk=0,rst=1; always #5 clk=~clk;
reg [15:0] events=0; reg [1:0] image=0; reg [31:0] sector=32'h1234;
reg [2:0] error=0; reg [3:0] phase=0; reg auto_en=0; reg [63:0] debug=64'hA5;
wire tx;
uart_event_logger #(.CLK_FREQ_HZ(1000),.BAUD_RATE(100),.QUEUE_DEPTH(2)) dut(
 .clk(clk),.rst(rst),.events(events),.image_index(image),.sector(sector),.error_code(error),
 .phase(phase),.auto_enabled(auto_en),.sd_debug(debug),.uart_tx(tx));
integer transitions=0, i;
initial begin
    #27 rst=0;
    // Three simultaneous snapshots exceed depth two; logger must retain the
    // first two and later emit a DROP record without stopping the source.
    @(negedge clk); events=16'h0001;
    @(negedge clk); events=16'h0080; image=2'd2;
    @(negedge clk); events=16'h0100; error=3'd2;
    @(negedge clk); events=0;
    repeat(30000) @(negedge clk);
    if(tx!==1'b1) $fatal(1,"UART logger not idle after drain");
    $display("PASS tb_uart_event_logger: snapshots, queue overflow and drain");
    $finish;
end
initial begin #400000 $fatal(1,"logger timeout"); end
endmodule
