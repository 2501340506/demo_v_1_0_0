`timescale 1ns/1ps
// Pin-level card: observes MOSI commands and drives MISO on falling SCLK.
// No FPGA reset input: card idle/application-command state survives host reset.
module sd_spi_card(input cs,sclk,mosi,input present,bad_crc,reject_crc_enable,ready_between_polls,output reg miso=1);
    reg [7:0] rx=0, packet[0:5], response[0:1023];
    integer bit_count=0, packet_count=0, rp=0,wp=0,commands=0,reads=0;
    integer idle_clocks=0,attempts=0,k;
    reg idle=1,app=0,crc_enabled=0;
    integer crc_enables=0;
    // Independent polynomial division over all 47 command/CRC bits.
    function automatic crc7_valid(input [47:0] frame);
        reg [46:0] remainder;
        integer bit_index;
        begin
            remainder=frame[47:1];
            for(bit_index=46;bit_index>=7;bit_index=bit_index-1)
                if(remainder[bit_index]) remainder=remainder ^ (47'h89 << (bit_index-7));
            crc7_valid=(remainder[6:0]==0 && frame[0]);
        end
    endfunction
    reg [7:0] value;
    task push(input [7:0] b); begin response[wp]=b;wp=wp+1;end endtask
    always @(posedge cs) begin
        bit_count=0;packet_count=0;rp=0;wp=0;miso=1;
    end
    always @(negedge sclk) begin
        if(!cs && present && rp<wp) miso=response[rp][7-bit_count];
        else miso=1;
    end
    always @(posedge sclk) begin
        if(cs) begin
            if(mosi) idle_clocks=idle_clocks+1;
        end else begin
            rx={rx[6:0],mosi};
            if(bit_count==7) begin
                bit_count=0;
                if(rp<wp) rp=rp+1;
                if(present) begin
                    if(packet_count!=0 || rx[7:6]==2'b01) begin
                        packet[packet_count]=rx;
                        if(packet_count==5) begin
                            packet_count=0;commands=commands+1;
                            if(!crc7_valid({packet[0],packet[1],packet[2],packet[3],packet[4],packet[5]}))
                                $fatal(1,"invalid command CRC7 on wire");
                            $display("CARD command=%0d arg=%h%h%h%h crc=%h",packet[0]&63,packet[1],packet[2],packet[3],packet[4],packet[5]);
                            push(255);
                            case(packet[0]&63)
                                0:begin
                                    if(packet[5]!=8'h95) $fatal(1,"CMD0 packet CRC");
                                    idle=1;app=0;attempts=0;crc_enabled=0;push(1);
                                end
                                8:begin
                                    if(packet[5]!=8'h87 || packet[4]!=8'haa) $fatal(1,"CMD8 packet");
                                    push(idle?1:0);push(0);push(0);push(1);push(8'haa);
                                end
                                55:begin app=1;push(idle?1:0);end
                                41:begin
                                    if(!app) $fatal(1,"ACMD41 without CMD55");
                                    app=0;attempts=attempts+1;
                                    if(attempts>=2) idle=0;
                                    push(idle?1:0);
                                    // Initialization can finish after returning idle,
                                    // before the host sends its next CMD55.
                                    if(ready_between_polls) idle=0;
                                end
                                16:begin
                                    if(idle) $fatal(1,"CMD16 before ready");
                                    if({packet[1],packet[2],packet[3],packet[4]}!=512) $fatal(1,"CMD16 block size");
                                    push(0);
                                end
                                17:begin
                                    if(idle) $fatal(1,"CMD17 before ready");
                                    if(!crc_enabled) $fatal(1,"CMD17 before CRC enabled");
                                    reads=reads+1;push(0);push(255);push(8'hfe);
                                    for(k=0;k<512;k=k+1) push((k*37+11)&255);
                                    push(8'hd5);push(bad_crc?8'h95:8'h94);
                                end
                                59:begin
                                    if(idle || {packet[1],packet[2],packet[3],packet[4]}!=1)
                                        $fatal(1,"CMD59 state/argument");
                                    if(reject_crc_enable) push(4);
                                    else begin crc_enabled=1;crc_enables=crc_enables+1;push(0);end
                                end
                                default: $fatal(1,"unexpected wire command %h",packet[0]);
                            endcase
                        end else packet_count=packet_count+1;
                    end
                end
            end else bit_count=bit_count+1;
        end
    end
endmodule

module tb_sd_spi_pins;
    parameter real OUT_DELAY = 0.0;
    parameter real MISO_DELAY = 0.0;
    reg clk=0,rst=1,read_req=0,present=1,bad_crc=0,reject_crc_enable=0;
    reg ready_between_polls=0;
    reg [31:0] read_addr=0;
    wire cs,sclk,mosi,miso,done,init_failed,failed,ending,dv;
    wire [7:0] data;
    wire [63:0] sd_debug;
    integer bytes=0,successes=0,errors=0;
    always #5 clk=~clk;
    sd_card_top #(.INIT_TIMEOUT_MS(50),.RESPONSE_TIMEOUT_MS(2),.TOKEN_TIMEOUT_MS(5)) dut(
        .clk(clk),.rst(rst),.SD_nCS(cs),.SD_DCLK(sclk),.SD_MOSI(mosi),.SD_MISO(miso),
        .sd_debug(sd_debug),.sd_init_done(done),.sd_init_failed(init_failed),.sd_sec_read_failed(failed),
        .sd_sec_read(read_req),.sd_sec_read_addr(read_addr),.sd_sec_read_data(data),
        .sd_sec_read_data_valid(dv),.sd_sec_read_end(ending),
        .sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),.sd_sec_write_data(8'd0),
        .sd_sec_write_data_req(),.sd_sec_write_end());
    wire card_cs,card_clk,card_mosi,card_miso;
    assign #(OUT_DELAY) card_cs=cs;
    assign #(OUT_DELAY) card_clk=sclk;
    assign #(OUT_DELAY) card_mosi=mosi;
    assign #(MISO_DELAY) miso=card_miso;
    sd_spi_card card(card_cs,card_clk,card_mosi,present,bad_crc,reject_crc_enable,ready_between_polls,card_miso);
    realtime last_card_mosi=-1e9,last_card_cs=-1e9,last_card_sample=-1e9;
    always @(card_mosi) begin
        if(!rst && !card_cs && $realtime-last_card_sample<5.0) $fatal(1,"card MOSI hold");
        last_card_mosi=$realtime;
    end
    always @(card_cs) begin
        if(!rst && $realtime-last_card_sample<5.0) $fatal(1,"card CS hold");
        last_card_cs=$realtime;
    end
    always @(posedge card_clk) if(!rst && !card_cs) begin
        if($realtime-last_card_mosi<5.0 || $realtime-last_card_cs<5.0) $fatal(1,"card input setup");
        last_card_sample=$realtime;
    end
    always @(posedge clk) if(!rst) begin
        if(dv) begin
            if(data!==((bytes*37+11)&255)) $fatal(1,"wire data mismatch byte=%0d got=%h",bytes,data);
            bytes=bytes+1;
        end
        if(ending) successes=successes+1;
        if(failed) errors=errors+1;
        if(init_failed && !reject_crc_enable) $fatal(1,"valid card initialization timed out; commands=%0d diagnostic=%h ACMD41 attempts=%0d",card.commands,sd_debug,card.attempts);
        if(done && !card.crc_enabled) $fatal(1,"init_done before CMD59 completed");
    end
    task read_sector;
        @(negedge clk);read_req=1;repeat(4)@(negedge clk);read_req=0;
        wait(ending || failed);repeat(4)@(negedge clk);
    endtask
    initial begin
        repeat(5)@(negedge clk);rst=0;
        wait(done);
        if(card.idle_clocks<80) $fatal(1,"idle clocks");
        read_sector();
        if(sd_debug[15:0]!==16'h1100) $fatal(1,"wire CMD17 R1 diagnostic: %h",sd_debug);
        if(successes!=1 || errors!=0 || bytes!=512) $fatal(1,"valid sector rejected successes=%0d errors=%0d bytes=%0d",successes,errors,bytes);
        if(sd_debug!==64'h0200d594d5941100) $fatal(1,"good CRC snapshot %h",sd_debug);
        read_addr=32'h12345;bad_crc=1;read_sector();
        if(successes!=1 || errors!=1) $fatal(1,"CRC error not rejected");
        if(sd_debug!==64'h2200d594d5951100) $fatal(1,"bad CRC snapshot %h",sd_debug);
        read_addr=32'h80000f;bad_crc=0;read_sector();
        if(successes!=2 || sd_debug!==64'h2200d594d5951100)
            $fatal(1,"first failure snapshot overwritten by a later transaction");
        bad_crc=0;rst=1;repeat(5)@(negedge clk);rst=0;
        wait(done);read_sector();
        if(successes!=3 || errors!=1 || card.reads!=4) $fatal(1,"host-only reset recovery");
        if(card.crc_enables!=2) $fatal(1,"CRC not reenabled after host reset");
        reject_crc_enable=1;rst=1;repeat(5)@(negedge clk);rst=0;
        wait(init_failed);repeat(5)@(negedge clk);
        if(done || !cs || sd_debug[15:0]!==16'h3b04) $fatal(1,"CMD59 rejection not reported");
        rst=1;reject_crc_enable=0;repeat(5)@(negedge clk);rst=0;
        wait(done);read_sector();
        if(successes!=4 || errors!=1 || card.crc_enables!=3) $fatal(1,"CMD59 failure recovery");
        ready_between_polls=1;rst=1;repeat(5)@(negedge clk);rst=0;
        wait(done);read_sector();
        if(successes!=5 || card.attempts!=2) $fatal(1,"CMD55 ready response recovery");
        $display("PASS initialization completes between ACMD41 polls: CMD55 R1=00 accepted");
        $display("PASS pin-level CRC7, CMD59 readiness/failure/retry, good/bad CRC16 and host-only reset");$finish;
    end
    initial begin #90000000;$fatal(1,"pin test watchdog");end
endmodule
