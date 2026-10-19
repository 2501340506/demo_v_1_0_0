`timescale 1ns/1ps
// File boundaries do not reset this ring. play_enable goes low for stop/error/
// rescan; wait for stopped before starting a new session. Both resets belong
// to the board-wide reset; normal restarts use the four-phase run/ack handshake.
module pcm_stream_player #(
 parameter integer SINGLE_SUPPORT=0, ID_WIDTH=16,
 parameter integer ADDR_WIDTH=12, SAMPLE_HZ=48000, CLOCK_HZ=25000000,
 parameter integer PREFILL=2048, LOW_WATER=1024, HIGH_WATER=3072
)(
 input wire wr_clk,wr_rst_n,play_enable,
 input wire single_play,input wire [30:0] sample_total,input wire [ID_WIDTH-1:0] session_id,
 output wire playback_done,output wire [ID_WIDTH-1:0] done_session,
 input wire file_valid,input wire [7:0] file_byte,output wire file_ready,
 output wire sector_permit,buffer_low,output wire stopped,
 output wire [ADDR_WIDTH:0] write_level,
 input wire rd_clk,rd_rst_n,sample_ready,
 output wire sample_valid,output wire signed [15:0] sample_left,sample_right,
 output reg active,output reg [31:0] underflow_count,
 output reg output_overrun
);
 localparam integer DEPTH=1<<ADDR_WIDTH;
 reg [15:0] mem[0:DEPTH-1];
 reg [ADDR_WIDTH:0] wr_bin,rd_bin,wr_gray,rd_gray;
 reg [ADDR_WIDTH:0] rd_sync1,rd_sync2,wr_sync1,wr_sync2;
 reg run,ack,ack1,ack2,run1,run2;
 reg [1:0] stop_guard;
 // Bundled configuration is written before run crosses, and held through
 // stop ack + guard. done is a four-phase level, cleared before session reuse.
 reg single_latched;reg [30:0] total_latched;
 // Capture the stable bundle locally before run2 can start playback. Keeping
 // comparisons wholly in rd_clk avoids a wide CDC combinational path.
 reg single_rd;reg [30:0] total_rd;
 reg [ID_WIDTH-1:0] identity_latched;
 reg done_rd;(* ASYNC_REG="TRUE" *) reg [1:0] done_sync;
 assign playback_done=SINGLE_SUPPORT && run && ack2 && done_sync[1];
 assign done_session=identity_latched;
 reg lo_pending;reg [7:0] lo_byte;
 // Measured low-byte register -> sample RAM hold path; no extra clock cycle.
 wire [7:0] ram_low_byte;
 assign ram_low_byte[7:3]=lo_byte[7:3];
 assign ram_low_byte[1:0]=lo_byte[1:0];
 (* keep="true" *) AL_MAP_LUT1 #(.INIT(2'b10),.EQN("A"))
  u_sample_hold2(.o(ram_low_byte[2]),.a(lo_byte[2]));
 function [ADDR_WIDTH:0] gray;
 input [ADDR_WIDTH:0] b;begin gray=b^(b>>1);end endfunction
 function [ADDR_WIDTH:0] binary;
 input [ADDR_WIDTH:0] g;integer i;begin binary[ADDR_WIDTH]=g[ADDR_WIDTH];
 for(i=ADDR_WIDTH-1;i>=0;i=i-1)binary[i]=binary[i+1]^g[i];end endfunction
 // Delay only the decoded read pointer. It can only lag consumption, so
 // occupancy remains conservative for whole-sector admission. The Gray
 // full comparator still protects every individual write without delay.
 reg [ADDR_WIDTH:0] rd_binary_wr;
 assign write_level=wr_bin-rd_binary_wr;
 wire [ADDR_WIDTH:0] level_rd=binary(wr_sync2)-rd_bin;
 assign stopped=!run && !ack2 && stop_guard==3;
 // Standard async FIFO full test: a depth-separated binary pointer has the
 // two upper Gray bits inverted. Avoid Gray decode/subtraction on BRAM WE.
 // The writer never advances when full, so occupancy cannot exceed DEPTH.
 wire full=wr_gray=={~rd_sync2[ADDR_WIDTH:ADDR_WIDTH-1],rd_sync2[ADDR_WIDTH-2:0]};
 assign file_ready=run && play_enable && !full;
 assign sector_permit=file_ready && write_level<=DEPTH-256 && write_level<HIGH_WATER;
 assign buffer_low=write_level<LOW_WATER;
 always @(posedge wr_clk or negedge wr_rst_n)begin
  if(!wr_rst_n)begin
   wr_bin<=0;wr_gray<=0;rd_sync1<=0;rd_sync2<=0;rd_binary_wr<=0;
   single_latched<=0;total_latched<=0;identity_latched<=0;done_sync<=0;
   run<=0;ack1<=0;ack2<=0;stop_guard<=0;lo_pending<=0;lo_byte<=0;
  end else begin
   done_sync<={done_sync[0],done_rd};
   rd_sync1<=rd_gray;rd_sync2<=rd_sync1;rd_binary_wr<=binary(rd_sync2);ack1<=ack;ack2<=ack1;
   if(!run && !ack2)begin
    // Reader has drained its visible output and reset its pointer. Only now
    // can the writer reset; guard also lets the old read pointer leave CDC.
    wr_bin<=0;wr_gray<=0;lo_pending<=0;
    if(stop_guard!=3)stop_guard<=stop_guard+1'b1;
    else if(play_enable)begin
     single_latched<=SINGLE_SUPPORT && single_play;total_latched<=sample_total;
     identity_latched<=session_id;run<=1;stop_guard<=0;
    end
   end
   if(run)begin
    if(!play_enable && ack2)begin run<=0;stop_guard<=0;end
    else if(file_valid && file_ready)begin
     if(!lo_pending)begin lo_byte<=file_byte;lo_pending<=1;end
     else begin wr_bin<=wr_bin+1'b1;wr_gray<=gray(wr_bin+1'b1);lo_pending<=0;end
    end
   end
  end
 end
 // No reset on the memory array or its synchronous read register: infer BRAM.
 wire [ADDR_WIDTH-1:0] ram_write_address;
 genvar write_address_bit;
 generate for(write_address_bit=0;write_address_bit<ADDR_WIDTH;write_address_bit=write_address_bit+1)begin:g_write_hold
  // Different placements expose different bits of this direct register/RAM
  // bus (TD27 bits 3/7, TD28 bit 5). Delay every bit without adding a cycle.
   (* keep="true" *) AL_MAP_LUT1 #(.INIT(2'b10),.EQN("A"))
    u_hold(.o(ram_write_address[write_address_bit]),.a(wr_bin[write_address_bit]));
 end endgenerate
 always @(posedge wr_clk)
  if(file_valid && file_ready && lo_pending)mem[ram_write_address]<={file_byte,ram_low_byte};
 reg [15:0] ram_sample;
 reg [15:0] fifo[0:7];
 reg source_tag[0:7];reg [30:0] launched,consumed;
 reg [2:0] wp,rp;reg [3:0] count;
 reg pending,pending_zero;
 // phase stays a multiple of RATE_DIV, so it is kept divided by it; every tick is unchanged.
 localparam integer RATE_DIV=(CLOCK_HZ%8000==0 && SAMPLE_HZ%8000==0) ? 8000 : 1;
 localparam integer RATE_CLOCK=CLOCK_HZ/RATE_DIV, RATE_SAMPLE=SAMPLE_HZ/RATE_DIV;
 reg [$clog2(RATE_CLOCK)-1:0] phase;
 wire tick=phase>=RATE_CLOCK-RATE_SAMPLE;
 wire pop=sample_valid && sample_ready;
 wire room=(count+pending<8)||pop;
 wire launch=run2 && active && tick && room;
 wire source_remaining=!single_rd || launched!=total_rd;
 wire read_ram=launch && level_rd!=0 && source_remaining;
 wire push=pending && run2;
 // TD12 measured a short read-address hold path on rd_bin[9].
 // Kept identity cells add physical delay only; BRAM latency is unchanged.
 wire [ADDR_WIDTH-1:0] ram_read_address;
 genvar address_bit;
 generate for(address_bit=0;address_bit<ADDR_WIDTH;address_bit=address_bit+1)begin:g_read_hold
   (* keep="true" *) AL_MAP_LUT1 #(.INIT(2'b10),.EQN("A"))
    u_hold(.o(ram_read_address[address_bit]),.a(rd_bin[address_bit]));
 end endgenerate
 always @(posedge rd_clk)if(read_ram)ram_sample<=mem[ram_read_address];
 assign sample_valid=count!=0;
 assign sample_left=fifo[rp];assign sample_right=fifo[rp];
 always @(posedge rd_clk or negedge rd_rst_n)begin
  if(!rd_rst_n)begin
   rd_bin<=0;rd_gray<=0;wr_sync1<=0;wr_sync2<=0;run1<=0;run2<=0;ack<=0;
   active<=0;phase<=0;wp<=0;rp<=0;count<=0;pending<=0;pending_zero<=0;
   underflow_count<=0;output_overrun<=0;launched<=0;consumed<=0;done_rd<=0;single_rd<=0;total_rd<=0;
  end else begin
   run1<=run;run2<=run1;
   wr_sync1<=wr_gray;wr_sync2<=wr_sync1;
   pending<=launch;
   if(pop)begin
    rp<=rp+1'b1;
    if(single_rd && source_tag[rp])begin
     consumed<=consumed+1'b1;
     if(consumed==total_rd-1'b1)done_rd<=1;
    end
   end
   if(push)begin
    source_tag[wp]<=!pending_zero;
    fifo[wp]<=pending_zero ? 16'd0 : {ram_sample[15],ram_sample[15:1]};
    wp<=wp+1'b1;
   end
   case({push,pop})2'b10:count<=count+1'b1;2'b01:count<=count-1'b1;default:;endcase
   if(!run2)begin
    single_rd<=single_latched;total_rd<=total_latched;
    phase<=0;
    // Preserve already presented valid/data through its accepting edge.
    // Other queued samples drain (at most eight) before acknowledging stop.
    if(count==0)begin
     active<=0;ack<=0;launched<=0;consumed<=0;done_rd<=0;rd_bin<=0;rd_gray<=0;wr_sync1<=0;wr_sync2<=0;
     wp<=0;rp<=0;underflow_count<=0;output_overrun<=0;
    end
   end else begin
    ack<=1;
    if(!active)begin
     phase<=0;
     if(level_rd>=PREFILL || (single_rd && total_rd!=0 && level_rd>=total_rd))active<=1;
    end else begin
     phase<=tick ? phase+RATE_SAMPLE-RATE_CLOCK : phase+RATE_SAMPLE;
     if(tick && !room)output_overrun<=1;
     if(launch)begin
      pending_zero<=!read_ram;
      if(read_ram)begin rd_bin<=rd_bin+1'b1;rd_gray<=gray(rd_bin+1'b1);if(single_rd)launched<=launched+1'b1;end
      else if(source_remaining)underflow_count<=underflow_count+1'b1;
     end
    end
   end
  end
 end
endmodule
