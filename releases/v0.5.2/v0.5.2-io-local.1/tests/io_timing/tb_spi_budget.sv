`timescale 1ns/1ps
module tb_spi_budget;
    parameter integer DIV = 1;
    parameter integer NEGATIVE = 0;
    parameter integer FAST = 0;
    reg clk=0, rst=1, req=0, cs_ctrl=1;
    reg [7:0] tx=0;
    reg [15:0] divider=DIV;
    wire cs,sclk,mosi,ack;
    wire [7:0] rx;
    always #5 clk=~clk;
    // Independent external channel: clock-to-pad, PCB, card tCO, input path.
    // Worst slow path includes 0.2 ns setup/uncertainty reserve at capture.
    localparam real OUT = FAST ? 0.0 : 5.0;
    localparam real PCB = FAST ? 0.0 : 1.0;
    localparam real TCO = FAST ? 0.0 : (NEGATIVE ? 25.0 : 14.0);
    localparam real INPATH = FAST ? 0.0 : 4.2;
    wire card_clk,card_cs,card_mosi,miso;
    reg card_bit=1;
    assign #(OUT+PCB) card_clk=sclk;
    assign #(OUT+PCB) card_cs=cs;
    assign #(OUT+PCB) card_mosi=mosi;
    assign #(PCB+INPATH) miso=card_bit;
    spi_master dut(clk,rst,cs,sclk,mosi,miso,1'b1,1'b1,cs_ctrl,divider,req,ack,tx,rx);
    reg [7:0] expected=0, observed=0;
    integer bit_index=0, samples=0, transfers=0;
    realtime last_mosi=-1e9,last_cs=-1e9,last_sample=-1e9,last_miso=-1e9;
    always @(card_mosi) begin
        if(!card_cs && !rst && $realtime-last_sample<5.0) $fatal(1,"MOSI hold");
        last_mosi=$realtime;
    end
    always @(card_cs) begin
        if(!rst && $realtime-last_sample<5.0) $fatal(1,"CS hold");
        last_cs=$realtime;
    end
    always @(miso) last_miso=$realtime;
    always @(negedge card_clk) if(!card_cs && !rst) begin
        card_bit <= #(TCO) expected[7-bit_index];
    end
    always @(posedge card_clk) if(!card_cs && !rst) begin
        if($realtime-last_mosi<5.0 || $realtime-last_cs<5.0) $fatal(1,"card setup");
        observed={observed[6:0],card_mosi};
        last_sample=$realtime;
        bit_index=(bit_index+1)%8;
        samples=samples+1;
    end
    // Capture in this CE design is at the system edge generating SCLK rise.
    always @(posedge clk) if(!rst && !cs && dut.state==1 && dut.clk_edge_cnt[0]) begin
        if(!FAST && $realtime-last_miso<0.2) $fatal(1,"MISO setup reserve");
    end
    task transfer(input [7:0] value,input [7:0] returned);
        begin
            @(negedge clk);tx=value;expected=returned;observed=0;req=1;
            wait(ack);@(negedge clk);req=0;
            if(rx!==returned || observed!==value) $fatal(1,"byte mismatch div=%0d tx=%h observed=%h rx=%h expected=%h",DIV,value,observed,rx,returned);
            wait(!ack);repeat(4)@(negedge clk);transfers=transfers+1;
        end
    endtask
    initial begin
        repeat(5)@(negedge clk);rst=0;
        repeat(5)@(negedge clk);cs_ctrl=0;
        repeat(5)@(negedge clk);
        transfer(8'ha5,8'h96); transfer(8'h3c,8'h69);
        transfer(8'h00,8'hff); transfer(8'hff,8'h00);
        repeat(5)@(negedge clk);cs_ctrl=1;
        repeat(5)@(negedge clk);
        if(samples!=32 || bit_index!=0) $fatal(1,"edge/byte count");
        $display("PASS SPI budget DIV=%0d FAST=%0d bytes=%0d samples=%0d",DIV,FAST,transfers,samples);$finish;
    end
    initial begin #1000000;$fatal(1,"watchdog");end
endmodule
