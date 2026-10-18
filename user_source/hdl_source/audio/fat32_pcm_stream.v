// S2 standalone audio file source. Caller holds volume geometry stable until
// stopped. Dropping enable drains a sector before resetting the FAT walker.
module fat32_pcm_stream #(
 parameter integer MAX_VISITED_CLUSTERS=8388608, SINGLE_SUPPORT=0
)(
 input wire clk,rst_n,enable,audio_found,
 input wire single_play,
 input wire [31:0] first_cluster,file_size,
 input wire [7:0] sectors_per_cluster,
 input wire [31:0] fat_start_lba,data_start_lba,max_cluster,
 input wire sector_permit,player_stopped,player_ready,
 output wire player_enable,output wire file_valid,output wire [7:0] file_byte,
 output wire stopped,output reg [7:0] error_code,output reg [31:0] loop_count,
 output wire sector_req,output wire [31:0] sector_lba,
 input wire sector_busy,sector_valid,sector_done,
 input wire [7:0] sector_byte,sector_error,input wire [8:0] sector_index
);
 localparam IDLE=0,START=1,READ=2,DRAIN=3,FAILED=4,REPLAY_REQ=5,REPLAY_OUT=6,CHECK=7,FINISHED=8,VERIFY=9;
 reg [3:0] state;
 reg single_latched;
 reg start;
 reg [31:0] cluster_latched,size_latched;
 // The start checks are registered with the latched file and decided in CHECK,
 // keeping the 32-bit range compare out of the latch enable (one extra cycle).
 reg found_latched,start_bad;
 reg cluster_hi_gt,cluster_hi_eq,cluster_lo_gt;
 wire req,busy,done,valid;wire [7:0] byte_data,fs_error;
 wire running=(state==START || state==READ);
 wire replaying=(state==REPLAY_REQ || state==REPLAY_OUT);
 reg [7:0] short_mem[0:511];
 reg [8:0] cache_write,replay_offset;
 // TD33 exposed another short replay address path. Buffer every cache
 // address bit with a kept identity cell, preserving the byte protocol.
 wire [8:0] cache_write_ram,cache_read_ram;
 reg [7:0] cached_byte;
 genvar cache_hold_bit;
 generate for(cache_hold_bit=0;cache_hold_bit<9;cache_hold_bit=cache_hold_bit+1)begin:g_cache_address_hold
  (* keep="true" *) AL_MAP_LUT1 #(.INIT(2'b10),.EQN("A"))
   u_write(.o(cache_write_ram[cache_hold_bit]),.a(cache_write[cache_hold_bit]));
  (* keep="true" *) AL_MAP_LUT1 #(.INIT(2'b10),.EQN("A"))
   u_read(.o(cache_read_ram[cache_hold_bit]),.a(replay_offset[cache_hold_bit]));
 end endgenerate
 // TD18 measured the source byte[7] -> cache BRAM data hold path.
 // Preserve the exact byte/clock protocol with a kept identity cell.
 wire [7:0] cache_byte;
 assign cache_byte[6:0]=byte_data[6:0];
 (* keep="true" *) AL_MAP_LUT1 #(.INIT(2'b10),.EQN("A"))
  u_cache_data_hold(.o(cache_byte[7]),.a(byte_data[7]));
 always @(posedge clk)begin
  if(state==READ && valid && size_latched<=512)short_mem[cache_write_ram]<=cache_byte;
  if(state==REPLAY_REQ)cached_byte<=short_mem[cache_read_ram];
 end
 assign stopped=state==IDLE && player_stopped && !sector_busy;
 assign player_enable=enable && (running || replaying || state==FINISHED);
 assign file_valid=enable && ((state==READ && valid) || state==REPLAY_OUT);
 assign file_byte=replaying?cached_byte:byte_data;
 // Do not mask an already emitted one-cycle request: it must reach the
 // service mailbox. DRAIN sees busy on the next cycle and waits for it.
 assign sector_req=req;
 fat32_file_streamer #(.MAX_VISITED_CLUSTERS(MAX_VISITED_CLUSTERS),.DATA_GATE_ENABLE(1)) source(
 .clk(clk),.rst_n(rst_n && running),.file_start(start),
 .data_permit(enable && sector_permit),.first_cluster(cluster_latched),.file_size(size_latched),
 .sectors_per_cluster(sectors_per_cluster),.fat_start_lba(fat_start_lba),.data_start_lba(data_start_lba),.max_cluster(max_cluster),
 .file_busy(busy),.file_done(done),.file_valid(valid),.file_byte(byte_data),.file_byte_offset(),.fs_error(fs_error),
 .sector_req(req),.sector_lba(sector_lba),.sector_busy(sector_busy),.sector_valid(sector_valid),
 .sector_byte(sector_byte),.sector_byte_index(sector_index),.sector_done(sector_done),.sector_error(sector_error));
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin state<=IDLE;single_latched<=0;start<=0;error_code<=0;loop_count<=0;cluster_latched<=0;size_latched<=0;found_latched<=0;start_bad<=0;cluster_hi_gt<=0;cluster_hi_eq<=0;cluster_lo_gt<=0;cache_write<=0;replay_offset<=0;end
  else begin
   start<=0;
   if(state==READ && valid)cache_write<=cache_write+1'b1;
   case(state)
    IDLE:if(enable && player_stopped && !sector_busy)begin
     error_code<=0;loop_count<=0;cache_write<=0;replay_offset<=0;
     cluster_latched<=first_cluster;size_latched<=file_size;found_latched<=audio_found;
     single_latched<=SINGLE_SUPPORT && single_play;
     start_bad<=!SINGLE_SUPPORT && (file_size==0 || file_size[0] || first_cluster<2 || first_cluster>max_cluster);
     state<=CHECK;
    end
    CHECK:if(SINGLE_SUPPORT)begin
     // The extra resource mux for VOI is settled before range validation.
     // Register independent half-word predicates in the existing CHECK cycle.
     // VERIFY combines one-bit results, preserving external/state latency.
     start_bad<=size_latched==0 || size_latched[0] || cluster_latched<2;
     cluster_hi_gt<=cluster_latched[31:16]>max_cluster[31:16];
     cluster_hi_eq<=cluster_latched[31:16]==max_cluster[31:16];
     cluster_lo_gt<=cluster_latched[15:0]>max_cluster[15:0];
     state<=VERIFY;
    end else if(!found_latched)state<=FAILED;
    else if(start_bad)begin error_code<=8'h30;state<=FAILED;end
    else state<=START;
    VERIFY:if(!found_latched)state<=FAILED;
    else if(start_bad || cluster_hi_gt || (cluster_hi_eq && cluster_lo_gt))begin error_code<=8'h30;state<=FAILED;end
    else state<=START;
    START:if(!enable)state<=DRAIN;
    else if(!busy)begin start<=1;state<=READ;end
    READ:if(!enable)state<=DRAIN;
    else if(done)begin
     if(fs_error!=0)begin error_code<=fs_error;state<=DRAIN;end
     else if(single_latched)state<=FINISHED;
     else begin loop_count<=loop_count+1'b1;state<=(size_latched<=512)?REPLAY_REQ:START;end
    end
    DRAIN:if(!sector_busy && player_stopped)begin
     if(enable)state<=FAILED;else state<=IDLE;
    end
    FINISHED:if(!enable)state<=DRAIN;
    FAILED:if(!enable && player_stopped && !sector_busy)state<=IDLE;
    REPLAY_REQ:if(!enable)state<=DRAIN;else state<=REPLAY_OUT;
    REPLAY_OUT:if(!enable)state<=DRAIN;
    else if(player_ready)begin
     // Replay is entered only with size_latched<=512, so its upper bits are zero.
     if({1'b0,replay_offset}+1'b1>=size_latched[9:0])begin replay_offset<=0;loop_count<=loop_count+1'b1;end
     else replay_offset<=replay_offset+1'b1;
     state<=REPLAY_REQ;
    end
    default:state<=IDLE;
   endcase
  end
 end
endmodule
