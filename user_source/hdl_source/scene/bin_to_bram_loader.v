// Sequential FONT/TEXT loader. Invalid optional resources never fail the images.
// The caller owns the sector port until done; audio starts only afterwards.
module bin_to_bram_loader #(
 parameter integer PIPELINED_METADATA=0
)(
 input clk,rst,start,input font_found,text_found,
 input [31:0] font_cluster,font_size,text_cluster,text_size,
 input [7:0] spc,input [31:0] fat_lba,data_lba,max_cluster,
 output reg done,font_valid,text_valid,output reg [7:0] font_count,
 output reg [12:0] text_bytes,
 output wr_en,wr_text,output [11:0] wr_addr,output [7:0] wr_data,
 output sector_req,output [31:0] sector_lba,
 input sector_busy,sector_valid,sector_done,input [7:0] sector_byte,sector_error,input [8:0] sector_index
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
 fat32_file_streamer #(.MAX_VISITED_CLUSTERS(8),.FILE_SIZE_BITS(13)) stream(
  .clk(clk),.rst_n(!rst),.file_start(go),.data_permit(1'b1),
  .first_cluster(PIPELINED_METADATA?selected_cluster:(is_text?text_cluster:font_cluster)),
  .file_size(PIPELINED_METADATA?{19'd0,selected_size}:(is_text?text_size:font_size)),
  .sectors_per_cluster(spc),.fat_start_lba(fat_lba),.data_start_lba(data_lba),.max_cluster(max_cluster),
  .file_busy(),.file_done(file_done),.file_valid(byte_valid),.file_byte(data),.file_byte_offset(offset),.fs_error(error),
  .sector_req(sector_req),.sector_lba(sector_lba),.sector_busy(sector_busy),.sector_valid(sector_valid),
  .sector_byte(sector_byte),.sector_byte_index(sector_index),.sector_done(sector_done),.sector_error(sector_error));
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
