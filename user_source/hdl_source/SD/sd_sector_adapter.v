// One outstanding 512-byte read. sector_req is a one-cycle request accepted
// when !sector_busy. Data is streamed at the existing SD driver's byte rate.
module sd_sector_adapter #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer TIMEOUT_MS = 500
)(
    input wire clk, input wire rst,
    input wire sector_req, input wire [31:0] sector_lba,
    output wire sector_busy,
    output wire sector_valid, output wire [7:0] sector_byte,
    output wire [8:0] sector_byte_index,
    output reg sector_done, output reg [7:0] sector_error,
    output wire sd_sec_read, output reg [31:0] sd_sec_read_addr,
    input wire sd_sec_read_data_valid, input wire [7:0] sd_sec_read_data,
    input wire sd_sec_read_end, input wire sd_sec_read_failed
);
    localparam IDLE=2'd0, READ=2'd1, COMPLETE=2'd2, GAP=2'd3;
    localparam ERR_READ=8'h10, ERR_TIMEOUT=8'h11, ERR_LENGTH=8'h12;
    localparam integer TIMEOUT_CYCLES=(CLK_FREQ_HZ/1000)*TIMEOUT_MS;
    localparam integer TIMER_BITS=(TIMEOUT_CYCLES>1)?$clog2(TIMEOUT_CYCLES):1;
    reg [1:0] state;
    reg request_active;
    reg [9:0] byte_count;
    reg [TIMER_BITS-1:0] idle_cycles;
    wire progress=sd_sec_read_data_valid || sd_sec_read_end || sd_sec_read_failed;
    wire deadline=(idle_cycles==TIMEOUT_CYCLES-1);
    wire length_ok=sd_sec_read_data_valid ? byte_count==10'd511 : byte_count==10'd512;

    // The driver returns straight to IDLE on failure. Withdraw in the same
    // cycle as its failed pulse, before it can accept the held request again.
    assign sd_sec_read=request_active && !sd_sec_read_failed && !sd_sec_read_end;
    assign sector_busy=(state!=IDLE);
    assign sector_valid=(state==READ) && sd_sec_read_data_valid &&
                        !sd_sec_read_failed && byte_count<10'd512;
    assign sector_byte=sd_sec_read_data;
    assign sector_byte_index=byte_count[8:0];

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            state<=IDLE; byte_count<=0; idle_cycles<=0;
            sector_done<=0; sector_error<=0; request_active<=0; sd_sec_read_addr<=0;
        end else begin
            sector_done<=0;
            case(state)
                IDLE: if(sector_req) begin
                    sd_sec_read_addr<=sector_lba;
                    request_active<=1;
                    byte_count<=0; idle_cycles<=0; sector_error<=0;
                    state<=READ;
                end
                READ: begin
                    if(progress) idle_cycles<=0;
                    else idle_cycles<=idle_cycles+1'b1;
                    // Saturate just beyond 512 so an overlong read cannot wrap.
                    if(sd_sec_read_data_valid && byte_count<10'd513)
                        byte_count<=byte_count+1'b1;
                    if(sd_sec_read_failed) begin
                        sector_error<=ERR_READ; request_active<=0; state<=COMPLETE;
                    end else if(sd_sec_read_end) begin
                        sector_error<=length_ok ? 8'd0 : ERR_LENGTH;
                        request_active<=0; state<=COMPLETE;
                    end else if(!progress && deadline) begin
                        sector_error<=ERR_TIMEOUT; request_active<=0; state<=COMPLETE;
                    end
                end
                // Last byte has already been sampled before this pulse.
                COMPLETE: begin sector_done<=1; state<=GAP; end
                GAP: state<=IDLE;
                default: begin state<=IDLE; request_active<=0; end
            endcase
        end
    end
endmodule
