module bmp_header_check #(parameter ALLOW_32=0, parameter RANGE_DIMENSIONS=0) (
 input clk,rst,file_valid, input [7:0] file_byte, input [31:0] file_byte_offset,
 input [15:0] bmp_width,bmp_height,
 output reg [31:0] file_len,pixel_offset,width,height,
 output reg [33:0] required_end, output header_match,skip_format, output reg header_complete,
 output wire is_32, output reg [31:0] row_stride,
 output reg [31:0] expected_pixels
);
reg header_0_is_b;
reg header_1_is_m;




reg bit_count_24, bit_count_32, bit_count_hi_zero;
reg [3:0] compression_zero;
reg [31:0] dib_size;
reg [1:0] planes_one;

// Header fields settle long before the 512-byte sector completes. Pipeline
// arithmetic/checks so the scan/load decision is not a wide combinational chain.

reg [33:0] expected_bytes;

reg [32:0] dib_end;
reg header_format_ok;
reg header_bounds_ok;
reg [35:0] candidate_end;
// Registered half-word comparisons settle before header_complete (byte 53).
// All dependent fields finish by byte 33; no header decision is delayed.
reg offset_hi_gt_dib,offset_hi_eq_dib,offset_lo_ge_dib;
reg offset_hi_lt_len,offset_hi_eq_len,offset_lo_lt_len;
reg len_hi_gt_end,len_hi_eq_end,len_lo_ge_end;
reg len_hi_gt_candidate,len_hi_eq_candidate,len_lo_ge_candidate;
wire offset_after_dib=offset_hi_gt_dib || (offset_hi_eq_dib && offset_lo_ge_dib);
wire offset_before_len=offset_hi_lt_len || (offset_hi_eq_len && offset_lo_lt_len);
always @(posedge clk or posedge rst)begin
 if(rst)begin
  offset_hi_gt_dib<=0;offset_hi_eq_dib<=0;offset_lo_ge_dib<=0;
  offset_hi_lt_len<=0;offset_hi_eq_len<=0;offset_lo_lt_len<=0;
  len_hi_gt_end<=0;len_hi_eq_end<=0;len_lo_ge_end<=0;
  len_hi_gt_candidate<=0;len_hi_eq_candidate<=0;len_lo_ge_candidate<=0;
 end else begin
  offset_hi_gt_dib<={1'b0,pixel_offset[31:16]}>dib_end[32:16];
  offset_hi_eq_dib<={1'b0,pixel_offset[31:16]}==dib_end[32:16];
  offset_lo_ge_dib<=pixel_offset[15:0]>=dib_end[15:0];
  offset_hi_lt_len<=pixel_offset[31:16]<file_len[31:16];
  offset_hi_eq_len<=pixel_offset[31:16]==file_len[31:16];
  offset_lo_lt_len<=pixel_offset[15:0]<file_len[15:0];
  len_hi_gt_end<={2'b00,file_len[31:16]}>required_end[33:16];
  len_hi_eq_end<={2'b00,file_len[31:16]}==required_end[33:16];
  len_lo_ge_end<=file_len[15:0]>=required_end[15:0];
  len_hi_gt_candidate<={4'b0000,file_len[31:16]}>candidate_end[35:16];
  len_hi_eq_candidate<={4'b0000,file_len[31:16]}==candidate_end[35:16];
  len_lo_ge_candidate<=file_len[15:0]>=candidate_end[15:0];
 end
end
wire [15:0] calc_width = RANGE_DIMENSIONS ? width[15:0] : bmp_width;
wire [15:0] calc_height = RANGE_DIMENSIONS ? height[15:0] : bmp_height;
// Explicit shift/add avoids a constant DSP multiply feeding the row*height
// DSP input in one clock (TD30 measured critical path). 18 bits cover 3*65535+3.
wire [17:0] row_24 = {2'b00,calc_width}+{1'b0,calc_width,1'b0};
wire [17:0] candidate_row_24 = {2'b00,width[15:0]}+{1'b0,width[15:0],1'b0};
wire dimensions_ok = RANGE_DIMENSIONS ?
    (width != 0 && height != 0 &&
     ((width <= 1920 && height <= 1080) || (width <= 1080 && height <= 1920))) :
    (width == {16'd0,bmp_width} && height == {16'd0,bmp_height});

assign is_32=ALLOW_32 && bit_count_32 && bit_count_hi_zero;
always @(posedge clk or posedge rst) begin
 if(rst) header_complete<=0;
 else if(file_valid && file_byte_offset==0) header_complete<=0;
 else if(file_valid && file_byte_offset==53) header_complete<=1;
end
reg [18:0] candidate_row_bytes;
reg [34:0] candidate_data_bytes;
reg candidate_structure_ok,candidate_length_ok;
assign skip_format=candidate_structure_ok && candidate_length_ok && header_complete;
// Conservative fast path for ordinary contiguous, uncompressed 24/32-bit BMPs.
// Unknown formats or untrustworthy lengths retain the one-sector search.
always @(posedge clk or posedge rst) begin
    if (rst) begin
        candidate_row_bytes <= 0;
        candidate_data_bytes <= 0;
        candidate_end <= 0;
        candidate_structure_ok <= 0;
        candidate_length_ok <= 0;

    end else begin
        candidate_row_bytes <= (bit_count_32 && bit_count_hi_zero) ?
                               {1'b0, width[15:0], 2'b00} :
                               {1'b0,((candidate_row_24 + 18'd3) & 18'h3fffc)};
        candidate_data_bytes <= {16'd0, candidate_row_bytes} * {19'd0, height[15:0]};
        candidate_end <= {4'd0, pixel_offset} + {1'b0, candidate_data_bytes};
        candidate_structure_ok <= header_0_is_b && header_1_is_m &&
                                  (dib_size >= 40) && (&planes_one) &&
                                  (width[31:16] == 0) && (width[15:0] != 0) &&
                                  (height[31:16] == 0) && (height[15:0] != 0) &&
                                  ((bit_count_24 && bit_count_hi_zero) || (bit_count_32 && bit_count_hi_zero)) && (&compression_zero);
        candidate_length_ok <= offset_after_dib && offset_before_len &&
                               (len_hi_gt_candidate || (len_hi_eq_candidate && len_lo_ge_candidate));

    end
end


assign header_match = header_format_ok && header_bounds_ok && header_complete;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        expected_pixels <= 0;
        expected_bytes <= 0;row_stride<=0;
        required_end <= 0;
        dib_end <= 0;
        header_format_ok <= 0;
        header_bounds_ok <= 0;
    end else begin
        expected_pixels <= {16'd0, calc_width} * {16'd0, calc_height};
        row_stride <= is_32 ? {14'd0,calc_width,2'b00} :
                              {14'd0,((row_24+18'd3)&18'h3fffc)};
        expected_bytes <= {2'b00,row_stride} * calc_height;
        required_end <= {2'b00, pixel_offset} + expected_bytes;
        dib_end <= {1'b0, dib_size} + 33'd14;
        header_format_ok <= header_0_is_b && header_1_is_m &&
                            (dib_size >= 32'd40) && (&planes_one) &&
                            dimensions_ok &&
                            ((bit_count_24 && bit_count_hi_zero) || is_32) && (&compression_zero);
        header_bounds_ok <= offset_after_dib && offset_before_len &&
                            (len_hi_gt_end || (len_hi_eq_end && len_lo_ge_end));
    end
end
always @(posedge clk or posedge rst) begin
    if (rst) begin
        header_0_is_b <= 1'b0;
        header_1_is_m <= 1'b0;
        file_len     <= 32'd0;
        pixel_offset <= 32'd54;
        width        <= 32'd0;
        height       <= 32'd0;
        bit_count_24 <= 1'b0;
        bit_count_32 <= 1'b0;
        bit_count_hi_zero <= 1'b1;
        compression_zero <= 4'b1111;
        dib_size     <= 32'd0;
        planes_one <= 2'b10;
    end else if (file_valid) begin
        case (file_byte_offset)
            10'd0 : header_0_is_b <= (file_byte == "B");
            10'd1 : header_1_is_m <= (file_byte == "M");

            10'd2 : file_len[7:0] <= file_byte;
            10'd3 : file_len[15:8] <= file_byte;
            10'd4 : file_len[23:16] <= file_byte;
            10'd5 : file_len[31:24] <= file_byte;

            10'd10: pixel_offset[7:0] <= file_byte;
            10'd11: pixel_offset[15:8] <= file_byte;
            10'd12: pixel_offset[23:16] <= file_byte;
            10'd13: pixel_offset[31:24] <= file_byte;

            10'd14: dib_size[7:0] <= file_byte;
            10'd15: dib_size[15:8] <= file_byte;
            10'd16: dib_size[23:16] <= file_byte;
            10'd17: dib_size[31:24] <= file_byte;

            10'd18: width[7:0] <= file_byte;
            10'd19: width[15:8] <= file_byte;
            10'd20: width[23:16] <= file_byte;
            10'd21: width[31:24] <= file_byte;

            10'd22: height[7:0] <= file_byte;
            10'd23: height[15:8] <= file_byte;
            10'd24: height[23:16] <= file_byte;
            10'd25: height[31:24] <= file_byte;

            10'd26: planes_one[0] <= (file_byte == 8'd1);
            10'd27: planes_one[1] <= (file_byte == 8'd0);

            10'd28: begin
                bit_count_24 <= (file_byte == 8'd24);
                bit_count_32 <= (file_byte == 8'd32);
            end
            10'd29: bit_count_hi_zero <= (file_byte == 8'd0);

            10'd30: compression_zero[0] <= (file_byte == 8'd0);
            10'd31: compression_zero[1] <= (file_byte == 8'd0);
            10'd32: compression_zero[2] <= (file_byte == 8'd0);
            10'd33: compression_zero[3] <= (file_byte == 8'd0);
            default: ;
        endcase
    end
end

endmodule
