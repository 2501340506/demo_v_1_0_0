module bmp_read #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer TIMEOUT_MS = 500,
    parameter integer ENABLE_SCAN_PAUSE = 0
)(
    input                       clk,
    input                       rst,
    output                      ready,

    // 上电扫描：从 scan_start_sector 开始，顺序寻找前 scan_target_count 张 BMP
    input                       scan_start,
    input  [31:0]               scan_start_sector,
    input  [31:0]               scan_max_sector,
    input  [2:0]                scan_target_count,
    input                       scan_pause_request,
    input                       scan_resume,
    output reg                  scan_paused,
    output reg [31:0]           scan_resume_sector,
    output reg                  scan_done,
    output reg                  scan_error,
    output reg                  scan_found_valid,
    output reg [31:0]           scan_found_sector,
    output reg [2:0]            scan_found_total,

    // 按指定扇区加载一张图到 SDRAM
    input                       load_start,
    input  [31:0]               load_sector,
    output reg                  load_done,
    output reg                  load_error,
    output reg [2:0]            bmp_error,

    input                       sd_init_done,
    output reg [3:0]            state_code,
    input  [15:0]               bmp_width,
    input  [15:0]               bmp_height,

    output reg                  write_req,
    input                       write_req_ack,

    output reg                  sd_sec_read,
    output reg [31:0]           sd_sec_read_addr,
    input  [7:0]                sd_sec_read_data,
    input                       sd_sec_read_data_valid,
    input                       sd_sec_read_end,
    input                       sd_sec_read_failed,

    output wire                 bmp_data_wr_en,
    output wire [23:0]          bmp_data
);

localparam ST_IDLE      = 3'd0;
localparam ST_SCAN      = 3'd1;
localparam ST_LOAD_HDR  = 3'd2;
localparam ST_LOAD_WAIT = 3'd3;
localparam ST_LOAD_DATA = 3'd4;
localparam ST_LOAD_DRAIN = 3'd5;
localparam ST_LOAD_CHECK = 3'd6;
localparam ST_STOP = 3'd7;

reg [2:0]  state;
reg [9:0]  rd_cnt;
reg scan_boundary;
reg scan_pause_pending;
// A pulse during a sector is remembered until that sector is fully consumed.
// The low-request boundary cycle also accepts a request based on found_valid.
always @(posedge clk or posedge rst) begin
    if (rst) scan_pause_pending <= 1'b0;
    else if (!ENABLE_SCAN_PAUSE) scan_pause_pending <= 1'b0;
    else if (!sd_init_done || state != ST_SCAN) scan_pause_pending <= 1'b0;
    else if (scan_pause_request) scan_pause_pending <= 1'b1;
end

// A no-progress deadline, not a whole-file or whole-scan deadline.
localparam integer TIMEOUT_CYCLES = (CLK_FREQ_HZ / 1000) * TIMEOUT_MS;
localparam integer TIMER_BITS = (TIMEOUT_CYCLES > 1) ? $clog2(TIMEOUT_CYCLES) : 1;
reg [TIMER_BITS-1:0] wait_cycles;
wire reading = (state == ST_SCAN) || (state == ST_LOAD_HDR) || (state == ST_LOAD_DATA);
wire waiting = reading || (state == ST_LOAD_WAIT);
wire progress = reading ? (sd_sec_read_data_valid || sd_sec_read_end) : write_req_ack;
wire wait_timeout = waiting && !progress && (wait_cycles == TIMEOUT_CYCLES - 1);
always @(posedge clk or posedge rst) begin
    if (rst) wait_cycles <= 0;
    else if (!sd_init_done || !waiting || progress || wait_timeout) wait_cycles <= 0;
    else wait_cycles <= wait_cycles + 1'b1;
end


wire [31:0] file_len, pixel_offset, expected_pixels;
wire [33:0] required_end;
wire header_match, skip_format;
bmp_header_check u_header (
 .clk(clk),.rst(rst),
 .file_valid(((state==ST_SCAN)||(state==ST_LOAD_HDR)) && sd_sec_read_data_valid),
 .file_byte(sd_sec_read_data),.file_byte_offset({22'd0,rd_cnt}),
 .bmp_width(bmp_width),.bmp_height(bmp_height),
 .file_len(file_len),.pixel_offset(pixel_offset),.width(),.height(),
 .required_end(required_end),.header_match(header_match),.skip_format(skip_format),
 .expected_pixels(expected_pixels),.header_complete(),.is_32(),.row_stride()
);
// In ST_SCAN the read address is also the current scan sector.
wire [31:0] scan_sector = sd_sec_read_addr;
reg [31:0] bmp_len_cnt;
reg [9:0] sector_bytes;
reg sector_complete;

wire sector_size_ok = sd_sec_read_data_valid ? (sector_bytes == 10'd511) :
                                               (sector_bytes == 10'd512);

// Count only received bytes. A short transfer must not shift the next sector
// into the missing bytes' position and accidentally complete a partial frame.
always @(posedge clk or posedge rst) begin
    if (rst) begin
        sector_bytes <= 0;
        sector_complete <= 0;
    end else if ((state == ST_SCAN) || (state == ST_LOAD_HDR) || (state == ST_LOAD_DATA)) begin
        if (sd_sec_read_end) begin
            sector_complete <= sector_size_ok;
            sector_bytes <= 0;
        end else if (sd_sec_read_data_valid) begin
            sector_bytes <= sector_bytes + 1'b1;
        end
    end else begin
        sector_bytes <= 0;
    end
end



reg [31:0] file_sector_count;
reg [32:0] next_scan_sector_if_match;
wire [31:0] next_scan_sector_if_miss;
wire skip_candidate = skip_format && (file_sector_count != 0) &&
 (next_scan_sector_if_match > {1'b0,scan_sector}) &&
 (next_scan_sector_if_match <= ({1'b0,scan_max_sector}+33'd1));
assign ready=(state==ST_IDLE);
// Header length is captured at byte 5; sector completion occurs at byte 512.
// Register these two additions separately instead of routing both through the
// scan state decision and the new completion/error outputs in one clock.
always @(posedge clk or posedge rst) begin
    if (rst) begin
        file_sector_count <= 32'd1;
        next_scan_sector_if_match <= 32'd0;
    end else begin
        file_sector_count <= (file_len == 32'd0) ? 32'd1 : ({9'd0, file_len[31:9]} + {31'd0, (|file_len[8:0])});
        next_scan_sector_if_match <= {1'b0, scan_sector} + {1'b0, file_sector_count};
    end
end
assign next_scan_sector_if_miss  = scan_sector + 32'd1;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        rd_cnt <= 10'd0;
    end else if ((state == ST_SCAN) || (state == ST_LOAD_HDR)) begin
        if (sd_sec_read_data_valid)
            rd_cnt <= rd_cnt + 10'd1;
        else if (sd_sec_read_end)
            rd_cnt <= 10'd0;
    end else begin
        rd_cnt <= 10'd0;
    end
end


always @(posedge clk or posedge rst) begin
    if (rst) begin
        bmp_len_cnt <= 32'd0;
    end else if (load_start && ready) begin
        bmp_len_cnt <= 32'd0;
    end else if (state == ST_LOAD_DATA) begin
        if (sd_sec_read_data_valid)
            bmp_len_cnt <= bmp_len_cnt + 32'd1;
    end
end


wire decoder_wr_en, decoder_done, decoder_commit;
wire [23:0] decoder_data;
wire [2:0] decoder_error;
wire decoder_end = (state == ST_LOAD_DRAIN) &&
                   (!sector_complete || {2'b00,bmp_len_cnt} >= required_end);
bmp24_decoder #(.RUNTIME_DIMENSIONS(1), .ALLOW_32(0)) u_decoder (
    .clk(clk), .rst(rst || !sd_init_done || state == ST_STOP),
    .expected_width(bmp_width), .expected_height(bmp_height),
    .file_start(state == ST_LOAD_WAIT && write_req_ack), .file_size(file_len),
    .file_valid(state == ST_LOAD_DATA && sd_sec_read_data_valid),
    .file_byte(sd_sec_read_data), .file_byte_offset(bmp_len_cnt),
    .file_end(decoder_end), .upstream_error(8'd0),
    .header_accepted(), .pixel_valid(decoder_wr_en), .pixel_rgb(decoder_data),
    .pixel_x(), .pixel_y(), .frame_commit(decoder_commit), .bmp_done(decoder_done),
    .bmp_error(decoder_error)
);
assign bmp_data_wr_en = decoder_wr_en;
assign bmp_data = decoder_data;
reg decoder_done_seen;
reg [2:0] decoder_error_seen;
always @(posedge clk or posedge rst) begin
    if (rst) begin decoder_done_seen<=0;decoder_error_seen<=0;end
    else if (state==ST_LOAD_WAIT) begin decoder_done_seen<=1'b0; decoder_error_seen<=3'd0; end
    else begin
        if (decoder_done) decoder_done_seen<=1'b1;
        if (decoder_error!=3'd0) decoder_error_seen<=decoder_error;
    end
end
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state             <= ST_IDLE;
        load_done         <= 1'b0;
        load_error        <= 1'b0;
        bmp_error         <= 3'd0;
        state_code        <= 4'd0;
        sd_sec_read       <= 1'b0;
        sd_sec_read_addr  <= 32'd0;
        write_req         <= 1'b0;
        scan_done         <= 1'b0;
        scan_error        <= 1'b0;
        scan_found_valid  <= 1'b0;
        scan_found_sector <= 32'd0;
        scan_found_total  <= 3'd0;
        scan_paused       <= 1'b0;
        scan_resume_sector <= 32'd0;
        scan_boundary     <= 1'b0;
    end else if (state == ST_STOP) begin
        // Late bytes/end/ack cannot revive an outstanding timed-out transaction.
        load_done <= 1'b0;
        load_error <= 1'b0;
        scan_error <= 1'b0;
        scan_found_valid <= 1'b0;
        sd_sec_read <= 1'b0;
        write_req <= 1'b0;
        state_code <= 4'hf;
    end else if (!sd_init_done) begin
        load_done         <= 1'b0;
        load_error        <= 1'b0;
        bmp_error         <= 3'd0;
        state             <= ST_IDLE;
        state_code        <= 4'd0;
        sd_sec_read       <= 1'b0;
        sd_sec_read_addr  <= 32'd0;
        write_req         <= 1'b0;
        scan_done         <= 1'b0;
        scan_error        <= 1'b0;
        scan_found_valid  <= 1'b0;
        scan_found_sector <= 32'd0;
        scan_found_total  <= 3'd0;
        scan_paused       <= 1'b0;
        scan_resume_sector <= 32'd0;
        scan_boundary     <= 1'b0;
    end else begin
        load_done <= 1'b0;
        load_error <= 1'b0;
        scan_found_valid <= 1'b0;
        scan_error <= 1'b0;

        if (wait_timeout || (waiting && sd_sec_read_failed)) begin
            state <= ST_STOP;
            state_code <= 4'hf;
            bmp_error <= 3'd2;
            scan_error <= (state == ST_SCAN);
            load_error <= (state != ST_SCAN);
            sd_sec_read <= 1'b0;
            write_req <= 1'b0;
        end else case (state)
            ST_IDLE: begin
                state_code  <= 4'd1;
                sd_sec_read <= 1'b0;
                write_req   <= 1'b0;

                if (scan_start) begin
                    scan_paused      <= 1'b0;
                    scan_boundary    <= (ENABLE_SCAN_PAUSE != 0);
                    if (ENABLE_SCAN_PAUSE) scan_resume_sector <= scan_start_sector;
                    scan_done        <= 1'b0;
                    scan_found_total <= 3'd0;
                    sd_sec_read_addr <= scan_start_sector;
                    state            <= ST_SCAN;
                end else if (load_start) begin
                    bmp_error          <= 3'd0;
                    sd_sec_read_addr    <= load_sector;
                    state               <= ST_LOAD_HDR;
                end else if (ENABLE_SCAN_PAUSE && scan_resume && scan_paused) begin
                    scan_paused      <= 1'b0;
                    scan_boundary    <= 1'b1;
                    sd_sec_read_addr <= scan_resume_sector;
                    state            <= ST_SCAN;
                end
            end

            ST_SCAN: begin
                state_code  <= 4'd2;
                if (ENABLE_SCAN_PAUSE && scan_boundary && (scan_pause_request || scan_pause_pending)) begin
                    // Count/address already include the completed sector. Loading
                    // may reuse sd_sec_read_addr without destroying this cursor.
                    sd_sec_read <= 1'b0;
                    scan_paused <= 1'b1;
                    scan_resume_sector <= sd_sec_read_addr;
                    state <= ST_IDLE;
                end else begin
                    scan_boundary <= 1'b0;
                    sd_sec_read <= 1'b1;
                end

                if (sd_sec_read_end) begin
                    sd_sec_read <= 1'b0;
                    scan_boundary <= (ENABLE_SCAN_PAUSE != 0);

                    if (header_match && sector_size_ok) begin
                        scan_found_valid  <= 1'b1;
                        scan_found_sector <= scan_sector;
                        scan_found_total  <= scan_found_total + 3'd1;

                        if ((scan_found_total + 3'd1 >= scan_target_count) || (next_scan_sector_if_match > scan_max_sector)) begin
                            scan_done        <= 1'b1;
                            state            <= ST_IDLE;
                            sd_sec_read_addr <= next_scan_sector_if_match[31:0];
                        end else begin
                            sd_sec_read_addr <= next_scan_sector_if_match[31:0];
                        end
                    end else if (skip_candidate && sector_size_ok) begin
                        if (next_scan_sector_if_match > {1'b0, scan_max_sector}) begin
                            scan_done <= 1'b1;
                            state <= ST_IDLE;
                        end else begin
                            sd_sec_read_addr <= next_scan_sector_if_match[31:0];
                        end
                    end else begin
                        if (scan_sector >= scan_max_sector) begin
                            scan_done <= 1'b1;
                            state     <= ST_IDLE;
                        end else begin
                            sd_sec_read_addr <= next_scan_sector_if_miss;
                        end
                    end
                end
            end

            ST_LOAD_HDR: begin
                state_code  <= 4'd2;
                sd_sec_read <= 1'b1;

                if (sd_sec_read_end) begin
                    sd_sec_read <= 1'b0;
                    if (!sector_size_ok) begin
                        bmp_error <= 3'd3;
                        load_error <= 1'b1;
                        state <= ST_IDLE;
                    end else if (header_match) begin
                        write_req        <= 1'b1;
                        // Header read leaves the load base in sd_sec_read_addr.
                        state            <= ST_LOAD_WAIT;
                    end else begin
                        bmp_error <= 3'd1;
                        load_error <= 1'b1;
                        state <= ST_IDLE;
                    end
                end
            end

            ST_LOAD_WAIT: begin
                state_code <= 4'd3;
                if (write_req_ack) begin
                    write_req <= 1'b0;
                    state     <= ST_LOAD_DATA;
                end
            end

            ST_LOAD_DATA: begin
                state_code  <= 4'd4;
                sd_sec_read <= 1'b1;

                if (sd_sec_read_end) begin
                    sd_sec_read <= 1'b0;
                    state <= ST_LOAD_DRAIN;
                end
            end

            // Let the final registered RGB write reach its consumer and counter
            // before checking completion, including data_valid coincident with end.
            ST_LOAD_DRAIN: begin
                sd_sec_read <= 1'b0;
                state <= ST_LOAD_CHECK;
            end

            ST_LOAD_CHECK: begin
                if (!sector_complete) begin
                    bmp_error <= 3'd3;
                    load_error <= 1'b1;
                    state <= ST_IDLE;
                end else if ({2'b00, bmp_len_cnt} >= required_end) begin
                    if (decoder_done || decoder_done_seen) begin
                        load_done <= 1'b1;
                    end else if (decoder_error != 0 || decoder_error_seen != 0) begin
                        bmp_error <= (decoder_error != 0) ? decoder_error : decoder_error_seen;
                        load_error <= 1'b1;
                    end
                    if (decoder_done || decoder_done_seen || decoder_error != 0 || decoder_error_seen != 0) state <= ST_IDLE;
                end else begin
                    sd_sec_read_addr <= sd_sec_read_addr + 32'd1;
                    state <= ST_LOAD_DATA;
                end
            end

            default: begin
                state       <= ST_IDLE;
                state_code  <= 4'd1;
                sd_sec_read <= 1'b0;
                write_req   <= 1'b0;
            end
        endcase
    end
end

endmodule
