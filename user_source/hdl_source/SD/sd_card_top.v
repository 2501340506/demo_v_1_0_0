
module sd_card_top
#(
	parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer INIT_TIMEOUT_MS = 2000,
    parameter integer INIT_RETRIES = 3,
    parameter integer RESPONSE_TIMEOUT_MS = 100,
    parameter integer TOKEN_TIMEOUT_MS = 250,
	parameter  SPI_LOW_SPEED_DIV = 248,         // SD card low speed mode frequency division parameter,spi clk speed = clk speed /((SPI_LOW_SPEED_DIV + 2) * 2 )
	parameter  SPI_HIGH_SPEED_DIV = 1           // 16.667 MHz at 100 MHz; see IO_TIMING.md
)
(
	input            clk,
	input            rst,
	output           SD_nCS,                    //SD card chip select (SPI mode)
	output           SD_DCLK,                   //SD card clock
	output           SD_MOSI,                   //SD card controller data output
	input            SD_MISO,                   //SD card controller data input
	output sd_init_failed, sd_sec_read_failed,
    output reg [63:0] sd_debug,
	output           sd_init_done,              //SD card initialization is complete
	input            sd_sec_read,               //SD card sector read
	input[31:0]      sd_sec_read_addr,          //SD card sector read address
	output[7:0]      sd_sec_read_data,          //SD card sector read data
	output           sd_sec_read_data_valid,    //SD card sector read data valid
	output           sd_sec_read_end,           //SD card sector read end
	input            sd_sec_write,              //SD card sector write
	input[31:0]      sd_sec_write_addr,         //SD card sector write address
	input[7:0]       sd_sec_write_data,         //SD card sector write data
	output           sd_sec_write_data_req,     //SD card sector write data next clock is valid
	output           sd_sec_write_end           //SD card sector write end
);
wire block_read_error;
wire sd_init_recovery;
wire protocol_rst = rst || sd_init_failed || sd_init_recovery;
wire[15:0]           spi_clk_div;               //SPI module clock division parameter
wire                 cmd_req;                   //SD card command request
wire                 cmd_req_ack;               //SD card command request response
wire                 cmd_req_error;             //SD card command request error
wire[47:0]           cmd;                       //SD card command
wire[7:0]            cmd_r1;                    //SD card expect response
wire[15:0]           cmd_data_len;              //SD card command read data length
wire                 block_read_req;            //SD card sector data read request
wire                 block_read_valid;          //SD card sector data read data valid
wire[7:0]            block_read_data;           //SD card sector data read data
wire                 block_read_req_ack;        //SD card sector data read response
wire                 block_write_req;           //SD card sector data write request
wire[7:0]            block_write_data;          //SD card sector data write data next clock is valid
wire                 block_write_data_rd;       //SD card sector data write data
wire                 block_write_req_ack;       //SD card sector data write response

wire                 nCS_ctrl;                  //SPI module chip select control
wire                 spi_wr_req;                //SPI module data sending request
wire                 spi_wr_ack;                //SPI module data request response
wire[7:0]            spi_data_in;               //SPI module send data
wire[7:0]            spi_data_out;              //SPI module data returned
wire[15:0]           clk_div;
wire [7:0] cmd_response;
wire [47:0] read_debug;
reg debug_failure_seen;
// Retain the result when protocol_rst stops SPI after an init failure.
always @(posedge clk or posedge rst) begin
    if(rst) begin sd_debug <= 64'h000000000000ffff; debug_failure_seen <= 0; end
    else if(!debug_failure_seen) begin
        if(sd_init_failed || sd_sec_read_failed) debug_failure_seen <= 1;
        if(cmd_req || cmd_req_ack) sd_debug[15:0] <= {2'b00, cmd[45:40], cmd_response};
        if(!sd_init_failed) sd_debug[63:16] <= read_debug;
    end
end
sd_card_sec_read_write
#(
	.CLK_FREQ_HZ(CLK_FREQ_HZ), .INIT_TIMEOUT_MS(INIT_TIMEOUT_MS), .INIT_RETRIES(INIT_RETRIES),
	.SPI_LOW_SPEED_DIV(SPI_LOW_SPEED_DIV),
	.SPI_HIGH_SPEED_DIV(SPI_HIGH_SPEED_DIV)
)
sd_card_sec_read_write_m0(
	.clk                            (clk                    ),
	.rst                            (rst                    ),
	.sd_init_failed(sd_init_failed), .sd_init_recovery(sd_init_recovery), .sd_sec_read_failed(sd_sec_read_failed),
    .block_read_error(block_read_error),
	.sd_init_done                   (sd_init_done           ),
	.sd_sec_read                    (sd_sec_read            ),
	.sd_sec_read_addr               (sd_sec_read_addr       ),
	.sd_sec_read_data               (sd_sec_read_data       ),
	.sd_sec_read_data_valid         (sd_sec_read_data_valid ),
	.sd_sec_read_end                (sd_sec_read_end        ),
	.sd_sec_write                   (sd_sec_write           ),
	.sd_sec_write_addr              (sd_sec_write_addr      ),
	.sd_sec_write_data              (sd_sec_write_data      ),
	.sd_sec_write_data_req          (sd_sec_write_data_req  ),
	.sd_sec_write_end               (sd_sec_write_end       ),
	.spi_clk_div                    (spi_clk_div            ),
	.cmd_req                        (cmd_req                ),
	.cmd_req_ack                    (cmd_req_ack            ),
	.cmd_req_error                  (cmd_req_error          ),
	.cmd                            (cmd                    ),
	.cmd_r1                         (cmd_r1                 ),
	.cmd_data_len                   (cmd_data_len           ),
	.block_read_req                 (block_read_req         ),
	.block_read_valid               (block_read_valid       ),
	.block_read_data                (block_read_data        ),
	.block_read_req_ack             (block_read_req_ack     ),
	.block_write_req                (block_write_req        ),
	.block_write_data               (block_write_data       ),
	.block_write_data_rd            (block_write_data_rd    ),
	.block_write_req_ack            (block_write_req_ack    )
);

sd_card_cmd #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .RESPONSE_TIMEOUT_MS(RESPONSE_TIMEOUT_MS),
    .TOKEN_TIMEOUT_MS(TOKEN_TIMEOUT_MS)) sd_card_cmd_m0(
    .cmd_response(cmd_response),
    .read_debug(read_debug),
    .block_read_error(block_read_error),
	.sys_clk                        (clk                    ),
	.rst                            (protocol_rst           ),
	.spi_clk_div                    (spi_clk_div            ),
	.cmd_req                        (cmd_req                ),
	.cmd_req_ack                    (cmd_req_ack            ),
	.cmd_req_error                  (cmd_req_error          ),
	.cmd                            (cmd                    ),
	.cmd_r1                         (cmd_r1                 ),
	.cmd_data_len                   (cmd_data_len           ),
	.block_read_req                 (block_read_req         ),
	.block_read_req_ack             (block_read_req_ack     ),
	.block_read_data                (block_read_data        ),
	.block_read_valid               (block_read_valid       ),
	.block_write_req                (block_write_req        ),
	.block_write_data               (block_write_data       ),
	.block_write_data_rd            (block_write_data_rd    ),
	.block_write_req_ack            (block_write_req_ack    ),
	.nCS_ctrl                       (nCS_ctrl               ),
	.clk_div                        (clk_div                ),
	.spi_wr_req                     (spi_wr_req             ),
	.spi_wr_ack                     (spi_wr_ack             ),
	.spi_data_in                    (spi_data_in            ),
	.spi_data_out                   (spi_data_out           )

);

spi_master spi_master_m0(
	.sys_clk                        (clk                    ),
	.rst                            (protocol_rst           ),
	.nCS                            (SD_nCS                 ),
	.DCLK                           (SD_DCLK                ),
	.MOSI                           (SD_MOSI                ),
	.MISO                           (SD_MISO                ),
	.clk_div                        (clk_div                ),
	.CPOL                           (1'b1                   ),
	.CPHA                           (1'b1                   ),
	.nCS_ctrl                       (nCS_ctrl               ),
	.wr_req                         (spi_wr_req             ),
	.wr_ack                         (spi_wr_ack             ),
	.data_in                        (spi_data_in            ),
	.data_out                       (spi_data_out           )
);
endmodule
