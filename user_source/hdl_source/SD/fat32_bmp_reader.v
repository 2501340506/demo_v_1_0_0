// FAT32 scan/preflight/load coordinator. Sector ownership changes only at idle.
module fat32_bmp_reader #(
 parameter integer CLK_FREQ_HZ=100000000, TIMEOUT_MS=500,
 parameter integer SCAN_AUDIO=0, SCAN_TEXT=0, SCALE_ENABLE=0, SCAN_PUBLICITY=0,
 parameter integer MAX_VISITED_CLUSTERS=8192,
 // 1: loads select a found image by index from the scanner table instead of
 // taking load_cluster/load_size; the table only changes during a scan.
 parameter integer DIRECTORY_ENABLE=0,
 parameter integer LOAD_BY_INDEX=0
)(
 input clk,rst,sd_init_done,scan_start,load_start,load_cancel,
 // Opt-in module interface. Remap only when ready and both sector clients idle;
 // the caller must invalidate/quiesce its frame caches before requesting it.
 input map_start,resource_publicity,
 input [31:0] directory_cluster,input [2:0] expected_hazard,
 output [5:0] directory_valid,output [191:0] directory_clusters,
 output reg active_publicity,
 output [3:0] pic_valid,edu_valid,voi_valid,voi_invalid,
 output [127:0] pic_clusters,pic_sizes,edu_clusters,edu_sizes,voi_clusters,voi_sizes,
 output reg [3:0] mapped_valid,
 output reg [1:0] scan_found_slot,
 output audio_found,output [31:0] audio_cluster,audio_size,
 output [3:0] snd_valid,output [127:0] snd_clusters,snd_sizes,
 output font_found,text_found,output [31:0] font_cluster,font_size,text_cluster,text_size,
 output [7:0] audio_spc,output [31:0] audio_fat_lba,audio_data_lba,audio_max_cluster,
 input a_req,input [31:0] a_lba,input a_urgent,a_cancel,
 output a_busy,a_valid,a_done,output [7:0] a_error,a_byte,output [8:0] a_index,
 input [31:0] load_cluster,load_size,input [1:0] load_index,
 input [15:0] bmp_width,bmp_height,
 output ready, output reg scan_done,scan_error,scan_found_valid,
 output reg [31:0] scan_found_cluster,scan_found_size,
 output reg [2:0] scan_found_total,
 output reg [7:0] loaded_kind,
 output reg load_done,load_error, output reg [2:0] bmp_error,
 output reg [7:0] fat_error, output [3:0] state_code,
 output write_req,input write_req_ack,input write_ready,
 output bmp_data_wr_en,output [31:0] bmp_data,
 output sd_sec_read,output [31:0] sd_sec_read_addr,
 input [7:0] sd_sec_read_data,input sd_sec_read_data_valid,sd_sec_read_end,sd_sec_read_failed
);
 localparam IDLE=0,SCAN=1,SELECT=2,HEADER_RESET=3,HEADER_REQ=4,
 HEADER_WAIT=5,HEADER_CHECK=6,SCAN_FINISH=7,WRITE_WAIT=8,
 START_FILE=9,READ_FILE=10,DRAIN=11,RESULT=12,HEADER_SHIFT=13,HEADER_ADD=14,SELECT_CHECK=15,SELECT_RANGE=16,LOAD_SELECT=17;
 reg [4:0] state;
 reg scan_go,file_go;
 reg [2:0] candidate;
 reg [31:0] task_cluster,task_size,header_lba;
 reg [7:0] io_error;
 reg stream_finished,decode_finished;
 // Read type from the actual file stream, never from a scan or preload of
 // another image. Invalid/ordinary tags pass through; zero retains v1.
 reg [7:0] kind_hazard,kind_role;
 wire volume_done,volume_busy,stream_busy,stream_done,stream_valid;
 wire [7:0] volume_error,stream_error,stream_byte,spc;
 wire [31:0] fat_lba,data_lba,max_cluster,stream_offset;
 wire [3:0] mask=active_publicity ? edu_valid : pic_valid;
 wire [31:0] clusters[0:3],sizes[0:3];
 wire scan_req,file_req;wire [31:0] scan_lba,file_lba;
 wire sector_busy,sector_valid,sector_done;
 wire [7:0] sector_byte,sector_error;wire [8:0] sector_index;
 wire scan_owner=(state==SCAN);
 wire file_owner=(state==START_FILE || state==READ_FILE || state==DRAIN);
 wire abort_file=(state==DRAIN || state==RESULT || state==IDLE || load_cancel);
 // Local reset summaries settle before file_go. The START_FILE state provides
 // the release cycle; WRITE_WAIT holds the decoder reset until writer ack.
 // Request/data gates still observe cancellation immediately.
 reg abort_file_q,decoder_reset_q,scan_cancel_q;
 always @(posedge clk or posedge rst)begin
  if(rst)begin abort_file_q<=1;decoder_reset_q<=1;scan_cancel_q<=0;end
  else begin
   abort_file_q<=abort_file;
   decoder_reset_q<=state==WRITE_WAIT || load_cancel;
   scan_cancel_q<=load_cancel && state==SCAN;
  end
 end
 wire decoder_reset=rst || (SCAN_PUBLICITY?decoder_reset_q:(state==WRITE_WAIT || load_cancel));
 wire [2:0] decode_error;wire decode_done;
 wire request_allowed=(state==READ_FILE && decode_error==0 && !load_cancel);
 wire header_match;wire [33:0] required_end;
 wire [31:0] header_file_len;
 always @(posedge clk or posedge rst)begin
  if(rst)begin kind_hazard<=0;kind_role<=0;loaded_kind<=0;end
  else begin
   if(state==START_FILE)begin kind_hazard<=0;kind_role<=0;end
   if(state==READ_FILE && stream_valid)begin
    if(stream_offset==6)kind_hazard<=stream_byte;
    if(stream_offset==7)kind_role<=stream_byte;
   end
   if(state==RESULT && bmp_error==0)
    loaded_kind<=kind_hazard==0 && kind_role==0 ? 8'd0 :
      kind_hazard>=1 && kind_hazard<=4 && kind_role>=1 && kind_role<=4 ?
      {kind_hazard[3:0],kind_role[3:0]} : 8'hff;
  end
 end
 // Header fields settle before byte 54; completion is after byte 511.
 // Keep the 34-bit bound comparator off the mapped-slot write enables.
 reg header_end_hi_lt,header_end_hi_eq,header_end_lo_le,header_end_top_ok;
 reg header_size_ok;
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   header_end_hi_lt<=0;header_end_hi_eq<=0;header_end_lo_le<=0;
   header_end_top_ok<=0;header_size_ok<=0;
  end else begin
   header_end_hi_lt<=required_end[31:16]<task_size[31:16];
   header_end_hi_eq<=required_end[31:16]==task_size[31:16];
   header_end_lo_le<=required_end[15:0]<=task_size[15:0];
   header_end_top_ok<=required_end[33:32]==0;
   header_size_ok<=header_end_top_ok && (header_end_hi_lt ||
                       (header_end_hi_eq && header_end_lo_le));
  end
 end
 reg header_go;
 // Check the registered candidate, keeping the table mux off the range path.
 // A small constant limit needs only six low bits and a high-bit reduction;
 // do not infer a full 32-bit carry chain in the preflight state decision.
 wire selected_bad=!mask[candidate[1:0]] ||
   ((task_size[31:6]==0) && task_size[5:0]<6'd54) ||
   (task_cluster[31:1]==0) || task_cluster>max_cluster;
 // The enabled two-table design fans metadata out much further than the
 // legacy reader. Separate the range carry chain from the FSM decision.
 reg selected_bad_q;
 always @(posedge clk or posedge rst)begin
  if(rst)selected_bad_q<=0;
  else selected_bad_q<=selected_bad;
 end
 reg [2:0] strict_hazard;
 reg [1:0] found_slot[0:3];   // scanner slot of each accepted image
 // Resolve logical-to-physical mapping before selecting the wide metadata.
 // Both scanning and loading use the same registered physical table index.
 wire [1:0] select_slot=candidate[1:0];
 wire [31:0] selected_cluster=active_publicity ? edu_clusters[32*select_slot+:32] : clusters[select_slot];
 wire [31:0] selected_size=active_publicity ? edu_sizes[32*select_slot+:32] : sizes[select_slot];

 reg [7:0] header_hazard,header_role;
 wire header_valid;
 wire [7:0] header_byte;
 wire [8:0] header_index;
 always @(posedge clk or posedge rst)begin
  if(rst)begin strict_hazard<=0;header_hazard<=0;header_role<=0;end
  else begin
   if(state==IDLE && scan_start)strict_hazard<=DIRECTORY_ENABLE?expected_hazard:3'd0;
   if(state==HEADER_RESET)begin header_hazard<=0;header_role<=0;end
   if(header_valid)begin
    if(header_index==6)header_hazard<=header_byte;
    if(header_index==7)header_role<=header_byte;
   end
  end
 end
 reg metadata_ready,mapping_ready,cancelled;
 wire indexed_load_valid=mapping_ready && (active_publicity || strict_hazard!=0 ? mapped_valid[load_index] : {1'b0,load_index}<scan_found_total);
 assign pic_clusters={clusters[3],clusters[2],clusters[1],clusters[0]};
 assign pic_sizes={sizes[3],sizes[2],sizes[1],sizes[0]};
 function [2:0] spc_shift;
 input [7:0] v;
 begin case(v) 2:spc_shift=1;4:spc_shift=2;8:spc_shift=3;16:spc_shift=4;
 32:spc_shift=5;64:spc_shift=6;128:spc_shift=7;default:spc_shift=0;endcase end
 endfunction
 reg [2:0] header_cluster_shift;
reg [2:0] header_shift_count;   // header_lba is shifted one bit per cycle
 always @(posedge clk or posedge rst)begin
  if(rst)header_cluster_shift<=0;
  else header_cluster_shift<=spc_shift(spc);
 end
 assign ready=(state==IDLE && sd_init_done);
 assign state_code=(state==IDLE)?4'd1:((state<=SCAN_FINISH || state==SELECT_CHECK || state==SELECT_RANGE)?4'd2:4'd3);
 assign write_req=(state==WRITE_WAIT && !load_cancel);
 wire pixel_valid;
 wire pixel_ready=state==READ_FILE && decode_error==0 && stream_error==0 && !load_cancel && (!SCALE_ENABLE || write_ready);
 assign bmp_data_wr_en=pixel_valid && pixel_ready;
 wire data_permit;
 assign audio_spc=spc;
 assign audio_fat_lba=fat_lba;assign audio_data_lba=data_lba;assign audio_max_cluster=max_cluster;
 assign a_byte=sector_byte;assign a_index=sector_index;
 // Register the scanner response bundle together. This separates the shared
 // owner/state decode from the scanner's byte-field write enables.
 reg scan_sector_valid,scan_sector_done;
 reg [7:0] scan_sector_byte,scan_sector_error;
 reg [8:0] scan_sector_index;
 always @(posedge clk or posedge rst)begin
  if(rst)begin scan_sector_valid<=0;scan_sector_done<=0;scan_sector_byte<=0;scan_sector_error<=0;scan_sector_index<=0;end
  else begin
   scan_sector_valid<=scan_owner && sector_valid;scan_sector_done<=scan_owner && sector_done;
   scan_sector_byte<=sector_byte;scan_sector_error<=sector_error;scan_sector_index<=sector_index;
  end
 end
 fat32_volume_scanner #(.DIRECTORY_ENABLE(DIRECTORY_ENABLE),.SCAN_AUDIO(SCAN_AUDIO),.SCAN_TEXT(SCAN_TEXT),.SCAN_PUBLICITY(SCAN_PUBLICITY),.MAX_VISITED_CLUSTERS(MAX_VISITED_CLUSTERS)) scanner(
 .clk(clk),.rst_n(!rst && !(SCAN_PUBLICITY && scan_cancel_q)),.scan_start(scan_go),.scan_busy(volume_busy),.scan_done(volume_done),.fs_error(volume_error),
 .directory_cluster(directory_cluster),.directory_valid(directory_valid),.directory_clusters(directory_clusters),
 .partition_lba(),.sectors_per_cluster(spc),.fat_start_lba(fat_lba),.data_start_lba(data_lba),.max_cluster(max_cluster),
 .resource_valid(pic_valid),.audio_found(audio_found),.audio_cluster(audio_cluster),.audio_size(audio_size),.resource0_cluster(clusters[0]),.resource1_cluster(clusters[1]),.resource2_cluster(clusters[2]),.resource3_cluster(clusters[3]),
 .edu_valid(edu_valid),.edu_clusters(edu_clusters),.edu_sizes(edu_sizes),.voi_valid(voi_valid),.voi_invalid(voi_invalid),.voi_clusters(voi_clusters),.voi_sizes(voi_sizes),
 .font_found(font_found),.font_cluster(font_cluster),.font_size(font_size),.text_found(text_found),.text_cluster(text_cluster),.text_size(text_size),
 .snd_valid(snd_valid),.snd_clusters(snd_clusters),.snd_sizes(snd_sizes),
 .resource0_size(sizes[0]),.resource1_size(sizes[1]),.resource2_size(sizes[2]),.resource3_size(sizes[3]),
 .sector_req(scan_req),.sector_lba(scan_lba),.sector_busy(sector_busy),.sector_valid(scan_sector_valid),
 .sector_byte(scan_sector_byte),.sector_byte_index(scan_sector_index),.sector_done(scan_sector_done),.sector_error(scan_sector_error));
 // Keep the file response in one pipeline bundle: the last byte may arrive
 // with done. Cancellation discards the queued response while the service
 // continues draining the physical read under its existing ownership.
 reg file_sector_valid,file_sector_done,control_sector_done_q,header_sector_valid;
 reg [7:0] file_sector_byte,file_sector_error;
 reg [8:0] file_sector_index;
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   file_sector_valid<=0;file_sector_done<=0;control_sector_done_q<=0;header_sector_valid<=0;
   file_sector_byte<=0;file_sector_error<=0;file_sector_index<=0;
  end else begin
   control_sector_done_q<=sector_done;
   header_sector_valid<=state==HEADER_WAIT && sector_valid;
   file_sector_valid<=file_owner && !abort_file && sector_valid;
   file_sector_done<=file_owner && !abort_file && sector_done;
   file_sector_byte<=sector_byte;file_sector_error<=sector_error;file_sector_index<=sector_index;
  end
 end
 // In the enabled design, keep the cancel/error decode out of the reader
 // status mux. Header fields use the same registered response bundle.
 // Drain stays active until this queued response has also been consumed.
 wire control_sector_done=SCAN_PUBLICITY ? control_sector_done_q : sector_done;
 wire [7:0] control_sector_error=SCAN_PUBLICITY ? file_sector_error : sector_error;
 assign header_valid=SCAN_PUBLICITY ? header_sector_valid : state==HEADER_WAIT && sector_valid;
 assign header_byte=SCAN_PUBLICITY ? file_sector_byte : sector_byte;
 assign header_index=SCAN_PUBLICITY ? file_sector_index : sector_index;
 fat32_file_streamer #(.MAX_VISITED_CLUSTERS(SCALE_ENABLE?16384:MAX_VISITED_CLUSTERS),.DATA_GATE_ENABLE(SCALE_ENABLE)) streamer(
 .clk(clk),.rst_n(!rst && !(SCAN_PUBLICITY?abort_file_q:abort_file)),.file_start(file_go),.data_permit(data_permit),.first_cluster(task_cluster),.file_size(task_size),
 .sectors_per_cluster(spc),.fat_start_lba(fat_lba),.data_start_lba(data_lba),.max_cluster(max_cluster),
 .file_busy(stream_busy),.file_done(stream_done),.file_valid(stream_valid),.file_byte(stream_byte),.file_byte_offset(stream_offset),.fs_error(stream_error),
 .sector_req(file_req),.sector_lba(file_lba),.sector_busy(sector_busy),.sector_valid(file_sector_valid),
 .sector_byte(file_sector_byte),.sector_byte_index(file_sector_index),.sector_done(file_sector_done),.sector_error(file_sector_error));
 // Shared service retains per-client ownership through cancellation and drain.
 sd_sector_service #(.CLK_FREQ_HZ(CLK_FREQ_HZ),.TIMEOUT_MS(TIMEOUT_MS)) adapter(
 .clk(clk),.rst(rst),.p_req(scan_owner?scan_req:(file_owner?(file_req && request_allowed):header_go)),
 .p_lba(scan_owner?scan_lba:(file_owner?file_lba:header_lba)),.p_cancel(load_cancel),
 .p_busy(sector_busy),.p_accepted(),.p_valid(sector_valid),.p_done(sector_done),.p_error(sector_error),
 .a_req((SCAN_AUDIO || SCAN_TEXT || SCAN_PUBLICITY) ? a_req : 1'b0),.a_lba(a_lba),.a_cancel((SCAN_AUDIO || SCAN_TEXT || SCAN_PUBLICITY) ? a_cancel : 1'b0),.a_urgent(a_urgent),.a_enable(SCAN_AUDIO!=0 || SCAN_TEXT!=0 || SCAN_PUBLICITY!=0),
 .a_busy(a_busy),.a_accepted(),.a_valid(a_valid),.a_done(a_done),.a_error(a_error),
 .sector_byte(sector_byte),.sector_index(sector_index),
 .sd_sec_read(sd_sec_read),.sd_sec_read_addr(sd_sec_read_addr),.sd_sec_read_data(sd_sec_read_data),
 .sd_sec_read_data_valid(sd_sec_read_data_valid),.sd_sec_read_end(sd_sec_read_end),.sd_sec_read_failed(sd_sec_read_failed));
 bmp_header_check #(.ALLOW_32(1),.RANGE_DIMENSIONS(SCALE_ENABLE)) preflight(
 .clk(clk),.rst(rst || state==HEADER_RESET),.file_valid(header_valid),
 .file_byte(header_byte),.file_byte_offset({23'd0,header_index}),.bmp_width(bmp_width),.bmp_height(bmp_height),
 .file_len(header_file_len),.pixel_offset(),.width(),.height(),.required_end(required_end),.header_match(header_match),
 .skip_format(),.header_complete(),.is_32(),.row_stride(),.expected_pixels());
 generate if(SCALE_ENABLE)begin:g_scale
 bmp_scale_stream scaled(
 .clk(clk),.rst(decoder_reset),.file_start(file_go),.file_size(task_size),
 .file_valid(stream_valid && state==READ_FILE),.file_byte(stream_byte),.file_byte_offset(stream_offset),
 .file_end(stream_done),.upstream_error(stream_error),.data_permit(data_permit),
 .pixel_valid(pixel_valid),.pixel_ready(pixel_ready),.pixel_rgb(bmp_data),.done(decode_done),.error(decode_error));
 end else begin:g_fixed
 assign data_permit=1'b1;
 bmp24_decoder #(.RUNTIME_DIMENSIONS(1),.ALLOW_32(1)) decoder(
 .clk(clk),.rst(decoder_reset),.expected_width(bmp_width),.expected_height(bmp_height),
 .file_start(file_go),.file_size(task_size),.file_valid(stream_valid && state==READ_FILE),.file_byte(stream_byte),
 .file_byte_offset(stream_offset),.file_end(stream_done),.upstream_error(stream_error),
 .header_accepted(),.pixel_valid(pixel_valid),.pixel_rgb(),.pixel_rgba(bmp_data),.pixel_x(),.pixel_y(),
 .frame_commit(),.bmp_done(decode_done),.bmp_error(decode_error),
 .pixel_ready(1'b1),.file_ready(),.image_width(),.image_height());
 end endgenerate
 localparam integer WAIT_CYCLES=(CLK_FREQ_HZ/1000)*TIMEOUT_MS;
 reg [31:0] ack_wait;
 always @(posedge clk or posedge rst)begin
 if(rst)begin
 state<=IDLE;scan_go<=0;file_go<=0;header_go<=0;scan_done<=0;scan_error<=0;
 active_publicity<=0;metadata_ready<=0;mapping_ready<=0;mapped_valid<=0;scan_found_slot<=0;cancelled<=0;
 scan_found_valid<=0;scan_found_cluster<=0;scan_found_size<=0;scan_found_total<=0;
 load_done<=0;load_error<=0;bmp_error<=0;fat_error<=0;candidate<=0;
 task_cluster<=0;task_size<=0;header_lba<=0;header_shift_count<=0;found_slot[0]<=0;found_slot[1]<=0;found_slot[2]<=0;found_slot[3]<=0;io_error<=0;stream_finished<=0;decode_finished<=0;ack_wait<=0;
 end else begin
 scan_go<=0;file_go<=0;header_go<=0;scan_found_valid<=0;load_done<=0;load_error<=0;scan_error<=0;
 // Observe file errors with the same response bundle consumed by streamer.
 // This preserves the existing distinction between a retryable stream error
 // and a previously latched physical timeout.
 if((file_owner ? file_sector_done : control_sector_done) &&
    (file_owner ? file_sector_error : control_sector_error)!=0)
  io_error<=file_owner ? file_sector_error : control_sector_error;
 // Cancel and drain the current sector. Opt-in scan/preflight cancellation
 // invalidates the partial mapping; a file cancellation retains it for retry.
 if(load_cancel) begin
  if(SCAN_PUBLICITY)cancelled<=1;
  if(SCAN_PUBLICITY && state!=IDLE && state!=WRITE_WAIT && state!=START_FILE && state!=READ_FILE && state!=DRAIN && state!=RESULT)begin
   mapping_ready<=0;mapped_valid<=0;scan_done<=0;scan_found_total<=0;
   if(state==SCAN)metadata_ready<=0;
  end
  if(!sector_busy) state<=IDLE;
  else state<=DRAIN;
 end else case(state)
 IDLE:if(sd_init_done)begin
 if(scan_start)begin scan_done<=0;scan_found_total<=0;candidate<=0;fat_error<=0;bmp_error<=0;io_error<=0;scan_go<=1;state<=SCAN;cancelled<=0;
 active_publicity<=SCAN_PUBLICITY ? resource_publicity : 1'b0;metadata_ready<=0;mapping_ready<=0;mapped_valid<=0;end
 else if(SCAN_PUBLICITY && map_start && !sector_busy && !a_busy)begin
  if(metadata_ready)begin active_publicity<=resource_publicity;scan_done<=0;scan_found_total<=0;candidate<=0;mapped_valid<=0;mapping_ready<=0;fat_error<=0;bmp_error<=0;io_error<=0;state<=SELECT;cancelled<=0;end
  else begin scan_error<=1;fat_error<=8'h24;end
 end
 else if(load_start)begin
 if(LOAD_BY_INDEX)candidate<={1'b0,((SCAN_PUBLICITY && active_publicity || strict_hazard!=0)?load_index:found_slot[load_index])};
 if(!LOAD_BY_INDEX)begin task_cluster<=load_cluster;task_size<=load_size;end
 io_error<=0;fat_error<=0;bmp_error<=0;cancelled<=0;
 stream_finished<=0;decode_finished<=0;ack_wait<=0;
 if(SCAN_PUBLICITY && LOAD_BY_INDEX && !indexed_load_valid)begin bmp_error<=3;state<=RESULT;end
 else state<=LOAD_BY_INDEX?LOAD_SELECT:WRITE_WAIT;end
 end
 LOAD_SELECT:begin task_cluster<=selected_cluster;task_size<=selected_size;state<=WRITE_WAIT;end
 SCAN:if(volume_done)begin
 if(volume_error!=0)begin fat_error<=(volume_error==8'h10 && io_error!=0)?io_error:volume_error;bmp_error<=2;scan_error<=1;state<=SCAN_FINISH;end
 else begin metadata_ready<=1;state<=SELECT;end
 end
 SELECT:if(!sector_busy)begin
 if(candidate==4)state<=SCAN_FINISH;
 else begin
 task_cluster<=selected_cluster;task_size<=selected_size;
 state<=SCAN_PUBLICITY?SELECT_RANGE:SELECT_CHECK;end
 end
 SELECT_RANGE:state<=SELECT_CHECK;
 SELECT_CHECK:begin
 if(SCAN_PUBLICITY?selected_bad_q:selected_bad)begin candidate<=candidate+1'b1;state<=SELECT;end
 else begin
 header_lba<=task_cluster-2;header_shift_count<=header_cluster_shift;state<=HEADER_SHIFT;end
 end
 HEADER_SHIFT:if(header_shift_count!=0)begin header_lba<={header_lba[30:0],1'b0};header_shift_count<=header_shift_count-1'b1;end
 else state<=HEADER_ADD;
 HEADER_ADD:begin header_lba<=data_lba+header_lba;state<=HEADER_RESET;end
 HEADER_RESET:state<=HEADER_REQ;
 HEADER_REQ:if(!sector_busy)begin header_go<=1;state<=HEADER_WAIT;end
 HEADER_WAIT:if(control_sector_done)begin
 if(control_sector_error!=0)begin fat_error<=control_sector_error;bmp_error<=2;scan_error<=1;state<=SCAN_FINISH;end
 else state<=HEADER_CHECK;
 end
 HEADER_CHECK:begin
 if(header_match && (strict_hazard==0 || (header_hazard=={5'd0,strict_hazard} && header_role=={5'd0,candidate}+8'd1)) && (SCAN_PUBLICITY ? header_size_ok : required_end<={2'b0,task_size}))begin
 mapped_valid[candidate[1:0]]<=1;scan_found_slot<=candidate[1:0];
 scan_found_cluster<=task_cluster;scan_found_size<=task_size;scan_found_valid<=1;scan_found_total<=scan_found_total+1'b1;
 if(!scan_found_total[2])found_slot[scan_found_total[1:0]]<=candidate[1:0];end
 candidate<=candidate+1'b1;state<=SELECT;
 end
 SCAN_FINISH:if(!sector_busy)begin scan_done<=1;mapping_ready<=(bmp_error==0 && fat_error==0);state<=IDLE;end
 WRITE_WAIT:if(write_req_ack)state<=START_FILE;
 else if(ack_wait>=WAIT_CYCLES-1)begin bmp_error<=2;fat_error<=8'h11;state<=RESULT;end
 else ack_wait<=ack_wait+1'b1;
 START_FILE:begin file_go<=1;state<=READ_FILE;end
 READ_FILE:begin
 if(stream_done)stream_finished<=1;
 if(decode_done)decode_finished<=1;
 if(stream_error!=0)begin fat_error<=(stream_error==8'h10 && io_error!=0)?io_error:stream_error;
 bmp_error<=(stream_error==8'h10 && (io_error==8'h10 || io_error==8'h11))?3'd2:3'd3;state<=DRAIN;end
 else if(decode_error!=0)begin bmp_error<=decode_error;state<=DRAIN;end
 else if((stream_finished || stream_done) && (decode_finished || decode_done))state<=DRAIN;
 end
 DRAIN:begin
 if(control_sector_done && (control_sector_error==8'h10 || control_sector_error==8'h11))begin bmp_error<=2;fat_error<=control_sector_error;end
 if(!sector_busy && !(SCAN_PUBLICITY && sector_done))state<=(SCAN_PUBLICITY && cancelled)?IDLE:RESULT;
 end
 RESULT:begin if(bmp_error==0)load_done<=1;else load_error<=1;state<=IDLE;end
 default:state<=IDLE;
 endcase
 end end
endmodule
