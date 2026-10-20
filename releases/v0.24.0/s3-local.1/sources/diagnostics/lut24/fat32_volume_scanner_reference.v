// Read-only FAT32 root directory scanner. Derived from the lesson's resource
// contract; fields are captured as bytes arrive, without a 512-byte mux array.
module fat32_volume_scanner_reference #(
    parameter integer MAX_VISITED_CLUSTERS = 8192,
    parameter integer DIRECTORY_ENABLE = 0, REUSE_GEOMETRY=0,
    parameter integer SCAN_AUDIO = 0, SCAN_TEXT = 0, SCAN_PUBLICITY = 0
)(
    input wire clk, input wire rst_n, input wire scan_start,
    input wire [31:0] directory_cluster,
    output reg [5:0] directory_valid,
    output reg [191:0] directory_clusters,
    output wire scan_busy, output reg scan_done, output reg [7:0] fs_error,
    output reg [31:0] partition_lba,
    output reg [7:0] sectors_per_cluster,
    output reg [31:0] fat_start_lba, data_start_lba, max_cluster,
    output reg [3:0] resource_valid,
    output reg [31:0] resource0_cluster, resource1_cluster, resource2_cluster, resource3_cluster,
    output reg [31:0] resource0_size, resource1_size, resource2_size, resource3_size,
    output reg thumb_found,output reg [31:0] thumb_cluster,thumb_size,
    output reg audio_found, output reg [31:0] audio_cluster, audio_size,
    output reg [3:0] snd_valid,
    output reg [127:0] snd_clusters,snd_sizes,
    output reg font_found,text_found,
    output reg [31:0] font_cluster,font_size,text_cluster,text_size,
    output reg [3:0] edu_valid,voi_valid,
    output reg [3:0] voi_invalid,
    output reg [127:0] edu_clusters,edu_sizes,voi_clusters,voi_sizes,
    output reg sector_req, output reg [31:0] sector_lba,
    input wire sector_busy, sector_valid, input wire [7:0] sector_byte,
    input wire [8:0] sector_byte_index,
    input wire sector_done, input wire [7:0] sector_error
);
    localparam IDLE=0, ZERO_REQ=1, ZERO_WAIT=2, ZERO_PARSE=3,
        BOOT_REQ=4, BOOT_WAIT=5, BOOT_PARSE=6, LAYOUT=7, ROOT=8,
        DIR_REQ=9, DIR_WAIT=10, DIR_NEXT=11, FAT_REQ=12, FAT_WAIT=13,
        FAT_PARSE=14, FINISH=15, LAYOUT_SUB=16, LAYOUT_SHIFT=17, LAYOUT_MAX=18, LAYOUT_CHECK=19, ROOT_SHIFT=20, ROOT_ADD=21,
        LAYOUT_ACCEPT=22,FAT_CHECK=23,LAYOUT_LOAD=24,FAT_COMPARE=25,LAYOUT_COMPARE=26;
    localparam ERR_SECTOR=8'h10, ERR_SIGNATURE=8'h20, ERR_BPB=8'h21,
        ERR_LOOP=8'h23, ERR_RANGE=8'h24, ERR_LIMIT=8'h26;
    localparam COUNT_BITS=$clog2(MAX_VISITED_CLUSTERS+1);
    reg [4:0] state;
    reg [15:0] bytes_per_sector, reserved, root_entries, fat16, flags;
    reg signature_low_ok, signature_high_ok;
    reg [7:0] spc, fat_count;
    reg [31:0] total_sectors, fat_sectors, root_cluster;
    reg [31:0] mbr_lba[0:3];
    reg [3:0] mbr_match;
    reg [2:0] cluster_shift;
    reg [31:0] fat_span, current_cluster;
    reg [7:0] dir_sector;
    // The sector index and cluster size are stable throughout DIR_WAIT.
    // Prepare its successor decision before the wide LBA mux is enabled.
    reg dir_more_q;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)dir_more_q<=0;
        else dir_more_q<=dir_sector+1'b1<sectors_per_cluster;
    end
    reg [COUNT_BITS-1:0] visited;
    reg dir_end, name_match;
    reg audio_match;
    reg snd_match;
    reg font_match,text_match;
    reg edu_match,voi_match,thumb_match,geometry_valid;
    reg [1:0] resource_index;
    reg [31:0] entry_cluster, entry_size, fat_entry;
    wire [31:0] next_cluster={4'b0,fat_entry[27:0]};
    wire [8:0] fat_offset={current_cluster[6:0],2'b00};
    reg [31:0] overhead,data_sectors,cluster_count,partition_reserved,cluster_offset;
    reg data_borrow;   // total_sectors<overhead, from the LAYOUT_SUB subtraction
    reg [2:0] shift_count;   // layout and root shifts move one bit per cycle
    reg layout_bad,fat_end,fat_bad,fat_loop,fat_limit;
    reg fat_hi_gt,fat_hi_eq,fat_lo_gt,fat_too_small;
    reg fat_mid_gt,fat_mid_eq;
    reg root_hi_gt,root_hi_eq,root_lo_gt,dir_hi_gt,dir_hi_eq,dir_lo_gt;
    reg capacity_hi_gt,capacity_hi_eq,capacity_lo_ge,layout_fields_bad,dir_small;
    wire bpb_fields_ok=(bytes_per_sector==512) && spc!=0 && ((spc & (spc-1'b1))==0) &&
        reserved!=0 && (fat_count==1 || fat_count==2) && root_entries==0 && fat16==0 &&
        total_sectors!=0 && fat_sectors!=0 && root_cluster>=2 &&
        (!flags[7] || {4'd0,flags[3:0]}<fat_count);
    // BPB fields finish at byte 47, well before the sector-end parse states.
    // Register their joint test so it is not in the MBR address enable cone.
    // Signature (bytes 510/511) and sector_error retain their original checks.
    reg bpb_ok;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)bpb_ok<=0;
        else bpb_ok<=bpb_fields_ok;
    end
    wire [5:0] directory_match;
    wire [31:0] matched_cluster;
    generate if(DIRECTORY_ENABLE)begin:g_directories
     fat32_lfn_directories matcher(.clk(clk),.rst(!rst_n),.clear(state==IDLE && scan_start),
      .byte_valid(state==DIR_WAIT && sector_valid && !dir_end),
      .byte_index(sector_byte_index[4:0]),.byte_data(sector_byte),
      .directory_match(directory_match),.directory_cluster(matched_cluster));
    end else begin:g_no_directories
     assign directory_match=0;assign matched_cluster=0;
    end endgenerate
    // Match/cluster and split range predicates travel together for one cycle.
    // This removes the 32-bit range check from directory/audio-table enables.
    reg [5:0] directory_match_q;
    reg [31:0] matched_cluster_q;
    reg directory_hi_lt,directory_hi_eq,directory_lo_le,directory_min_ok;
    always @(posedge clk or negedge rst_n)begin
     if(!rst_n)begin
      directory_match_q<=0;matched_cluster_q<=0;
      directory_hi_lt<=0;directory_hi_eq<=0;directory_lo_le<=0;directory_min_ok<=0;
     end else begin
      directory_match_q<=directory_match;matched_cluster_q<=matched_cluster;
      directory_hi_lt<=matched_cluster[31:16]<max_cluster[31:16];
      directory_hi_eq<=matched_cluster[31:16]==max_cluster[31:16];
      directory_lo_le<=matched_cluster[15:0]<=max_cluster[15:0];
      directory_min_ok<=matched_cluster>=2;
     end
    end
    integer directory_slot;
    always @(posedge clk or negedge rst_n)begin
     if(!rst_n)begin directory_valid<=0;directory_clusters<=0;end
     else if(state==IDLE && scan_start)begin directory_valid<=0;directory_clusters<=0;end
     else if(directory_min_ok && (directory_hi_lt || (directory_hi_eq && directory_lo_le)))
      for(directory_slot=0;directory_slot<6;directory_slot=directory_slot+1)
       if(directory_match_q[directory_slot] && !directory_valid[directory_slot])begin
        directory_valid[directory_slot]<=1;
        directory_clusters[directory_slot*32+:32]<=matched_cluster_q;
       end
    end
    reg [31:0] requested_directory;
    reg requested_root;
    always @(posedge clk or negedge rst_n)begin
     if(!rst_n)begin requested_directory<=0;requested_root<=1;end
     else if(state==IDLE && scan_start)begin
      requested_directory<=DIRECTORY_ENABLE?directory_cluster:32'd0;
      requested_root<=!DIRECTORY_ENABLE || directory_cluster==0;
     end
    end
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
    // Names/attributes settle at byte 11, long before byte-31 commit.
    // Evaluate destination enables continuously: the commit strobe alone
    // qualifies them. Avoid a shared byte-index decode on nineteen CEs.
    (* keep = "true" *) reg [18:0] entry_accept;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) entry_accept<=0;
        else begin
                entry_accept[0]<=!dir_end && name_match && resource_index==0 && !resource_valid[0];
                entry_accept[1]<=!dir_end && name_match && resource_index==1 && !resource_valid[1];
                entry_accept[2]<=!dir_end && name_match && resource_index==2 && !resource_valid[2];
                entry_accept[3]<=!dir_end && name_match && resource_index==3 && !resource_valid[3];
                entry_accept[4]<=!dir_end && audio_match && !audio_found;
                entry_accept[5]<=!dir_end && snd_match && resource_index==0 && !snd_valid[0];
                entry_accept[6]<=!dir_end && snd_match && resource_index==1 && !snd_valid[1];
                entry_accept[7]<=!dir_end && snd_match && resource_index==2 && !snd_valid[2];
                entry_accept[9]<=!dir_end && font_match && !font_found;
                entry_accept[10]<=!dir_end && text_match && !text_found;
                entry_accept[8]<=!dir_end && snd_match && resource_index==3 && !snd_valid[3];
                entry_accept[11]<=!dir_end && edu_match && resource_index==0 && !edu_valid[0];
                entry_accept[12]<=!dir_end && edu_match && resource_index==1 && !edu_valid[1];
                entry_accept[13]<=!dir_end && edu_match && resource_index==2 && !edu_valid[2];
                entry_accept[14]<=!dir_end && edu_match && resource_index==3 && !edu_valid[3];
                entry_accept[15]<=!dir_end && voi_match && resource_index==0 && !voi_valid[0];
                entry_accept[16]<=!dir_end && voi_match && resource_index==1 && !voi_valid[1];
                entry_accept[17]<=!dir_end && voi_match && resource_index==2 && !voi_valid[2];
                entry_accept[18]<=!dir_end && voi_match && resource_index==3 && !voi_valid[3];
        end
    end
    // Delay the byte-31 commit enable and final size byte together. Entry
    // cluster/low size remain stable until byte 20 of the next directory entry.
    // This removes the sector-index decode from the wide output register CE.
    (* keep = "true" *) reg [18:0] entry_commit;
    reg [7:0] entry_size_high;
    reg publicity_bmp_size_ok,publicity_pcm_size_ok;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            entry_commit<=0;entry_size_high<=0;
            publicity_bmp_size_ok<=0;publicity_pcm_size_ok<=0;
        end
        else begin
            entry_commit<=0;
            if(state==DIR_WAIT && sector_valid && sector_byte_index[4:0]==31)begin
                entry_commit<=entry_accept;entry_size_high<=sector_byte;
                // Size low bytes are already stable. Qualify the final byte
                // alongside commit, so the wide metadata CEs use one bit.
                publicity_bmp_size_ok<=sector_byte!=0 || entry_size[23:0]>=54;
                publicity_pcm_size_ok<=(sector_byte!=0 || entry_size[23:0]!=0) && !entry_size[0];
            end
        end
    end
    wire [31:0] committed_size={entry_size_high,entry_size[23:0]};
    // THUMB   BMP is an independent 8.3 entry, never a PIC stage alias.
    reg thumb_commit;
    always @(posedge clk or negedge rst_n)begin
     if(!rst_n)begin thumb_match<=0;thumb_commit<=0;thumb_found<=0;thumb_cluster<=0;thumb_size<=0;end
     else begin
      thumb_commit<=state==DIR_WAIT && sector_valid && !dir_end && sector_byte_index[4:0]==31 && thumb_match;
      if(state==IDLE && scan_start)begin thumb_found<=0;thumb_cluster<=0;thumb_size<=0;thumb_match<=0;end
      else if(thumb_commit && DIRECTORY_ENABLE && !thumb_found)begin
       thumb_found<=1;thumb_cluster<=entry_cluster;thumb_size<=committed_size;
      end
      if(state==DIR_WAIT && sector_valid && !dir_end)case(sector_byte_index[4:0])
       0:thumb_match<=DIRECTORY_ENABLE && sector_byte=="T";
       1:thumb_match<=thumb_match && sector_byte=="H";
       2:thumb_match<=thumb_match && sector_byte=="U";
       3:thumb_match<=thumb_match && sector_byte=="M";
       4:thumb_match<=thumb_match && sector_byte=="B";
       5,6,7:thumb_match<=thumb_match && sector_byte==" ";
       8:thumb_match<=thumb_match && sector_byte=="B";
       9:thumb_match<=thumb_match && sector_byte=="M";
       10:thumb_match<=thumb_match && sector_byte=="P";
       11:thumb_match<=thumb_match && (sector_byte & 8'h18)==0;
       default:;
      endcase
     end
    end
    // Cluster bytes finish at offset 27, four byte times before commit.
    // Two stages fit between the final cluster byte (27) and commit (31),
    // even with contiguous bytes. Split the wide range comparator first.
    reg publicity_cluster_ok,publicity_hi_lt,publicity_hi_eq;
    reg publicity_lo_le,publicity_cluster_min;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            publicity_cluster_ok<=0;publicity_hi_lt<=0;publicity_hi_eq<=0;
            publicity_lo_le<=0;publicity_cluster_min<=0;
        end else begin
            publicity_hi_lt<=entry_cluster[31:16]<max_cluster[31:16];
            publicity_hi_eq<=entry_cluster[31:16]==max_cluster[31:16];
            publicity_lo_le<=entry_cluster[15:0]<=max_cluster[15:0];
            publicity_cluster_min<=|entry_cluster[31:1];
            publicity_cluster_ok<=publicity_cluster_min &&
                (publicity_hi_lt || (publicity_hi_eq && publicity_lo_le));
        end
    end
    integer publicity_slot;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            edu_valid<=0;voi_valid<=0;voi_invalid<=0;edu_clusters<=0;edu_sizes<=0;voi_clusters<=0;voi_sizes<=0;
        end else if(state==IDLE && scan_start) begin
            edu_valid<=0;voi_valid<=0;voi_invalid<=0;edu_clusters<=0;edu_sizes<=0;voi_clusters<=0;voi_sizes<=0;
        end else if(SCAN_PUBLICITY) begin
            // Only new resources get these basic metadata checks. BMP format
            // is checked by reader preflight; PCM content is checked downstream.
            for(publicity_slot=0;publicity_slot<4;publicity_slot=publicity_slot+1) begin
                if(entry_commit[11+publicity_slot] && publicity_cluster_ok && publicity_bmp_size_ok) begin
                    edu_valid[publicity_slot]<=1;
                    edu_clusters[32*publicity_slot+:32]<=entry_cluster;
                    edu_sizes[32*publicity_slot+:32]<=committed_size;
                end
                if(entry_commit[15+publicity_slot] && (!publicity_cluster_ok || !publicity_pcm_size_ok))
                    voi_invalid[publicity_slot]<=1;
                if(entry_commit[15+publicity_slot] && publicity_cluster_ok && publicity_pcm_size_ok) begin
                    voi_valid[publicity_slot]<=1;voi_invalid[publicity_slot]<=0;
                    voi_clusters[32*publicity_slot+:32]<=entry_cluster;
                    voi_sizes[32*publicity_slot+:32]<=committed_size;
                end
            end
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            resource_valid<=0;audio_found<=0;audio_cluster<=0;audio_size<=0;
            snd_valid<=0;snd_clusters<=0;snd_sizes<=0;
            font_found<=0;text_found<=0;font_cluster<=0;font_size<=0;text_cluster<=0;text_size<=0;
            resource0_cluster<=0;resource1_cluster<=0;resource2_cluster<=0;resource3_cluster<=0;
            resource0_size<=0;resource1_size<=0;resource2_size<=0;resource3_size<=0;
        end else if(state==IDLE && scan_start) begin
            resource_valid<=0;audio_found<=0;audio_cluster<=0;audio_size<=0;
            snd_valid<=0;snd_clusters<=0;snd_sizes<=0;
            font_found<=0;text_found<=0;font_cluster<=0;font_size<=0;text_cluster<=0;text_size<=0;
            resource0_cluster<=0;resource1_cluster<=0;resource2_cluster<=0;resource3_cluster<=0;
            resource0_size<=0;resource1_size<=0;resource2_size<=0;resource3_size<=0;
        end else begin
            if(entry_commit[0])begin resource_valid[0]<=1;resource0_cluster<=entry_cluster;resource0_size<={entry_size_high,entry_size[23:0]};end
            if(entry_commit[1])begin resource_valid[1]<=1;resource1_cluster<=entry_cluster;resource1_size<={entry_size_high,entry_size[23:0]};end
            if(entry_commit[2])begin resource_valid[2]<=1;resource2_cluster<=entry_cluster;resource2_size<={entry_size_high,entry_size[23:0]};end
            if(entry_commit[3])begin resource_valid[3]<=1;resource3_cluster<=entry_cluster;resource3_size<={entry_size_high,entry_size[23:0]};end
            if(entry_commit[4])begin audio_found<=1;audio_cluster<=entry_cluster;audio_size<={entry_size_high,entry_size[23:0]};end
            if(entry_commit[5])begin snd_valid[0]<=1;snd_clusters[31:0]<=entry_cluster;snd_sizes[31:0]<={entry_size_high,entry_size[23:0]};end
            if(entry_commit[6])begin snd_valid[1]<=1;snd_clusters[63:32]<=entry_cluster;snd_sizes[63:32]<={entry_size_high,entry_size[23:0]};end
            if(entry_commit[7])begin snd_valid[2]<=1;snd_clusters[95:64]<=entry_cluster;snd_sizes[95:64]<={entry_size_high,entry_size[23:0]};end
            if(entry_commit[9])begin font_found<=1;font_cluster<=entry_cluster;font_size<={entry_size_high,entry_size[23:0]};end
            if(entry_commit[10])begin text_found<=1;text_cluster<=entry_cluster;text_size<={entry_size_high,entry_size[23:0]};end
            if(entry_commit[8])begin snd_valid[3]<=1;snd_clusters[127:96]<=entry_cluster;snd_sizes[127:96]<={entry_size_high,entry_size[23:0]};end
        end
    end
    integer j;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=IDLE;scan_done<=0;fs_error<=0;sector_req<=0;sector_lba<=0;
            layout_bad<=0;geometry_valid<=0;fat_end<=0;fat_bad<=0;fat_loop<=0;fat_limit<=0;
            fat_hi_gt<=0;fat_hi_eq<=0;fat_lo_gt<=0;fat_too_small<=0;fat_mid_gt<=0;fat_mid_eq<=0;
            partition_lba<=0;sectors_per_cluster<=0;fat_start_lba<=0;data_start_lba<=0;max_cluster<=0;
            bytes_per_sector<=0;reserved<=0;root_entries<=0;fat16<=0;flags<=0;signature_low_ok<=0;signature_high_ok<=0;
            spc<=0;fat_count<=0;total_sectors<=0;fat_sectors<=0;root_cluster<=0;
            mbr_match<=0;for(j=0;j<4;j=j+1)mbr_lba[j]<=0;
            overhead<=0;data_sectors<=0;data_borrow<=0;shift_count<=0;cluster_count<=0;partition_reserved<=0;cluster_offset<=0;cluster_shift<=0;fat_span<=0;current_cluster<=0;dir_sector<=0;visited<=0;
            dir_end<=0;name_match<=0;resource_index<=0;entry_cluster<=0;entry_size<=0;fat_entry<=0;
            audio_match<=0;snd_match<=0;font_match<=0;text_match<=0;edu_match<=0;voi_match<=0;
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
                    510:signature_low_ok<=(sector_byte==8'h55);511:signature_high_ok<=(sector_byte==8'haa);
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
                    0:begin edu_match<=SCAN_PUBLICITY && sector_byte=="E";voi_match<=SCAN_PUBLICITY && sector_byte=="V";end
                    1:begin edu_match<=edu_match && sector_byte=="D";voi_match<=voi_match && sector_byte=="O";end
                    2:begin edu_match<=edu_match && sector_byte=="U";voi_match<=voi_match && sector_byte=="I";end
                    3:begin edu_match<=edu_match && sector_byte>="1" && sector_byte<="4";voi_match<=voi_match && sector_byte>="1" && sector_byte<="4";end
                    4,5,6,7:begin edu_match<=edu_match && sector_byte==" ";voi_match<=voi_match && sector_byte==" ";end
                    8:begin edu_match<=edu_match && sector_byte=="B";voi_match<=voi_match && sector_byte=="P";end
                    9:begin edu_match<=edu_match && sector_byte=="M";voi_match<=voi_match && sector_byte=="C";end
                    10:begin edu_match<=edu_match && sector_byte=="P";voi_match<=voi_match && sector_byte=="M";end
                    11:begin edu_match<=edu_match && (sector_byte & 8'h18)==0;voi_match<=voi_match && (sector_byte & 8'h18)==0;end
                    default:;
                endcase
                case(sector_byte_index[4:0])
                    0:begin font_match<=SCAN_TEXT && sector_byte=="F";text_match<=SCAN_TEXT && sector_byte=="T";name_match<=(sector_byte=="P");audio_match<=SCAN_AUDIO && (sector_byte=="B");snd_match<=SCAN_AUDIO && sector_byte=="S";if(sector_byte==0)dir_end<=1;end
                    1:begin font_match<=font_match && sector_byte=="O";text_match<=text_match && sector_byte=="E";name_match<=name_match && sector_byte=="I";audio_match<=audio_match && sector_byte=="G";snd_match<=snd_match && sector_byte=="N";end
                    2:begin font_match<=font_match && sector_byte=="N";text_match<=text_match && sector_byte=="X";name_match<=name_match && sector_byte=="C";audio_match<=audio_match && sector_byte=="M";snd_match<=snd_match && sector_byte=="D";end
                    3:begin font_match<=font_match && sector_byte=="T";text_match<=text_match && sector_byte=="T";name_match<=name_match && sector_byte>="1" && sector_byte<="4";audio_match<=audio_match && sector_byte==" ";
                        snd_match<=snd_match && sector_byte>="1" && sector_byte<="4";resource_index<=sector_byte[1:0]-2'd1;end
                    4,5,6,7:begin font_match<=font_match && sector_byte==" ";text_match<=text_match && sector_byte==" ";name_match<=name_match && sector_byte==" ";audio_match<=audio_match && sector_byte==" ";snd_match<=snd_match && sector_byte==" ";end
                    8:begin font_match<=font_match && sector_byte=="B";text_match<=text_match && sector_byte=="B";name_match<=name_match && sector_byte=="B";audio_match<=audio_match && sector_byte=="P";snd_match<=snd_match && sector_byte=="P";end
                    9:begin font_match<=font_match && sector_byte=="I";text_match<=text_match && sector_byte=="I";name_match<=name_match && sector_byte=="M";audio_match<=audio_match && sector_byte=="C";snd_match<=snd_match && sector_byte=="C";end
                    10:begin font_match<=font_match && sector_byte=="N";text_match<=text_match && sector_byte=="N";name_match<=name_match && sector_byte=="P";audio_match<=audio_match && sector_byte=="M";snd_match<=snd_match && sector_byte=="M";end
                    // Accept read-only/hidden/system/archive files; exclude LFN,
                    // volume labels and subdirectories by their attribute bits.
                    11:begin font_match<=font_match && (sector_byte & 8'h18)==0;text_match<=text_match && (sector_byte & 8'h18)==0;name_match<=name_match && (sector_byte & 8'h18)==0;audio_match<=audio_match && (sector_byte & 8'h18)==0;snd_match<=snd_match && (sector_byte & 8'h18)==0;end
                    20:entry_cluster[23:16]<=sector_byte;
                    21:entry_cluster[31:24]<={4'b0,sector_byte[3:0]};
                    26:entry_cluster[7:0]<=sector_byte;27:entry_cluster[15:8]<=sector_byte;
                    28:entry_size[7:0]<=sector_byte;29:entry_size[15:8]<=sector_byte;30:entry_size[23:16]<=sector_byte;
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
                    fs_error<=0;mbr_match<=0;dir_end<=0;
                    if(REUSE_GEOMETRY && geometry_valid)state<=LAYOUT_CHECK;
                    else begin partition_lba<=0;sector_lba<=0;state<=ZERO_REQ;end
                end
                ZERO_REQ:if(!sector_busy)begin sector_req<=1;state<=ZERO_WAIT;end
                ZERO_WAIT:if(sector_done)begin if(sector_error!=0)fail(ERR_SECTOR);else state<=ZERO_PARSE;end
                ZERO_PARSE:begin
                    if(!signature_low_ok || !signature_high_ok)fail(ERR_SIGNATURE);
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
                    if(!signature_low_ok || !signature_high_ok)fail(ERR_SIGNATURE);
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
                    {data_borrow,data_sectors}<={1'b0,total_sectors}-{1'b0,overhead};
                    data_start_lba<=partition_lba+overhead;
                    state<=LAYOUT_LOAD;
                end
                LAYOUT_LOAD:begin cluster_count<=data_sectors;shift_count<=cluster_shift;state<=LAYOUT_SHIFT;end
                LAYOUT_SHIFT:if(shift_count!=0)begin cluster_count<={1'b0,cluster_count[31:1]};shift_count<=shift_count-1'b1;end
                else state<=LAYOUT_MAX;
                LAYOUT_MAX:begin max_cluster<=cluster_count+1;state<=LAYOUT_CHECK;end
                LAYOUT_CHECK:begin
                    if(DIRECTORY_ENABLE)begin
                        // BPB fields are stable: compare halfwords first, then
                        // combine in a separate cycle before directory access.
                        root_hi_gt<=root_cluster[31:16]>max_cluster[31:16];
                        root_hi_eq<=root_cluster[31:16]==max_cluster[31:16];
                        root_lo_gt<=root_cluster[15:0]>max_cluster[15:0];
                        dir_hi_gt<=requested_directory[31:16]>max_cluster[31:16];
                        dir_hi_eq<=requested_directory[31:16]==max_cluster[31:16];
                        dir_lo_gt<=requested_directory[15:0]>max_cluster[15:0];
                        dir_small<=requested_directory==1;
                        capacity_hi_gt<={7'd0,max_cluster[31:23]}>fat_sectors[31:16];
                        capacity_hi_eq<={7'd0,max_cluster[31:23]}==fat_sectors[31:16];
                        capacity_lo_ge<=max_cluster[22:7]>=fat_sectors[15:0];
                        layout_fields_bad<=data_borrow || data_sectors==0 || cluster_count==0 || cluster_count>32'h0fffffee;
                        state<=LAYOUT_COMPARE;
                    end else begin
                     layout_bad<=data_borrow || data_sectors==0 || cluster_count==0 ||
                       (requested_directory!=0 && (requested_directory<2 || requested_directory>max_cluster)) || root_cluster>max_cluster || cluster_count>32'h0fffffee ||
                       (max_cluster>>7)>=fat_sectors;
                     state<=LAYOUT_ACCEPT;
                    end
                end
                LAYOUT_COMPARE:begin
                    layout_bad<=layout_fields_bad || root_hi_gt || (root_hi_eq && root_lo_gt) ||
                        dir_small || dir_hi_gt || (dir_hi_eq && dir_lo_gt) ||
                        capacity_hi_gt || (capacity_hi_eq && capacity_lo_ge);
                    state<=LAYOUT_ACCEPT;
                end
                LAYOUT_ACCEPT:begin
                    if(layout_bad)fail(ERR_BPB);
                    else begin geometry_valid<=1;current_cluster<=requested_root?root_cluster:requested_directory;visited<=1;dir_sector<=0;state<=ROOT;end
                end
                ROOT:begin cluster_offset<=current_cluster-2;shift_count<=cluster_shift;state<=ROOT_SHIFT;end
                ROOT_SHIFT:if(shift_count!=0)begin cluster_offset<={cluster_offset[30:0],1'b0};shift_count<=shift_count-1'b1;end
                else state<=ROOT_ADD;
                ROOT_ADD:begin sector_lba<=data_start_lba+cluster_offset;state<=DIR_REQ;end
                DIR_REQ:if(!sector_busy)begin sector_req<=1;name_match<=0;state<=DIR_WAIT;end
                DIR_WAIT:if(sector_done)begin if(sector_error!=0)fail(ERR_SECTOR);else state<=DIR_NEXT;end
                DIR_NEXT:begin
                    // Publicity resources may follow a complete legacy set.
                    // Scan to directory/EOC end even when optional VOI is absent.
                    if(dir_end || (!DIRECTORY_ENABLE && !SCAN_PUBLICITY && resource_valid==4'hf && (!SCAN_AUDIO || (audio_found && snd_valid==4'hf)) && (!SCAN_TEXT || (font_found && text_found))))state<=FINISH;
                    else if(dir_more_q)begin
                        dir_sector<=dir_sector+1'b1;sector_lba<=sector_lba+1'b1;state<=DIR_REQ;
                    end else begin sector_lba<=fat_start_lba+(current_cluster>>7);state<=FAT_REQ;end
                end
                FAT_REQ:if(!sector_busy)begin sector_req<=1;state<=FAT_WAIT;end
                FAT_WAIT:if(sector_done)begin if(sector_error!=0)fail(ERR_SECTOR);else state<=FAT_PARSE;end
                FAT_PARSE:begin
                    fat_end<=next_cluster>=32'h0ffffff8;
                    // Split the variable 32-bit range compare across cycles.
                    // fat_entry is stable after sector_done and through FAT_CHECK.
                    fat_hi_gt<=next_cluster[31:16]>max_cluster[31:16];
                    fat_hi_eq<=next_cluster[31:16]==max_cluster[31:16];
                    fat_mid_gt<=next_cluster[15:8]>max_cluster[15:8];
                    fat_mid_eq<=next_cluster[15:8]==max_cluster[15:8];
                    fat_lo_gt<=next_cluster[7:0]>max_cluster[7:0];
                    fat_too_small<=next_cluster<2;
                    fat_loop<=next_cluster==current_cluster;
                    fat_limit<=visited>=MAX_VISITED_CLUSTERS;
                    state<=FAT_COMPARE;
                end
                FAT_COMPARE:begin
                    fat_bad<=fat_too_small || fat_hi_gt || (fat_hi_eq && (fat_mid_gt || (fat_mid_eq && fat_lo_gt)));
                    state<=FAT_CHECK;
                end
                FAT_CHECK:begin
                    if(fat_end)state<=FINISH;
                    else if(fat_bad)fail(ERR_RANGE);
                    else if(fat_loop)fail(ERR_LOOP);
                    else if(fat_limit)fail(ERR_LIMIT);
                    else begin current_cluster<=next_cluster;visited<=visited+1'b1;dir_sector<=0;state<=ROOT;end
                end
                FINISH:begin scan_done<=1;state<=IDLE;end
                default:state<=IDLE;
            endcase
        end
    end
endmodule
