// Sequential FONT/TEXT loader. Invalid optional resources never fail the images.
// The caller owns the sector port until done; audio starts only afterwards.
// File source bus (fat32_file_streamer): request {rst_n,file_start,
// data_permit,first_cluster[31:0],file_size[31:0]}, response {file_busy,
// file_done,file_valid,file_byte[7:0],file_byte_offset[31:0],fs_error[7:0]}.
// The core drives the source bus; bin_to_bram_loader below adds its streamer.
module bin_to_bram_loader_core #(
 parameter integer PIPELINED_METADATA=0
)(
 input clk,rst,start,input font_found,text_found,
 input [31:0] font_cluster,font_size,text_cluster,text_size,
 output reg done,font_valid,text_valid,output reg [7:0] font_count,
 output reg [12:0] text_bytes,
 output wr_en,wr_text,output [11:0] wr_addr,output [7:0] wr_data,
 output [66:0] source_request,input [50:0] source_response
);
 localparam IDLE=0,FONT_START=1,FONT_WAIT=2,TEXT_START=3,TEXT_WAIT=4,FINISH=5,FONT_SELECT=6,TEXT_SELECT=7;
 reg [2:0] state;
 reg [31:0] selected_cluster;
 reg [12:0] selected_size;
 reg selected_ok;
 wire is_text=state==TEXT_START || state==TEXT_WAIT;
 wire go=PIPELINED_METADATA ? ((state==FONT_START || state==TEXT_START) && selected_ok) :
         ((state==FONT_START && font_found && font_size>=416 && font_size<=4096 && font_size[4:0]==0) ||
         (state==TEXT_START && text_found && text_size>=44 && text_size<=4096));
 wire byte_valid,file_done;wire [7:0] data,error;wire [31:0] offset;
 assign source_request={!rst,go,1'b1,
  PIPELINED_METADATA?selected_cluster:(is_text?text_cluster:font_cluster),
  PIPELINED_METADATA?{19'd0,selected_size}:(is_text?text_size:font_size)};
 assign {file_done,byte_valid,data,offset,error}=source_response[49:0];
 assign wr_en=byte_valid && (state==FONT_WAIT || state==TEXT_WAIT) && offset<4096;
 assign wr_text=is_text;assign wr_addr=offset[11:0];assign wr_data=data;
 always @(posedge clk or posedge rst)begin
  if(rst)begin state<=IDLE;done<=0;font_valid<=0;text_valid<=0;font_count<=0;text_bytes<=0;selected_cluster<=0;selected_size<=0;selected_ok<=0;end
  else begin
   done<=0;
   case(state)
    IDLE:if(start)begin font_valid<=0;text_valid<=0;font_count<=0;text_bytes<=0;state<=PIPELINED_METADATA?FONT_SELECT:FONT_START;end
    // Snapshot selection and eligibility before the stream acceptance edge.
    // Keep the old cycle sequence when the new application is disabled.
    FONT_SELECT:begin
     selected_cluster<=font_cluster;selected_size<=font_size[12:0];
     selected_ok<=font_found && font_size>=416 && font_size<=4096 && font_size[4:0]==0;
     state<=FONT_START;
    end
    TEXT_SELECT:begin
     selected_cluster<=text_cluster;selected_size<=text_size[12:0];
     selected_ok<=text_found && text_size>=44 && text_size<=4096;
     state<=TEXT_START;
    end
    FONT_START:state<=go?FONT_WAIT:(PIPELINED_METADATA?TEXT_SELECT:TEXT_START);
    FONT_WAIT:if(file_done)begin font_valid<=error==0;font_count<=PIPELINED_METADATA?selected_size[12:5]:font_size[12:5];state<=PIPELINED_METADATA?TEXT_SELECT:TEXT_START;end
    TEXT_START:state<=go?TEXT_WAIT:FINISH;
    TEXT_WAIT:if(file_done)begin text_valid<=error==0;text_bytes<=PIPELINED_METADATA?selected_size:text_size[12:0];state<=FINISH;end
    FINISH:begin done<=1;state<=IDLE;end
    default:state<=IDLE;
   endcase
  end
 end
endmodule

// Stand-alone loader: the core with its own file streamer. Accepted files are
// at most 4096 bytes, so they span at most eight clusters (13 size bits).
module bin_to_bram_loader #(
 parameter integer PIPELINED_METADATA=0
)(
 input clk,rst,start,input font_found,text_found,
 input [31:0] font_cluster,font_size,text_cluster,text_size,
 input [7:0] spc,input [31:0] fat_lba,data_lba,max_cluster,
 output done,font_valid,text_valid,output [7:0] font_count,
 output [12:0] text_bytes,
 output wr_en,wr_text,output [11:0] wr_addr,output [7:0] wr_data,
 output sector_req,output [31:0] sector_lba,
 input sector_busy,sector_valid,sector_done,input [7:0] sector_byte,sector_error,input [8:0] sector_index
);
 wire [66:0] source_request;wire [50:0] source_response;
 bin_to_bram_loader_core #(.PIPELINED_METADATA(PIPELINED_METADATA)) core(
  .clk(clk),.rst(rst),.start(start),.font_found(font_found),.text_found(text_found),
  .font_cluster(font_cluster),.font_size(font_size),.text_cluster(text_cluster),.text_size(text_size),
  .done(done),.font_valid(font_valid),.text_valid(text_valid),.font_count(font_count),.text_bytes(text_bytes),
  .wr_en(wr_en),.wr_text(wr_text),.wr_addr(wr_addr),.wr_data(wr_data),
  .source_request(source_request),.source_response(source_response));
 fat32_source_streamer #(.MAX_VISITED_CLUSTERS(8),.FILE_SIZE_BITS(13)) stream(
  .clk(clk),.request(source_request),.response(source_response),
  .sectors_per_cluster(spc),.fat_start_lba(fat_lba),.data_start_lba(data_lba),.max_cluster(max_cluster),
  .sector_req(sector_req),.sector_lba(sector_lba),.sector_busy(sector_busy),.sector_valid(sector_valid),
  .sector_byte(sector_byte),.sector_index(sector_index),.sector_done(sector_done),.sector_error(sector_error));
endmodule
