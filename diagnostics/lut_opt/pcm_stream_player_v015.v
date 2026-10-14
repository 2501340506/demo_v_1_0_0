`timescale 1ns/1ps
// File boundaries do not reset this ring. play_enable goes low for stop/error/
// rescan; wait for stopped before starting a new session. Both resets belong
// to the board-wide reset; normal restarts use the four-phase run/ack handshake.
module pcm_stream_player_v015 #(
 parameter integer ADDR_WIDTH=12, SAMPLE_HZ=48000, CLOCK_HZ=25000000,
 parameter integer PREFILL=2048, LOW_WATER=1024, HIGH_WATER=3072
)(
 input wire wr_clk,wr_rst_n,play_enable,
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
 reg lo_pending;reg [7:0] lo_byte;
 function [ADDR_WIDTH:0] gray;
 input [ADDR_WIDTH:0] b;begin gray=b^(b>>1);end endfunction
 function [ADDR_WIDTH:0] binary;
 input [ADDR_WIDTH:0] g;integer i;begin binary[ADDR_WIDTH]=g[ADDR_WIDTH];
 for(i=ADDR_WIDTH-1;i>=0;i=i-1)binary[i]=binary[i+1]^g[i];end endfunction
 assign write_level=wr_bin-binary(rd_sync2);
 wire [ADDR_WIDTH:0] level_rd=binary(wr_sync2)-rd_bin;
 assign stopped=!run && !ack2 && stop_guard==3;
 assign file_ready=run && play_enable && write_level<DEPTH;
 assign sector_permit=file_ready && write_level<=DEPTH-256 && write_level<HIGH_WATER;
 assign buffer_low=write_level<LOW_WATER;
 always @(posedge wr_clk or negedge wr_rst_n)begin
  if(!wr_rst_n)begin
   wr_bin<=0;wr_gray<=0;rd_sync1<=0;rd_sync2<=0;
   run<=0;ack1<=0;ack2<=0;stop_guard<=0;lo_pending<=0;lo_byte<=0;
  end else begin
   rd_sync1<=rd_gray;rd_sync2<=rd_sync1;ack1<=ack;ack2<=ack1;
   if(!run && !ack2)begin
    // Reader has drained its visible output and reset its pointer. Only now
    // can the writer reset; guard also lets the old read pointer leave CDC.
    wr_bin<=0;wr_gray<=0;lo_pending<=0;
    if(stop_guard!=3)stop_guard<=stop_guard+1'b1;
    else if(play_enable)begin run<=1;stop_guard<=0;end
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
 always @(posedge wr_clk)
  if(file_valid && file_ready && lo_pending)mem[wr_bin[ADDR_WIDTH-1:0]]<={file_byte,lo_byte};
 reg [15:0] ram_sample;
 reg [15:0] fifo[0:7];
 reg [2:0] wp,rp;reg [3:0] count;
 reg pending,pending_zero;
 reg [31:0] phase;
 wire tick=phase>=CLOCK_HZ-SAMPLE_HZ;
 wire pop=sample_valid && sample_ready;
 wire room=(count+pending<8)||pop;
 wire launch=run2 && active && tick && room;
 wire read_ram=launch && level_rd!=0;
 wire push=pending && run2;
 always @(posedge rd_clk)if(read_ram)ram_sample<=mem[rd_bin[ADDR_WIDTH-1:0]];
 assign sample_valid=count!=0;
 assign sample_left=fifo[rp];assign sample_right=fifo[rp];
 always @(posedge rd_clk or negedge rd_rst_n)begin
  if(!rd_rst_n)begin
   rd_bin<=0;rd_gray<=0;wr_sync1<=0;wr_sync2<=0;run1<=0;run2<=0;ack<=0;
   active<=0;phase<=0;wp<=0;rp<=0;count<=0;pending<=0;pending_zero<=0;
   underflow_count<=0;output_overrun<=0;
  end else begin
   run1<=run;run2<=run1;
   wr_sync1<=wr_gray;wr_sync2<=wr_sync1;
   pending<=launch;
   if(pop)rp<=rp+1'b1;
   if(push)begin
    fifo[wp]<=pending_zero ? 16'd0 : {ram_sample[15],ram_sample[15:1]};
    wp<=wp+1'b1;
   end
   case({push,pop})2'b10:count<=count+1'b1;2'b01:count<=count-1'b1;default:;endcase
   if(!run2)begin
    phase<=0;
    // Preserve already presented valid/data through its accepting edge.
    // Other queued samples drain (at most eight) before acknowledging stop.
    if(count==0)begin
     active<=0;ack<=0;rd_bin<=0;rd_gray<=0;wr_sync1<=0;wr_sync2<=0;
     wp<=0;rp<=0;underflow_count<=0;output_overrun<=0;
    end
   end else begin
    ack<=1;
    if(!active)begin
     phase<=0;
     if(level_rd>=PREFILL)active<=1;
    end else begin
     if(tick)phase<=phase+SAMPLE_HZ-CLOCK_HZ;else phase<=phase+SAMPLE_HZ;
     if(tick && !room)output_overrun<=1;
     if(launch)begin
      pending_zero<=level_rd==0;
      if(level_rd!=0)begin rd_bin<=rd_bin+1'b1;rd_gray<=gray(rd_bin+1'b1);end
      else underflow_count<=underflow_count+1'b1;
     end
    end
   end
  end
 end
endmodule
