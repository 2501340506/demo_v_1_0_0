`timescale 1ns/1ps

module fat32_file_streamer #(
    parameter integer MAX_VISITED_CLUSTERS = 8192,
    parameter integer DATA_GATE_ENABLE = 0,
    parameter integer FILE_SIZE_BITS = 32
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        file_start,
    input  wire        data_permit,
    input  wire [31:0] first_cluster,
    input  wire [31:0] file_size,
    input  wire [7:0]  sectors_per_cluster,
    input  wire [31:0] fat_start_lba,
    input  wire [31:0] data_start_lba,
    input  wire [31:0] max_cluster,
    output wire        file_busy,
    output reg         file_done,
    output reg         file_valid,
    output reg  [7:0]  file_byte,
    output reg  [31:0] file_byte_offset,
    output reg  [7:0]  fs_error,
    output reg         sector_req,
    output reg  [31:0] sector_lba,
    input  wire        sector_busy,
    input  wire        sector_valid,
    input  wire [7:0]  sector_byte,
    input  wire [8:0]  sector_byte_index,
    input  wire        sector_done,
    input  wire [7:0]  sector_error
);
    localparam ERR_NONE              = 8'h00;
    localparam ERR_SECTOR            = 8'h10;
    localparam ERR_FAT_LOOP          = 8'h23;
    localparam ERR_CLUSTER_RANGE     = 8'h24;
    localparam ERR_EARLY_EOF         = 8'h25;
    localparam ERR_VISITED_EXHAUSTED = 8'h26;

    localparam ST_IDLE       = 4'd0;
    localparam ST_DATA_REQ   = 4'd1;
    localparam ST_DATA_WAIT  = 4'd2;
    localparam ST_FAT_REQ    = 4'd3;
    localparam ST_FAT_WAIT   = 4'd4;
    localparam ST_FAT_PARSE  = 4'd5;
    localparam ST_FAT_CHECK  = 4'd6;
    localparam ST_FINISH     = 4'd7;
    localparam ST_OFFSET=4'd8,ST_SHIFT=4'd9,ST_ADDRESS=4'd10,ST_VALIDATE=4'd11,ST_FAT_EVAL=4'd12;
    reg start_invalid,start_empty;
    reg [3:0] start_gt,start_eq;
    wire start_range_bad=start_gt[3] || (start_eq[3] && start_gt[2]) ||
        (&start_eq[3:2] && start_gt[1]) || (&start_eq[3:1] && start_gt[0]);
    reg [31:0] cluster_offset;
    reg [2:0] shift_count;   // cluster_offset is shifted one bit per cycle

    localparam integer CHAIN_COUNT_WIDTH = $clog2(MAX_VISITED_CLUSTERS + 1);

    reg [3:0] state;
    reg [31:0] current_cluster;
    reg [31:0] next_cluster;
    (* keep = "true" *) reg next_eoc,next_invalid,next_self;
    reg [3:0] next_gt,next_eq;
    wire next_range_bad = next_invalid || next_gt[3] || (next_eq[3] && next_gt[2]) ||
        (&next_eq[3:2] && next_gt[1]) || (&next_eq[3:1] && next_gt[0]);
    (* keep = "true" *) reg [31:0] fat_value_latched, fat_cluster_snapshot;
    reg [FILE_SIZE_BITS-1:0] remaining_bytes;
    reg remaining_empty, remaining_one;
    reg [7:0] sector_in_cluster;
    reg [8:0] fat_entry_offset;
    reg [7:0] fat_byte0, fat_byte1, fat_byte2, fat_byte3;
    reg [CHAIN_COUNT_WIDTH-1:0] chain_count;
    // Volume configuration is stable while a request is active; file size is
    // latched because offsets must not depend on the caller's next selection.
    reg [FILE_SIZE_BITS-1:0] size_latched;
    wire [FILE_SIZE_BITS-1:0] emitted_offset = size_latched - remaining_bytes;
    reg [2:0] cluster_shift;
    function [2:0] spc_shift;
        input [7:0] value;
        begin
            case(value)
                2:spc_shift=1;4:spc_shift=2;8:spc_shift=3;16:spc_shift=4;
                32:spc_shift=5;64:spc_shift=6;128:spc_shift=7;
                default:spc_shift=0;
            endcase
        end
    endfunction

    function valid_spc;
        input [7:0] value;
        begin case(value)
            1,2,4,8,16,32,64,128:valid_spc=1;
            default:valid_spc=0;
        endcase end
    endfunction
    assign file_busy = (state != ST_IDLE);
    // Byte comparisons finish on the existing validation/evaluation edge.
    // Combining their registered results keeps all public cycle counts intact.
    genvar range_byte;
    generate for(range_byte=0;range_byte<4;range_byte=range_byte+1)begin:g_range
        always @(posedge clk or negedge rst_n)begin
            if(!rst_n)begin
                start_gt[range_byte]<=0;start_eq[range_byte]<=0;
                next_gt[range_byte]<=0;next_eq[range_byte]<=0;
            end else begin
                if(state==ST_IDLE && file_start)begin
                    start_gt[range_byte]<=first_cluster[range_byte*8+:8]>max_cluster[range_byte*8+:8];
                    start_eq[range_byte]<=first_cluster[range_byte*8+:8]==max_cluster[range_byte*8+:8];
                end
                if(state==ST_FAT_EVAL)begin
                    next_gt[range_byte]<=fat_value_latched[range_byte*8+:8]>max_cluster[range_byte*8+:8];
                    next_eq[range_byte]<=fat_value_latched[range_byte*8+:8]==max_cluster[range_byte*8+:8];
                end
            end
        end
    end endgenerate

    task finish_with_error;
        input [7:0] code;
        begin
            fs_error <= code;
            state <= ST_FINISH;
        end
    endtask

    task advance_to_next_cluster;
        input [31:0] cluster_value;
        begin
            chain_count <= chain_count + 1'b1;
            current_cluster <= cluster_value;
            state <= ST_OFFSET;
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;cluster_offset<=0;shift_count<=0;start_invalid<=0;start_empty<=0;
            file_done <= 1'b0;
            file_valid <= 1'b0;
            file_byte <= 8'd0;
            file_byte_offset <= 32'd0;
            fs_error <= ERR_NONE;
            sector_req <= 1'b0;

            sector_lba <= 32'd0;
            current_cluster <= 32'd0;
            next_cluster <= 32'd0;
            next_eoc<=0;next_invalid<=0;next_self<=0;fat_value_latched<=0;fat_cluster_snapshot<=0;
            remaining_bytes <= 32'd0;
            remaining_empty <= 1; remaining_one <= 0;
            sector_in_cluster <= 8'd0;
            fat_entry_offset <= 9'd0;
            fat_byte0 <= 8'd0;
            fat_byte1 <= 8'd0;
            fat_byte2 <= 8'd0;
            fat_byte3 <= 8'd0;
            chain_count <= 0;
            size_latched <= 0; cluster_shift <= 0;
        end else begin
            file_done <= 1'b0;
            file_valid <= 1'b0;
            sector_req <= 1'b0;

            // FAT bytes and current_cluster are stable before ST_FAT_EVAL.
            // Sampling continuously removes the shared state decode from
            // these wide internal snapshot registers without changing any
            // public handshake or the evaluation cycle.
            fat_value_latched <= {4'd0, fat_byte3[3:0], fat_byte2, fat_byte1, fat_byte0};
            fat_cluster_snapshot <= current_cluster;

            if (state == ST_DATA_WAIT && sector_valid && remaining_bytes != 0) begin
                file_valid <= 1'b1;
                file_byte <= sector_byte;
                file_byte_offset <= emitted_offset;
                remaining_bytes <= remaining_bytes - 1'b1;
                // Predict the post-byte predicates on the same edge as the
                // decrement, keeping EOF and sector requests cycle identical.
                remaining_empty <= remaining_bytes == 1;
                remaining_one <= remaining_bytes == 2;
            end

            if (state == ST_FAT_WAIT && sector_valid) begin
                if (sector_byte_index == fat_entry_offset)
                    fat_byte0 <= sector_byte;
                else if (sector_byte_index == fat_entry_offset + 1'b1)
                    fat_byte1 <= sector_byte;
                else if (sector_byte_index == fat_entry_offset + 2'd2)
                    fat_byte2 <= sector_byte;
                else if (sector_byte_index == fat_entry_offset + 2'd3)
                    fat_byte3 <= sector_byte;
            end

            case (state)
                ST_IDLE: if (file_start) begin
                    fs_error <= ERR_NONE;
                    file_byte_offset <= 32'd0;
                    remaining_bytes <= file_size;
                    remaining_empty <= file_size[FILE_SIZE_BITS-1:0] == 0;
                    remaining_one <= file_size[FILE_SIZE_BITS-1:0] == 1;
                    sector_in_cluster <= 8'd0;
                    chain_count <= 1;
                    size_latched <= file_size;
                    cluster_shift <= spc_shift(sectors_per_cluster);
                    current_cluster <= first_cluster;
                    start_empty <= file_size==0;
                    // Compare bytes in parallel at acceptance. ST_VALIDATE
                    // combines the registered terms, retaining the existing
                    // request latency without a full-width comparator path.
                    start_invalid <= first_cluster<2 || !valid_spc(sectors_per_cluster);
                    state<=ST_VALIDATE;
                end
                ST_VALIDATE:begin
                    if (start_empty) begin
                        state <= ST_FINISH;
                    end else if (start_invalid || start_range_bad) begin
                        finish_with_error(ERR_CLUSTER_RANGE);
                    end else begin
                        state <= ST_OFFSET;
                    end
                end
                ST_OFFSET:begin cluster_offset<=current_cluster-2;shift_count<=cluster_shift;state<=ST_SHIFT;end
                ST_SHIFT:if(shift_count!=0)begin cluster_offset<={cluster_offset[30:0],1'b0};shift_count<=shift_count-1'b1;end
                else state<=ST_ADDRESS;
                ST_ADDRESS:begin sector_lba<=data_start_lba+cluster_offset;state<=ST_DATA_REQ;end
                ST_DATA_REQ: if (!sector_busy && (!DATA_GATE_ENABLE || data_permit)) begin
                    sector_req <= 1'b1;
                    state <= ST_DATA_WAIT;
                end
                ST_DATA_WAIT: if (sector_done) begin
                    if (sector_error != 0) begin
                        finish_with_error(ERR_SECTOR);
                    end else if (remaining_empty || (remaining_one && sector_valid)) begin
                        // Directory size is authoritative; no extra FAT read at EOF.
                        state <= ST_FINISH;
                    end else if (sector_in_cluster + 1'b1 < sectors_per_cluster) begin
                        sector_in_cluster <= sector_in_cluster + 1'b1;
                        sector_lba <= sector_lba + 1'b1;
                        state <= ST_DATA_REQ;
                    end else begin
                        sector_in_cluster <= 8'd0;
                        fat_entry_offset <= {current_cluster[6:0], 2'b00};
                        sector_lba <= fat_start_lba + (current_cluster >> 7);
                        state <= ST_FAT_REQ;
                    end
                end
                ST_FAT_REQ: if (!sector_busy) begin
                    sector_req <= 1'b1;
                    state <= ST_FAT_WAIT;
                end
                ST_FAT_WAIT: if (sector_done) begin
                    if (sector_error != 0)
                        finish_with_error(ERR_SECTOR);
                    else
                        state <= ST_FAT_PARSE;
                end
                ST_FAT_PARSE: begin
                    state<=ST_FAT_EVAL;
                end
                ST_FAT_EVAL: begin
                    next_cluster <= fat_value_latched;
                    next_eoc <= fat_value_latched[27:0]>=28'hffffff8;
                    // Combine registered byte comparisons in CHECK, just
                    // as at file acceptance; keep FAT latency and EOC priority.
                    next_invalid <= fat_value_latched<2;
                    next_self <= fat_value_latched==fat_cluster_snapshot;
                    state<=ST_FAT_CHECK;
                end
                ST_FAT_CHECK: begin
                    if (next_eoc) begin
                        finish_with_error(ERR_EARLY_EOF);
                    end else if (next_range_bad) begin
                        finish_with_error(ERR_CLUSTER_RANGE);
                    end else if (chain_count >= MAX_VISITED_CLUSTERS) begin
                        finish_with_error(ERR_VISITED_EXHAUSTED);
                    end else if (next_self) begin
                        finish_with_error(ERR_FAT_LOOP);
                    end else begin
                        advance_to_next_cluster(next_cluster);
                    end
                end
                ST_FINISH: begin
                    file_done <= 1'b1;
                    state <= ST_IDLE;
                end
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule

// File source bus (fat32_file_streamer): request {rst_n,file_start,
// data_permit,first_cluster[31:0],file_size[31:0]}, response {file_busy,
// file_done,file_valid,file_byte[7:0],file_byte_offset[31:0],fs_error[7:0]}.
module fat32_source_streamer #(
    parameter integer MAX_VISITED_CLUSTERS = 8192,
    parameter integer DATA_GATE_ENABLE = 0,
    parameter integer FILE_SIZE_BITS = 32
)(
 input wire clk,input wire [66:0] request,output wire [50:0] response,
 input wire [7:0] sectors_per_cluster,input wire [31:0] fat_start_lba,data_start_lba,max_cluster,
 output wire sector_req,output wire [31:0] sector_lba,
 input wire sector_busy,sector_valid,sector_done,
 input wire [7:0] sector_byte,sector_error,input wire [8:0] sector_index
);
 wire busy,done,valid;wire [7:0] data,error;wire [31:0] offset;
 fat32_file_streamer #(.MAX_VISITED_CLUSTERS(MAX_VISITED_CLUSTERS),.DATA_GATE_ENABLE(DATA_GATE_ENABLE),
  .FILE_SIZE_BITS(FILE_SIZE_BITS)) streamer(
  .clk(clk),.rst_n(request[66]),.file_start(request[65]),.data_permit(request[64]),
  .first_cluster(request[63:32]),.file_size(request[31:0]),
  .sectors_per_cluster(sectors_per_cluster),.fat_start_lba(fat_start_lba),.data_start_lba(data_start_lba),.max_cluster(max_cluster),
  .file_busy(busy),.file_done(done),.file_valid(valid),.file_byte(data),.file_byte_offset(offset),.fs_error(error),
  .sector_req(sector_req),.sector_lba(sector_lba),.sector_busy(sector_busy),.sector_valid(sector_valid),
  .sector_byte(sector_byte),.sector_byte_index(sector_index),.sector_done(sector_done),.sector_error(sector_error));
 assign response={busy,done,valid,data,offset,error};
endmodule
