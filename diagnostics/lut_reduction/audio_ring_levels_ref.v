// Actual accepted PCM only. 128 slots leave 32 spare while copying 96 entries.
module audio_ring_levels_ref(
 input wire clk, rst, frame_start, pcm_valid,
 input wire signed [15:0] pcm_left, pcm_right,
 input wire [6:0] bar_index,
 output wire [4:0] bar_height
);
 wire [15:0] left_abs = pcm_left[15] ? (~pcm_left + 16'd1) : pcm_left;
 wire [15:0] right_abs = pcm_right[15] ? (~pcm_right + 16'd1) : pcm_right;
 wire [15:0] magnitude = left_abs > right_abs ? left_abs : right_abs;
 reg [15:0] peak;
 wire [15:0] next_peak = magnitude > peak ? magnitude : peak;
 wire [4:0] level = next_peak[15:9] > 28 ? 5'd28 : next_peak[13:9];
 reg [4:0] sample_count;
 reg [6:0] write_pointer, history_count;
 reg [4:0] history [0:127];
 reg [4:0] heights [0:95];
 reg seen_sample;
 reg copying, copy_valid, copy_zero;
 reg [6:0] copy_pointer, copy_index, missing, result_index;
 reg [4:0] history_q;
 reg result_zero;
 integer i;
 assign bar_height = bar_index < 96 ? heights[bar_index] : 5'd0;
 // Read port has a synchronous RAM latency; unwritten entries are masked.
 always @(posedge clk) history_q <= history[copy_pointer];
 always @(posedge clk) begin
  if (pcm_valid && !rst && sample_count == 31) history[write_pointer] <= level;
 end
 always @(posedge clk or posedge rst) begin
  if (rst) begin
   peak<=0; sample_count<=0; write_pointer<=0; history_count<=0; seen_sample<=0;
   copying<=0; copy_valid<=0; copy_zero<=1; copy_pointer<=0; copy_index<=0;
   missing<=96; result_index<=0; result_zero<=1;
   for(i=0;i<96;i=i+1) heights[i]<=0;
  end else begin
   if(pcm_valid) begin
    seen_sample<=1;
    if(sample_count==31) begin
     peak<=0; sample_count<=0; write_pointer<=write_pointer+1'b1;
     if(history_count<96) history_count<=history_count+1'b1;
    end else begin peak<=next_peak; sample_count<=sample_count+1'b1; end
   end
   if(frame_start) begin
    seen_sample<=pcm_valid;
    copying<=1; copy_pointer<=write_pointer-7'd96; copy_index<=0;
    missing<=7'd96-history_count; copy_zero<=!seen_sample;
   end else if(copying) begin
    copy_pointer<=copy_pointer+1'b1;
    if(copy_index==95) copying<=0;
    else copy_index<=copy_index+1'b1;
   end
   copy_valid<=copying;
   result_index<=copy_index;
   result_zero<=copy_zero || copy_index<missing;
   if(copy_valid) begin
    if(!result_zero && history_q >= heights[result_index]) heights[result_index]<=history_q;
    else if(heights[result_index]>3) begin
     if(!result_zero && history_q > heights[result_index]-5'd3) heights[result_index]<=history_q;
     else heights[result_index]<=heights[result_index]-5'd3;
    end else heights[result_index]<=result_zero ? 5'd0 : history_q;
   end
  end
 end
endmodule
