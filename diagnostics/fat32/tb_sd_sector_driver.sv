`timescale 1ns/1ps
// Real SD protocol/controller, with a card model at the SPI-byte boundary.
module tb_sd_sector_driver;
    reg clk=0;always #5 clk=~clk;
    reg rst=1,request=0,spi_ack=0;
    reg [7:0] spi_rx=255;
    wire busy,done,valid,raw_request,raw_valid,raw_end,raw_failed,init_done;
    wire [7:0] byte_data,raw_data,error_code;
    wire [8:0] byte_index;
    wire [31:0] address;
    integer gap=0,cmd17_count=0,scenario=0,received=0;
    sd_sector_adapter #(.CLK_FREQ_HZ(1000),.TIMEOUT_MS(500)) adapter (
        .clk(clk),.rst(rst),.sector_req(request),.sector_lba(32'd2048),
        .sector_busy(busy),.sector_valid(valid),.sector_byte(byte_data),
        .sector_byte_index(byte_index),.sector_done(done),.sector_error(error_code),
        .sd_sec_read(raw_request),.sd_sec_read_addr(address),
        .sd_sec_read_data_valid(raw_valid),.sd_sec_read_data(raw_data),
        .sd_sec_read_end(raw_end),.sd_sec_read_failed(raw_failed)
    );
    sd_card_top #(.CLK_FREQ_HZ(1000),.SPI_LOW_SPEED_DIV(0)) card (
        .clk(clk),.rst(rst),.SD_nCS(),.SD_DCLK(),.SD_MOSI(),.SD_MISO(1'b1),
        .sd_debug(),.sd_init_done(init_done),.sd_init_failed(),.sd_sec_read_failed(raw_failed),
        .sd_sec_read(raw_request),.sd_sec_read_addr(address),.sd_sec_read_data(raw_data),
        .sd_sec_read_data_valid(raw_valid),.sd_sec_read_end(raw_end),
        .sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),.sd_sec_write_data(8'd0),
        .sd_sec_write_data_req(),.sd_sec_write_end()
    );
    always @(negedge clk) begin
        spi_ack=0;
        if(gap>0) gap=gap-1;
        else if(card.spi_wr_req && !card.protocol_rst) begin
            gap=3;spi_ack=1;spi_rx=255;
            if(card.sd_card_cmd_m0.state==card.sd_card_cmd_m0.S_CMD) begin
                if(card.sd_card_cmd_m0.byte_cnt==0 && card.cmd[45:40]==17)
                    cmd17_count=cmd17_count+1;
                if(card.sd_card_cmd_m0.byte_cnt>=6)
                    case(card.cmd[45:40])
                        0,8,55:spi_rx=1;
                        41,16,59:spi_rx=0;
                        17:spi_rx=scenario==0 ? 4 : 0;
                        default:spi_rx=255;
                    endcase
            end
            if(card.sd_card_cmd_m0.state==card.sd_card_cmd_m0.S_READ_WAIT) spi_rx=8'hfe;
            if(card.sd_card_cmd_m0.state==card.sd_card_cmd_m0.S_READ)
                spi_rx=(scenario==2 && card.sd_card_cmd_m0.byte_cnt==513) ? 1 : 0;
        end
    end
    always @(posedge clk) if(valid) begin
        if(byte_data!==0 || byte_index!==9'(received)) $fatal(1,"real driver byte/index");
        received=received+1;
    end
    task read_once(input integer kind);
        integer before_count;
        begin
            scenario=kind;received=0;before_count=cmd17_count;
            @(negedge clk);request=1;@(negedge clk);request=0;
            wait(done);#1;
            if(error_code!==(kind==1 ? 8'h00 : 8'h10)) $fatal(1,"driver error forwarding %h",error_code);
            if(received!=(kind==0 ? 0 : 512)) $fatal(1,"driver byte count");
            repeat(100) @(negedge clk);
            if(cmd17_count!=before_count+1 || busy || raw_request)
                $fatal(1,"duplicate CMD17 after completion/failure: before=%0d after=%0d",before_count,cmd17_count);
        end
    endtask
    initial begin
        force card.spi_wr_ack=spi_ack;force card.spi_data_out=spi_rx;
        repeat(4) @(negedge clk);rst=0;
        wait(init_done);
        read_once(0);$display("PASS driver CMD17 rejection completes without duplicate read");
        read_once(1);$display("PASS driver full sector after failure, including CRC/end");
        read_once(2);$display("PASS driver CRC failure after all pixels does not report success");
        read_once(1);$display("PASS driver explicit retry succeeds without duplicate read");
        $display("PASS sector real driver all scenarios");$finish;
    end
    initial begin #500000;$fatal(1,"driver test watchdog");end
endmodule
