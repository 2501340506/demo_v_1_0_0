// Read-only FAT32 root directory scanner. Derived from the lesson's resource
// contract; fields are captured as bytes arrive, without a 512-byte mux array.
module fat32_volume_scanner #(
    parameter integer MAX_VISITED_CLUSTERS = 8192
)(
    input wire clk, input wire rst_n, input wire scan_start,
    output wire scan_busy, output reg scan_done, output reg [7:0] fs_error,
    output reg [31:0] partition_lba,
    output reg [7:0] sectors_per_cluster,
    output reg [31:0] fat_start_lba, data_start_lba, max_cluster,
    output reg [3:0] resource_valid,
    output reg [31:0] resource0_cluster, resource1_cluster, resource2_cluster, resource3_cluster,
    output reg [31:0] resource0_size, resource1_size, resource2_size, resource3_size,
    output reg sector_req, output reg [31:0] sector_lba,
    input wire sector_busy, sector_valid, input wire [7:0] sector_byte,
    input wire [8:0] sector_byte_index,
    input wire sector_done, input wire [7:0] sector_error
);
    localparam IDLE=0, ZERO_REQ=1, ZERO_WAIT=2, ZERO_PARSE=3,
        BOOT_REQ=4, BOOT_WAIT=5, BOOT_PARSE=6, LAYOUT=7, ROOT=8,
        DIR_REQ=9, DIR_WAIT=10, DIR_NEXT=11, FAT_REQ=12, FAT_WAIT=13,
        FAT_PARSE=14, FINISH=15, LAYOUT_SUB=16, LAYOUT_SHIFT=17, LAYOUT_MAX=18, LAYOUT_CHECK=19, ROOT_SHIFT=20, ROOT_ADD=21;
    localparam ERR_SECTOR=8'h10, ERR_SIGNATURE=8'h20, ERR_BPB=8'h21,
        ERR_LOOP=8'h23, ERR_RANGE=8'h24, ERR_LIMIT=8'h26;
    localparam COUNT_BITS=$clog2(MAX_VISITED_CLUSTERS+1);
    reg [4:0] state;
    reg [15:0] bytes_per_sector, reserved, root_entries, fat16, flags, signature;
    reg [7:0] spc, fat_count;
    reg [31:0] total_sectors, fat_sectors, root_cluster;
    reg [31:0] mbr_lba[0:3];
    reg [3:0] mbr_match;
    reg [2:0] cluster_shift;
    reg [31:0] fat_span, current_cluster;
    reg [7:0] dir_sector;
    reg [COUNT_BITS-1:0] visited;
    reg dir_end, name_match;
    reg [1:0] resource_index;
    reg [31:0] entry_cluster, entry_size, fat_entry;
    wire [31:0] next_cluster={4'b0,fat_entry[27:0]};
    wire [8:0] fat_offset={current_cluster[6:0],2'b00};
    reg [31:0] overhead,data_sectors,cluster_count,partition_reserved,cluster_offset;
    wire bpb_ok=(bytes_per_sector==512) && spc!=0 && ((spc & (spc-1'b1))==0) &&
        reserved!=0 && (fat_count==1 || fat_count==2) && root_entries==0 && fat16==0 &&
        total_sectors!=0 && fat_sectors!=0 && root_cluster>=2 &&
        (!flags[7] || {4'd0,flags[3:0]}<fat_count);
    assign scan_busy=(state!=IDLE);

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
    task fail;
        input [7:0] code;
        begin fs_error<=code;state<=FINISH;end
    endtask
    integer j;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=IDLE;scan_done<=0;fs_error<=0;sector_req<=0;sector_lba<=0;
            partition_lba<=0;sectors_per_cluster<=0;fat_start_lba<=0;data_start_lba<=0;max_cluster<=0;
            resource_valid<=0;resource0_cluster<=0;resource1_cluster<=0;resource2_cluster<=0;resource3_cluster<=0;
            resource0_size<=0;resource1_size<=0;resource2_size<=0;resource3_size<=0;
            bytes_per_sector<=0;reserved<=0;root_entries<=0;fat16<=0;flags<=0;signature<=0;
            spc<=0;fat_count<=0;total_sectors<=0;fat_sectors<=0;root_cluster<=0;
            mbr_match<=0;for(j=0;j<4;j=j+1)mbr_lba[j]<=0;
            overhead<=0;data_sectors<=0;cluster_count<=0;partition_reserved<=0;cluster_offset<=0;cluster_shift<=0;fat_span<=0;current_cluster<=0;dir_sector<=0;visited<=0;
            dir_end<=0;name_match<=0;resource_index<=0;entry_cluster<=0;entry_size<=0;fat_entry<=0;
        end else begin
            scan_done<=0;sector_req<=0;
            if(sector_valid && (state==ZERO_WAIT || state==BOOT_WAIT)) begin
                case(sector_byte_index)
                    11:bytes_per_sector[7:0]<=sector_byte;12:bytes_per_sector[15:8]<=sector_byte;
                    13:spc<=sector_byte;
                    14:reserved[7:0]<=sector_byte;15:reserved[15:8]<=sector_byte;
                    16:fat_count<=sector_byte;
                    17:root_entries[7:0]<=sector_byte;18:root_entries[15:8]<=sector_byte;
                    22:fat16[7:0]<=sector_byte;23:fat16[15:8]<=sector_byte;
                    32:total_sectors[7:0]<=sector_byte;33:total_sectors[15:8]<=sector_byte;
                    34:total_sectors[23:16]<=sector_byte;35:total_sectors[31:24]<=sector_byte;
                    36:fat_sectors[7:0]<=sector_byte;37:fat_sectors[15:8]<=sector_byte;
                    38:fat_sectors[23:16]<=sector_byte;39:fat_sectors[31:24]<=sector_byte;
                    40:flags[7:0]<=sector_byte;41:flags[15:8]<=sector_byte;
                    44:root_cluster[7:0]<=sector_byte;45:root_cluster[15:8]<=sector_byte;
                    46:root_cluster[23:16]<=sector_byte;47:root_cluster[31:24]<={4'b0,sector_byte[3:0]};
                    510:signature[7:0]<=sector_byte;511:signature[15:8]<=sector_byte;
                    default:;
                endcase
                if(state==ZERO_WAIT) begin
                    for(j=0;j<4;j=j+1) begin
                        if(sector_byte_index==450+16*j) mbr_match[j]<=(sector_byte==8'h0b || sector_byte==8'h0c);
                        if(sector_byte_index==454+16*j)mbr_lba[j][7:0]<=sector_byte;
                        if(sector_byte_index==455+16*j)mbr_lba[j][15:8]<=sector_byte;
                        if(sector_byte_index==456+16*j)mbr_lba[j][23:16]<=sector_byte;
                        if(sector_byte_index==457+16*j)mbr_lba[j][31:24]<=sector_byte;
                    end
                end
            end
            if(state==DIR_WAIT && sector_valid && !dir_end) begin
                case(sector_byte_index[4:0])
                    0:begin name_match<=(sector_byte=="P");if(sector_byte==0)dir_end<=1;end
                    1:name_match<=name_match && sector_byte=="I";
                    2:name_match<=name_match && sector_byte=="C";
                    3:begin name_match<=name_match && sector_byte>="1" && sector_byte<="4";
                        resource_index<=sector_byte[1:0]-2'd1;end
                    4,5,6,7:name_match<=name_match && sector_byte==" ";
                    8:name_match<=name_match && sector_byte=="B";
                    9:name_match<=name_match && sector_byte=="M";
                    10:name_match<=name_match && sector_byte=="P";
                    // Accept read-only/hidden/system/archive files; exclude LFN,
                    // volume labels and subdirectories by their attribute bits.
                    11:name_match<=name_match && (sector_byte & 8'h18)==0;
                    20:entry_cluster[23:16]<=sector_byte;
                    21:entry_cluster[31:24]<={4'b0,sector_byte[3:0]};
                    26:entry_cluster[7:0]<=sector_byte;27:entry_cluster[15:8]<=sector_byte;
                    28:entry_size[7:0]<=sector_byte;29:entry_size[15:8]<=sector_byte;30:entry_size[23:16]<=sector_byte;
                    31:if(name_match && !resource_valid[resource_index]) begin
                        resource_valid[resource_index]<=1;
                        case(resource_index)
                            0:begin resource0_cluster<=entry_cluster;resource0_size<={sector_byte,entry_size[23:0]};end
                            1:begin resource1_cluster<=entry_cluster;resource1_size<={sector_byte,entry_size[23:0]};end
                            2:begin resource2_cluster<=entry_cluster;resource2_size<={sector_byte,entry_size[23:0]};end
                            3:begin resource3_cluster<=entry_cluster;resource3_size<={sector_byte,entry_size[23:0]};end
                        endcase
                    end
                    default:;
                endcase
            end
            if(state==FAT_WAIT && sector_valid) begin
                if(sector_byte_index==fat_offset)fat_entry[7:0]<=sector_byte;
                if(sector_byte_index==fat_offset+9'd1)fat_entry[15:8]<=sector_byte;
                if(sector_byte_index==fat_offset+9'd2)fat_entry[23:16]<=sector_byte;
                if(sector_byte_index==fat_offset+9'd3)fat_entry[31:24]<=sector_byte;
            end
            case(state)
                IDLE:if(scan_start) begin
                    fs_error<=0;resource_valid<=0;partition_lba<=0;mbr_match<=0;dir_end<=0;
                    resource0_cluster<=0;resource1_cluster<=0;resource2_cluster<=0;resource3_cluster<=0;
                    resource0_size<=0;resource1_size<=0;resource2_size<=0;resource3_size<=0;
                    sector_lba<=0;state<=ZERO_REQ;
                end
                ZERO_REQ:if(!sector_busy)begin sector_req<=1;state<=ZERO_WAIT;end
                ZERO_WAIT:if(sector_done)begin if(sector_error!=0)fail(ERR_SECTOR);else state<=ZERO_PARSE;end
                ZERO_PARSE:begin
                    if(signature!=16'haa55)fail(ERR_SIGNATURE);
                    // An MBR can also begin EB/E9; recognize actual BPB fields.
                    else if(bpb_ok)state<=BOOT_PARSE;
                    else if(mbr_match!=0)begin
                        if(mbr_match[0])begin partition_lba<=mbr_lba[0];sector_lba<=mbr_lba[0];end
                        else if(mbr_match[1])begin partition_lba<=mbr_lba[1];sector_lba<=mbr_lba[1];end
                        else if(mbr_match[2])begin partition_lba<=mbr_lba[2];sector_lba<=mbr_lba[2];end
                        else begin partition_lba<=mbr_lba[3];sector_lba<=mbr_lba[3];end
                        state<=BOOT_REQ;
                    end else fail(ERR_BPB);
                end
                BOOT_REQ:if(!sector_busy)begin sector_req<=1;state<=BOOT_WAIT;end
                BOOT_WAIT:if(sector_done)begin if(sector_error!=0)fail(ERR_SECTOR);else state<=BOOT_PARSE;end
                BOOT_PARSE:begin
                    if(signature!=16'haa55)fail(ERR_SIGNATURE);
                    else if(!bpb_ok)fail(ERR_BPB);
                    else begin
                        sectors_per_cluster<=spc;cluster_shift<=spc_shift(spc);
                        fat_span<=fat_count==2 ? fat_sectors<<1 : fat_sectors;
                        partition_reserved<=partition_lba+{16'd0,reserved};
                        state<=LAYOUT;
                    end
                end
                LAYOUT:begin
                    overhead<={16'd0,reserved}+fat_span;
                    fat_start_lba<=partition_reserved+((flags[7] && flags[0])?fat_sectors:32'd0);
                    state<=LAYOUT_SUB;
                end
                LAYOUT_SUB:begin
                    data_sectors<=total_sectors-overhead;
                    data_start_lba<=partition_lba+overhead;
                    state<=LAYOUT_SHIFT;
                end
                LAYOUT_SHIFT:begin cluster_count<=data_sectors>>cluster_shift;state<=LAYOUT_MAX;end
                LAYOUT_MAX:begin max_cluster<=cluster_count+1;state<=LAYOUT_CHECK;end
                LAYOUT_CHECK:begin
                    if(total_sectors<=overhead || cluster_count==0 ||
                       root_cluster>max_cluster || cluster_count>32'h0fffffee ||
                       (max_cluster>>7)>=fat_sectors)fail(ERR_BPB);
                    else begin current_cluster<=root_cluster;visited<=1;dir_sector<=0;state<=ROOT;end
                end
                ROOT:begin cluster_offset<=current_cluster-2;state<=ROOT_SHIFT;end
                ROOT_SHIFT:begin cluster_offset<=cluster_offset<<cluster_shift;state<=ROOT_ADD;end
                ROOT_ADD:begin sector_lba<=data_start_lba+cluster_offset;state<=DIR_REQ;end
                DIR_REQ:if(!sector_busy)begin sector_req<=1;name_match<=0;state<=DIR_WAIT;end
                DIR_WAIT:if(sector_done)begin if(sector_error!=0)fail(ERR_SECTOR);else state<=DIR_NEXT;end
                DIR_NEXT:begin
                    if(dir_end || resource_valid==4'hf)state<=FINISH;
                    else if(dir_sector+1'b1<sectors_per_cluster)begin
                        dir_sector<=dir_sector+1'b1;sector_lba<=sector_lba+1'b1;state<=DIR_REQ;
                    end else begin sector_lba<=fat_start_lba+(current_cluster>>7);state<=FAT_REQ;end
                end
                FAT_REQ:if(!sector_busy)begin sector_req<=1;state<=FAT_WAIT;end
                FAT_WAIT:if(sector_done)begin if(sector_error!=0)fail(ERR_SECTOR);else state<=FAT_PARSE;end
                FAT_PARSE:begin
                    if(next_cluster>=32'h0ffffff8)state<=FINISH;
                    else if(next_cluster<2 || next_cluster>max_cluster)fail(ERR_RANGE);
                    else if(next_cluster==current_cluster)fail(ERR_LOOP);
                    else if(visited>=MAX_VISITED_CLUSTERS)fail(ERR_LIMIT);
                    else begin current_cluster<=next_cluster;visited<=visited+1'b1;dir_sector<=0;state<=ROOT;end
                end
                FINISH:begin scan_done<=1;state<=IDLE;end
                default:state<=IDLE;
            endcase
        end
    end
endmodule
