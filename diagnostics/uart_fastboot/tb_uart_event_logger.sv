`timescale 1ns/1ps
module tb_uart_event_logger;
reg clk=0,rst=1; always #5 clk=~clk;
reg [15:0] events=0; reg [1:0] image=0; reg [31:0] sector=32'h12345678;
reg [2:0] error=0; reg [3:0] phase=2; reg auto_en=0; reg [63:0] debug=64'h1122334455667788;
wire tx;
uart_event_logger #(.CLK_FREQ_HZ(100000),.BAUD_RATE(10000),.QUEUE_DEPTH(2)) dut(
 .clk(clk),.rst(rst),.events(events),.image_index(image),.sector(sector),.error_code(error),
 .phase(phase),.auto_enabled(auto_en),.sd_debug(debug),.uart_tx(tx));
string lines[0:31], line="";
integer n=0,b;
reg [7:0] rx;
reg cr=0;
// Independent 8N1 receiver: numeric CR/LF, no access to formatter registers.
initial forever begin
    @(negedge tx);
    if(!rst) begin
        #50;
        if(tx!==0) $fatal(1,"bad start");
        for(b=0;b<8;b=b+1) begin #100; rx[b]=tx; end
        #100;
        if(tx!==1) $fatal(1,"bad stop");
        if(rx==8'h0d) cr=1;
        else if(rx==8'h0a) begin
            if(!cr) $fatal(1,"LF without numeric CR");
            lines[n]=line; n=n+1; line=""; cr=0;
        end else begin
            if(cr || rx<32 || rx>126) $fatal(1,"non-ASCII/embedded NUL byte %02x",rx);
            line={line,rx};
        end
    end
end
task check(input integer idx,input string name,input string suffix);
    begin
        if(lines[idx].len()!=67 || lines[idx].substr(0,9)!=name || lines[idx].substr(21,66)!=suffix)
            $fatal(1,"Unexpected line %0d: [%s]",idx,lines[idx]);
    end
endtask
initial begin
    #27 rst=0;
    repeat(201) @(negedge clk);
    events=16'h0001;
    @(negedge clk); events=16'h0120; image=2; error=2; phase=3; auto_en=1;
    @(negedge clk); events=16'h0080; sector=32'h99999999;
    @(negedge clk); events=16'h0080;
    @(negedge clk); events=0;
    // Mutate context while the first record is still serializing.
    repeat(3) @(negedge clk); debug=0; image=0; error=0;
    wait(n==5);
    if(lines[0]!="BOOT v0.5.4-s3-local.1") $fatal(1,"banner [%s]",lines[0]);
    check(1,"INIT_OK   "," I=0 S=12345678 E=0 P=2 A=0 D=0000000000000000");
    check(2,"RETRY     "," I=2 S=12345678 E=2 P=3 A=1 D=1122334455667788");
    check(3,"ERROR     "," I=2 S=12345678 E=2 P=3 A=1 D=1122334455667788");
    check(4,"DROP      "," I=0 S=00000002 E=0 P=0 A=0 D=0000000000000000");
    if(lines[1].substr(13,20)!="00000002" || lines[2].substr(13,20)!="00000002")
        $fatal(1,"enqueue timestamp mismatch");
    repeat(30) @(negedge clk);
    sector=32'h87654321; image=3; error=0; phase=7; auto_en=0; events=16'h0080;
    @(negedge clk); events=0;
    wait(n==6);
    check(5,"COMMIT    "," I=3 S=87654321 E=0 P=7 A=0 D=0000000000000000");
    repeat(1000) @(negedge clk);
    if(n!=6 || tx!==1) $fatal(1,"repeat/idle failure");
    $display("PASS tb_uart_event_logger: exact wire bytes, CR/LF, timestamp, simultaneous events, immutable context, DROP=2, recovery after overflow");
    $finish;
end
initial begin #1000000; $fatal(1,"logger timeout"); end
endmodule
