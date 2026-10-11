// FAT32 scan/preflight/load coordinator. Sector ownership changes only at idle.
module fat32_bmp_reader #(
 parameter integer CLK_FREQ_HZ=100000000, TIMEOUT_MS=500,
 parameter integer MAX_VISITED_CLUSTERS=8192
)(
 input clk,rst,sd_init_done,scan_start,load_start,load_cancel,
 input [31:0] load_cluster,load_size,
 input [15:0] bmp_width,bmp_height,
 output ready, output reg scan_done,scan_error,scan_found_valid,
 output reg [31:0] scan_found_cluster,scan_found_size,
 output reg [2:0] scan_found_total,
 output reg load_done,load_error, output reg [2:0] bmp_error,
 output reg [7:0] fat_error, output [3:0] state_code,
 output write_req,input write_req_ack,
 output bmp_data_wr_en,output [23:0] bmp_data,
 output sd_sec_read,output [31:0] sd_sec_read_addr,
 input [7:0] sd_sec_read_data,input sd_sec_read_data_valid,sd_sec_read_end,sd_sec_read_failed
);
 localparam IDLE=0,SCAN=1,SELECT=2,HEADER_RESET=3,HEADER_REQ=4,
 HEADER_WAIT=5,HEADER_CHECK=6,SCAN_FINISH=7,WRITE_WAIT=8,
 START_FILE=9,READ_FILE=10,DRAIN=11,RESULT=12,HEADER_SHIFT=13,HEADER_ADD=14;
 reg [3:0] state;
 reg scan_go,file_go;
 reg [2:0] candidate;
 reg [31:0] task_cluster,task_size,header_lba;
 reg [7:0] io_error;
 reg stream_finished,decode_finished;
 wire volume_done,volume_busy,stream_busy,stream_done,stream_valid;
 wire [7:0] volume_error,stream_error,stream_byte,spc;
 wire [31:0] fat_lba,data_lba,max_cluster,stream_offset;
 wire [3:0] mask;
 wire [31:0] clusters[0:3],sizes[0:3];
 wire scan_req,file_req;wire [31:0] scan_lba,file_lba;
 wire sector_busy,sector_valid,sector_done;
 wire [7:0] sector_byte,sector_error;wire [8:0] sector_index;
 wire scan_owner=(state==SCAN);
 wire file_owner=(state==START_FILE || state==READ_FILE || state==DRAIN);
 wire abort_file=(state==DRAIN || state==RESULT || state==IDLE || load_cancel);
 wire [2:0] decode_error;wire decode_done;
 wire request_allowed=(state==READ_FILE && decode_error==0 && !load_cancel);
 wire header_match;wire [33:0] required_end;
 wire [31:0] header_file_len;
 reg header_go;
 wire [31:0] selected_cluster=clusters[candidate[1:0]];
 wire [31:0] selected_size=sizes[candidate[1:0]];
 function [2:0] spc_shift;
 input [7:0] v;
 begin case(v) 2:spc_shift=1;4:spc_shift=2;8:spc_shift=3;16:spc_shift=4;
 32:spc_shift=5;64:spc_shift=6;128:spc_shift=7;default:spc_shift=0;endcase end
 endfunction
 assign ready=(state==IDLE && sd_init_done);
 assign state_code=(state==IDLE)?4'd1:((state<=SCAN_FINISH)?4'd2:4'd3);
 assign write_req=(state==WRITE_WAIT && !load_cancel);
 wire pixel_valid;
 assign bmp_data_wr_en=pixel_valid && state==READ_FILE && decode_error==0 && stream_error==0 && !load_cancel;
 fat32_volume_scanner #(.MAX_VISITED_CLUSTERS(MAX_VISITED_CLUSTERS)) scanner(
 .clk(clk),.rst_n(!rst),.scan_start(scan_go),.scan_busy(volume_busy),.scan_done(volume_done),.fs_error(volume_error),
 .partition_lba(),.sectors_per_cluster(spc),.fat_start_lba(fat_lba),.data_start_lba(data_lba),.max_cluster(max_cluster),
 .resource_valid(mask),.audio_found(),.audio_cluster(),.audio_size(),.resource0_cluster(clusters[0]),.resource1_cluster(clusters[1]),.resource2_cluster(clusters[2]),.resource3_cluster(clusters[3]),
 .resource0_size(sizes[0]),.resource1_size(sizes[1]),.resource2_size(sizes[2]),.resource3_size(sizes[3]),
 .sector_req(scan_req),.sector_lba(scan_lba),.sector_busy(sector_busy),.sector_valid(scan_owner && sector_valid),
 .sector_byte(sector_byte),.sector_byte_index(sector_index),.sector_done(scan_owner && sector_done),.sector_error(sector_error));
 fat32_file_streamer #(.MAX_VISITED_CLUSTERS(MAX_VISITED_CLUSTERS)) streamer(
 .clk(clk),.rst_n(!rst && !abort_file),.file_start(file_go),.data_permit(1'b1),.first_cluster(task_cluster),.file_size(task_size),
 .sectors_per_cluster(spc),.fat_start_lba(fat_lba),.data_start_lba(data_lba),.max_cluster(max_cluster),
 .file_busy(stream_busy),.file_done(stream_done),.file_valid(stream_valid),.file_byte(stream_byte),.file_byte_offset(stream_offset),.fs_error(stream_error),
 .sector_req(file_req),.sector_lba(file_lba),.sector_busy(sector_busy),.sector_valid(file_owner && sector_valid),
 .sector_byte(sector_byte),.sector_byte_index(sector_index),.sector_done(file_owner && sector_done),.sector_error(sector_error));
 // S1 keeps the service at the existing reader boundary. Its second
 // mailbox is tied off until the independently tested audio path is added.
 sd_sector_service #(.CLK_FREQ_HZ(CLK_FREQ_HZ),.TIMEOUT_MS(TIMEOUT_MS)) adapter(
 .clk(clk),.rst(rst),.p_req(scan_owner?scan_req:(file_owner?(file_req && request_allowed):header_go)),
 .p_lba(scan_owner?scan_lba:(file_owner?file_lba:header_lba)),.p_cancel(load_cancel),
 .p_busy(sector_busy),.p_accepted(),.p_valid(sector_valid),.p_done(sector_done),.p_error(sector_error),
 .a_req(1'b0),.a_lba(32'd0),.a_cancel(1'b0),.a_urgent(1'b0),.a_enable(1'b0),
 .a_busy(),.a_accepted(),.a_valid(),.a_done(),.a_error(),
 .sector_byte(sector_byte),.sector_index(sector_index),
 .sd_sec_read(sd_sec_read),.sd_sec_read_addr(sd_sec_read_addr),.sd_sec_read_data(sd_sec_read_data),
 .sd_sec_read_data_valid(sd_sec_read_data_valid),.sd_sec_read_end(sd_sec_read_end),.sd_sec_read_failed(sd_sec_read_failed));
 bmp_header_check #(.ALLOW_32(0)) preflight(
 .clk(clk),.rst(rst || state==HEADER_RESET),.file_valid(state==HEADER_WAIT && sector_valid),
 .file_byte(sector_byte),.file_byte_offset({23'd0,sector_index}),.bmp_width(bmp_width),.bmp_height(bmp_height),
 .file_len(header_file_len),.pixel_offset(),.width(),.height(),.required_end(required_end),.header_match(header_match),
 .skip_format(),.header_complete(),.is_32(),.row_stride(),.expected_pixels());
 bmp24_decoder #(.RUNTIME_DIMENSIONS(1),.ALLOW_32(0)) decoder(
 .clk(clk),.rst(rst || state==WRITE_WAIT || load_cancel),.expected_width(bmp_width),.expected_height(bmp_height),
 .file_start(file_go),.file_size(task_size),.file_valid(stream_valid && state==READ_FILE),.file_byte(stream_byte),
 .file_byte_offset(stream_offset),.file_end(stream_done),.upstream_error(stream_error),
 .header_accepted(),.pixel_valid(pixel_valid),.pixel_rgb(bmp_data),.pixel_x(),.pixel_y(),
 .frame_commit(),.bmp_done(decode_done),.bmp_error(decode_error));
 localparam integer WAIT_CYCLES=(CLK_FREQ_HZ/1000)*TIMEOUT_MS;
 reg [31:0] ack_wait;
 always @(posedge clk or posedge rst)begin
 if(rst)begin
 state<=IDLE;scan_go<=0;file_go<=0;header_go<=0;scan_done<=0;scan_error<=0;
 scan_found_valid<=0;scan_found_cluster<=0;scan_found_size<=0;scan_found_total<=0;
 load_done<=0;load_error<=0;bmp_error<=0;fat_error<=0;candidate<=0;
 task_cluster<=0;task_size<=0;header_lba<=0;io_error<=0;stream_finished<=0;decode_finished<=0;ack_wait<=0;
 end else begin
 scan_go<=0;file_go<=0;header_go<=0;scan_found_valid<=0;load_done<=0;load_error<=0;scan_error<=0;
 if(sector_done && sector_error!=0)io_error<=sector_error;
 // Cancel only the current file and drain an already issued sector. Scanner
 // geometry stays intact for a retry or the next cached image.
 if(load_cancel) begin
  if(!sector_busy) state<=IDLE;
  else state<=DRAIN;
 end else case(state)
 IDLE:if(sd_init_done)begin
 if(scan_start)begin scan_done<=0;scan_found_total<=0;candidate<=0;fat_error<=0;bmp_error<=0;io_error<=0;scan_go<=1;state<=SCAN;end
 else if(load_start)begin task_cluster<=load_cluster;task_size<=load_size;io_error<=0;fat_error<=0;bmp_error<=0;
 stream_finished<=0;decode_finished<=0;ack_wait<=0;state<=WRITE_WAIT;end
 end
 SCAN:if(volume_done)begin
 if(volume_error!=0)begin fat_error<=(volume_error==8'h10 && io_error!=0)?io_error:volume_error;bmp_error<=2;scan_error<=1;state<=SCAN_FINISH;end
 else state<=SELECT;
 end
 SELECT:if(!sector_busy)begin
 if(candidate==4)state<=SCAN_FINISH;
 else if(!mask[candidate[1:0]] || selected_size<54 || selected_cluster<2 || selected_cluster>max_cluster)candidate<=candidate+1'b1;
 else begin task_cluster<=selected_cluster;task_size<=selected_size;
 header_lba<=selected_cluster-2;state<=HEADER_SHIFT;end
 end
 HEADER_SHIFT:begin header_lba<=header_lba<<spc_shift(spc);state<=HEADER_ADD;end
 HEADER_ADD:begin header_lba<=data_lba+header_lba;state<=HEADER_RESET;end
 HEADER_RESET:state<=HEADER_REQ;
 HEADER_REQ:if(!sector_busy)begin header_go<=1;state<=HEADER_WAIT;end
 HEADER_WAIT:if(sector_done)begin
 if(sector_error!=0)begin fat_error<=sector_error;bmp_error<=2;scan_error<=1;state<=SCAN_FINISH;end
 else state<=HEADER_CHECK;
 end
 HEADER_CHECK:begin
 if(header_match && required_end<={2'b0,task_size})begin
 scan_found_cluster<=task_cluster;scan_found_size<=task_size;scan_found_valid<=1;scan_found_total<=scan_found_total+1'b1;end
 candidate<=candidate+1'b1;state<=SELECT;
 end
 SCAN_FINISH:if(!sector_busy)begin scan_done<=1;state<=IDLE;end
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
 if(sector_done && (sector_error==8'h10 || sector_error==8'h11))begin bmp_error<=2;fat_error<=sector_error;end
 if(!sector_busy)state<=RESULT;
 end
 RESULT:begin if(bmp_error==0)load_done<=1;else load_error<=1;state<=IDLE;end
 default:state<=IDLE;
 endcase
 end end
endmodule
