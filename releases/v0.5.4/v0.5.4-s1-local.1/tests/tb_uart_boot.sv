`timescale 1ns/1ps
module tb_uart_boot;
reg clk=0, rst=1;
always #5 clk=~clk;
wire tx;
uart_boot_reporter dut(.clk(clk),.rst(rst),.uart_tx(tx));
string expected="BOOT v0.5.4-s1-local.1\r\n";
integer received=0;

// Independent line receiver: no DUT state/counter/handshake access.
// Inspect each bit throughout its 8680 ns interval, including stop/start.
task receive_byte(input byte value);
    reg [9:0] serial_frame;
    integer b, sample;
    begin
        serial_frame={1'b1,value,1'b0};
        @(negedge tx);
        #1;
        for(b=0;b<10;b=b+1) begin
            for(sample=0;sample<868;sample=sample+1) begin
                if(tx !== serial_frame[b])
                    $fatal(1,"UART data/timing byte=%02x bit=%0d sample=%0d",value,b,sample);
                #10;
            end
        end
        received=received+1;
    end
endtask
task receive_line;
    integer i;
    begin
        for(i=0;i<expected.len();i=i+1) receive_byte(expected[i]);
    end
endtask
task quiet_line;
    integer i;
    begin
        for(i=0;i<250000;i=i+1) begin
            #10;
            if(tx !== 1'b1) $fatal(1,"Unexpected repeated banner or non-idle TX");
        end
    end
endtask
initial begin
    #37;
    if(tx !== 1) $fatal(1,"TX not idle in reset");
    rst=0;
    receive_line();
    quiet_line();
    // Reset while idle must re-arm exactly one complete line.
    rst=1; #23; rst=0;
    receive_line();
    // Abort a third transmission mid-byte, then receive from B again.
    rst=1; #23; rst=0;
    @(negedge tx); #1234;
    rst=1; #1;
    if(tx !== 1) $fatal(1,"Asynchronous reset did not release TX");
    #22; rst=0;
    receive_line();
    quiet_line();
    $display("PASS tb_uart_boot: 72 bytes, 868 clocks/bit, 8N1, one-shot, idle and mid-byte reset");
    $finish;
end
initial begin #15000000; $fatal(1,"UART receiver timeout"); end
endmodule
