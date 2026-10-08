module bmp_header_check #(parameter ALLOW_32=0) (
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

assign is_32=ALLOW_32 && bit_count_32 && bit_count_hi_zero;
always @(posedge clk or posedge rst) begin
 if(rst) header_complete<=0;
 else if(file_valid && file_byte_offset==0) header_complete<=0;
 else if(file_valid && file_byte_offset==53) header_complete<=1;
end
reg [18:0] candidate_row_bytes;
reg [34:0] candidate_data_bytes;
reg [35:0] candidate_end;
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
                               (({3'b000, width[15:0]} * 19'd3 + 19'd3) & 19'h7fffc);
        candidate_data_bytes <= {16'd0, candidate_row_bytes} * {19'd0, height[15:0]};
        candidate_end <= {4'd0, pixel_offset} + {1'b0, candidate_data_bytes};
        candidate_structure_ok <= header_0_is_b && header_1_is_m &&
                                  (dib_size >= 40) && (&planes_one) &&
                                  (width[31:16] == 0) && (width[15:0] != 0) &&
                                  (height[31:16] == 0) && (height[15:0] != 0) &&
                                  ((bit_count_24 && bit_count_hi_zero) || (bit_count_32 && bit_count_hi_zero)) && (&compression_zero);
        candidate_length_ok <= ({1'b0, pixel_offset} >= dib_end) &&
                               (pixel_offset < file_len) && ({4'd0, file_len} >= candidate_end);

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
        expected_pixels <= {16'd0, bmp_width} * {16'd0, bmp_height};
        row_stride <= is_32 ? ({16'd0,bmp_width}*4) : (({16'd0,bmp_width}*3+3)&32'hfffffffc);
        expected_bytes <= {2'b00,row_stride} * bmp_height;
        required_end <= {2'b00, pixel_offset} + expected_bytes;
        dib_end <= {1'b0, dib_size} + 33'd14;
        header_format_ok <= header_0_is_b && header_1_is_m &&
                            (dib_size >= 32'd40) && (&planes_one) &&
                            (width == {16'd0, bmp_width}) &&
                            (height == {16'd0, bmp_height}) &&
                            ((bit_count_24 && bit_count_hi_zero) || is_32) && (&compression_zero);
        header_bounds_ok <= ({1'b0, pixel_offset} >= dib_end) &&
                            (pixel_offset < file_len) &&
                            ({2'b00, file_len} >= required_end);
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
