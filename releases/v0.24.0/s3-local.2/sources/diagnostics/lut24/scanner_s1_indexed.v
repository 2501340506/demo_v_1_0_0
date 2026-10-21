// v0.24 S2 reference: the S1 scanner (register tables) behind the S2 indexed
// read interface. The muxes repeat the original reader/sd_card_bmp selection.
// Rows hold their last committed value; the S2 RAM and the S1 registers
// differ only in rows whose valid/found bit is clear.
module scanner_s1_indexed #(
    parameter integer MAX_VISITED_CLUSTERS = 8192,
    parameter integer DIRECTORY_ENABLE = 0, REUSE_GEOMETRY=0,
    parameter integer SCAN_AUDIO = 0, SCAN_TEXT = 0, SCAN_PUBLICITY = 0
)(
    input wire clk, input wire rst_n, input wire scan_start,
    input wire [31:0] directory_cluster,
    output wire [5:0] directory_valid, output wire [191:0] directory_clusters,
    output wire scan_busy, output wire scan_done, output wire [7:0] fs_error,
    output wire [31:0] partition_lba, output wire [7:0] sectors_per_cluster,
    output wire [31:0] fat_start_lba, data_start_lba, max_cluster,
    output wire [3:0] resource_valid, output wire thumb_found,
    input wire [3:0] image_index, output wire [31:0] image_cluster, image_size,
    output wire audio_found, output wire [3:0] snd_valid,
    input wire [3:0] audio_index, output wire [31:0] audio_entry_cluster, audio_entry_size,
    output wire font_found,text_found, output wire [31:0] font_cluster,font_size,text_cluster,text_size,
    output wire [3:0] edu_valid,voi_valid,voi_invalid,
    output wire sector_req, output wire [31:0] sector_lba,
    input wire sector_busy, sector_valid, input wire [7:0] sector_byte,
    input wire [8:0] sector_byte_index, input wire sector_done, input wire [7:0] sector_error
);
    wire [31:0] rc[0:3],rs[0:3],tc,ts,ac,as;
    wire [127:0] sc,ss,ec,es,vc,vs;
    fat32_volume_scanner_s1_reference #(.MAX_VISITED_CLUSTERS(MAX_VISITED_CLUSTERS),.DIRECTORY_ENABLE(DIRECTORY_ENABLE),
     .REUSE_GEOMETRY(REUSE_GEOMETRY),.SCAN_AUDIO(SCAN_AUDIO),.SCAN_TEXT(SCAN_TEXT),.SCAN_PUBLICITY(SCAN_PUBLICITY)) core(
     .clk(clk),.rst_n(rst_n),.scan_start(scan_start),.directory_cluster(directory_cluster),
     .directory_valid(directory_valid),.directory_clusters(directory_clusters),
     .scan_busy(scan_busy),.scan_done(scan_done),.fs_error(fs_error),
     .partition_lba(partition_lba),.sectors_per_cluster(sectors_per_cluster),
     .fat_start_lba(fat_start_lba),.data_start_lba(data_start_lba),.max_cluster(max_cluster),
     .resource_valid(resource_valid),
     .resource0_cluster(rc[0]),.resource1_cluster(rc[1]),.resource2_cluster(rc[2]),.resource3_cluster(rc[3]),
     .resource0_size(rs[0]),.resource1_size(rs[1]),.resource2_size(rs[2]),.resource3_size(rs[3]),
     .thumb_found(thumb_found),.thumb_cluster(tc),.thumb_size(ts),
     .audio_found(audio_found),.audio_cluster(ac),.audio_size(as),
     .snd_valid(snd_valid),.snd_clusters(sc),.snd_sizes(ss),
     .font_found(font_found),.text_found(text_found),
     .font_cluster(font_cluster),.font_size(font_size),.text_cluster(text_cluster),.text_size(text_size),
     .edu_valid(edu_valid),.voi_valid(voi_valid),.voi_invalid(voi_invalid),
     .edu_clusters(ec),.edu_sizes(es),.voi_clusters(vc),.voi_sizes(vs),
     .sector_req(sector_req),.sector_lba(sector_lba),
     .sector_busy(sector_busy),.sector_valid(sector_valid),.sector_byte(sector_byte),
     .sector_byte_index(sector_byte_index),.sector_done(sector_done),.sector_error(sector_error));
    wire [1:0] i=image_index[1:0], a=audio_index[1:0];
    assign image_cluster=image_index[3]?tc:image_index[2]?ec[32*i+:32]:rc[i];
    assign image_size=image_index[3]?ts:image_index[2]?es[32*i+:32]:rs[i];
    assign audio_entry_cluster=audio_index[3]?vc[32*a+:32]:audio_index[2]?sc[32*a+:32]:ac;
    assign audio_entry_size=audio_index[3]?vs[32*a+:32]:audio_index[2]?ss[32*a+:32]:as;
endmodule
