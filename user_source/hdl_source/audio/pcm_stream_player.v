`timescale 1ns/1ps
// S2 standalone PCM stream player. The FAT32/sector adapter supplies valid
// bytes from BGM.PCM; this module owns byte pairing, circular buffering and
// the 48 kHz consumer contract. The file source is restarted by file_start
// after EOF, allowing the caller to loop a short corpus without clearing RAM.
module pcm_stream_player #(
 parameter integer ADDR_WIDTH=13, SAMPLE_HZ=48000, CLOCK_HZ=25000000,
 parameter integer PREFILL=2048, LOW_WATER=1024
)(
 input wire wr_clk,wr_rst_n,input wire file_start,input wire file_loop,
 input wire file_valid,input wire [7:0] file_byte,input wire file_last,
 input wire file_error,output wire file_ready,
 input wire rd_clk,rd_rst_n,input wire sample_ready,
 output reg sample_valid,output reg signed [15:0] sample_left,sample_right,
 output reg active,output reg [31:0] underflow_count
);
 localparam integer DEPTH=(1<<ADDR_WIDTH);
 reg [15:0] mem[0:DEPTH-1];
 reg [ADDR_WIDTH:0] wr_bin,rd_bin; reg [ADDR_WIDTH:0] wr_gray,rd_gray;
 reg [ADDR_WIDTH:0] rd_sync1,rd_sync2,wr_sync1,wr_sync2;
 reg lo_pending; reg [7:0] lo_byte;
 reg [31:0] bytes_seen; reg source_done;
 reg [31:0] phase;
 wire [ADDR_WIDTH:0] level_wr=wr_bin-rd_sync2;
 wire [ADDR_WIDTH:0] level_rd=wr_sync2-rd_bin;
 wire [ADDR_WIDTH:0] free_wr=DEPTH-level_wr;
 wire [31:0] TICK=(CLOCK_HZ/SAMPLE_HZ);
 function [ADDR_WIDTH:0] gray(input [ADDR_WIDTH:0] b); gray=b^(b>>1); endfunction
 assign file_ready=!source_done && !file_error && (free_wr>=2);
 always @(posedge wr_clk or negedge wr_rst_n) begin
  if(!wr_rst_n) begin wr_bin<=0;wr_gray<=0;rd_sync1<=0;rd_sync2<=0;lo_pending<=0;lo_byte<=0;bytes_seen<=0;source_done<=0;active<=0;end
  else begin
   rd_sync1<=rd_gray;rd_sync2<=rd_sync1;
   if(file_start) begin wr_bin<=0;wr_gray<=0;lo_pending<=0;bytes_seen<=0;source_done<=0;active<=1;end
   if(file_valid && file_ready) begin
    bytes_seen<=bytes_seen+1;
    if(!lo_pending)begin lo_byte<=file_byte;lo_pending<=1;end
    else begin mem[wr_bin[ADDR_WIDTH-1:0]]<={file_byte,lo_byte};wr_bin<=wr_bin+1;wr_gray<=gray(wr_bin+1);lo_pending<=0;end
    if(file_last)source_done<=1;
   end
   if(file_error)begin source_done<=1;active<=0;end
  end
 end
 always @(posedge rd_clk or negedge rd_rst_n) begin
  if(!rd_rst_n)begin rd_bin<=0;rd_gray<=0;wr_sync1<=0;wr_sync2<=0;sample_valid<=0;sample_left<=0;sample_right<=0;phase<=0;underflow_count<=0;end
  else begin
   wr_sync1<=wr_gray;wr_sync2<=wr_sync1; sample_valid<=0;
   if(phase>=TICK-1)phase<=phase-(TICK-1);else phase<=phase+1;
   if(phase>=TICK-1 && sample_ready)begin
    if(level_rd!=0)begin sample_left<=mem[rd_bin[ADDR_WIDTH-1:0]];sample_right<=mem[rd_bin[ADDR_WIDTH-1:0]];rd_bin<=rd_bin+1;rd_gray<=gray(rd_bin+1);sample_valid<=1;end
    else if(active)begin sample_left<=0;sample_right<=0;sample_valid<=1;underflow_count<=underflow_count+1;end
   end
  end
 end
endmodule
