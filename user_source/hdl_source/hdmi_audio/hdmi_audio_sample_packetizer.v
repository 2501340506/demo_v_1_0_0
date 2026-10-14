`timescale 1ns/1ps

module hdmi_audio_sample_packetizer (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_valid,
    output wire               sample_ready,
    input  wire signed [15:0] sample_left,
    input  wire signed [15:0] sample_right,
    output reg                packet_valid,
    input  wire               packet_ready,
    output reg  [23:0]        packet_header,
    output wire [7:0]         packet_header_ecc,
    output reg  [223:0]       packet_body,
    output reg  [31:0]        packet_body_ecc,
    output reg  [7:0]         packet_frame_base
);
    reg [1:0] collect_count;
    reg [7:0] next_audio_frame_base;
    reg signed [15:0] left0, left1, left2;
    reg signed [15:0] right0, right1, right2;
    reg [7:0] pending_ecc0, pending_ecc1, pending_ecc2;

    assign sample_ready = !packet_valid;

    function [55:0] make_subpacket;
        input signed [15:0] left_sample;
        input signed [15:0] right_sample;
        input channel_status;
        reg [23:0] left_word;
        reg [23:0] right_word;
        reg left_parity;
        reg right_parity;
        begin
            // 16-bit LPCM is left-justified in the 24-bit IEC 60958 sample
            // word. C[25]=1 declares 48 kHz and C[33]=1 declares 16-bit;
            // all other bits in this minimal consumer status block are zero.
            left_word = {left_sample, 8'h00};
            right_word = {right_sample, 8'h00};
            left_parity = ^{left_word, channel_status};
            right_parity = ^{right_word, channel_status};
            make_subpacket[7:0] = left_word[7:0];
            make_subpacket[15:8] = left_word[15:8];
            make_subpacket[23:16] = left_word[23:16];
            make_subpacket[31:24] = right_word[7:0];
            make_subpacket[39:32] = right_word[15:8];
            make_subpacket[47:40] = right_word[23:16];
            // Control nibble order is P/C/U/V for right then left.
            make_subpacket[55:48] =
                {right_parity, channel_status, 2'b00,
                 left_parity, channel_status, 2'b00};
        end
    endfunction

    // The frame base starts at 0 and steps by 4, so frames 25 and 33 can only
    // be the second subpacket of the packets based at 24 and 32.
    wire status_frame_base = (next_audio_frame_base == 8'd24) ||
                             (next_audio_frame_base == 8'd32);
    // BCH is computed once per accepted sample on the subpacket it will
    // occupy; the four results are published together with packet_body.
    wire [55:0] incoming_subpacket =
        make_subpacket(sample_left, sample_right,
                       collect_count == 2'd1 && status_frame_base);
    wire [7:0] incoming_ecc;

    hdmi_bch8 #(.DATA_BYTES(3)) u_header_bch (
        .data(packet_header), .ecc(packet_header_ecc)
    );
    hdmi_bch8 #(.DATA_BYTES(7)) u_subpacket_bch (
        .data(incoming_subpacket), .ecc(incoming_ecc)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            collect_count <= 2'd0;
            packet_valid <= 1'b0;
            packet_header <= 24'd0;
            packet_body <= 224'd0;
            packet_body_ecc <= 32'd0;
            packet_frame_base <= 8'd0;
            next_audio_frame_base <= 8'd0;
            left0 <= 16'sd0;
            left1 <= 16'sd0;
            left2 <= 16'sd0;
            right0 <= 16'sd0;
            right1 <= 16'sd0;
            right2 <= 16'sd0;
            pending_ecc0 <= 8'd0;
            pending_ecc1 <= 8'd0;
            pending_ecc2 <= 8'd0;
        end else if (packet_valid) begin
            if (packet_ready)
                packet_valid <= 1'b0;
        end else if (sample_valid) begin
            case (collect_count)
                2'd0: begin
                    left0 <= sample_left;
                    right0 <= sample_right;
                    pending_ecc0 <= incoming_ecc;
                    collect_count <= 2'd1;
                end
                2'd1: begin
                    left1 <= sample_left;
                    right1 <= sample_right;
                    pending_ecc1 <= incoming_ecc;
                    collect_count <= 2'd2;
                end
                2'd2: begin
                    left2 <= sample_left;
                    right2 <= sample_right;
                    pending_ecc2 <= incoming_ecc;
                    collect_count <= 2'd3;
                end
                default: begin
                    // Low byte is HB0. Layout=0 and all four subpackets are
                    // present. HB2.B0 marks the first IEC status block frame.
                    packet_header <=
                                      {(next_audio_frame_base == 0) ?
                                            8'h10 : 8'h00,
                                       8'h0f, 8'h02};
                    packet_body <= {
                        incoming_subpacket,
                        make_subpacket(left2, right2, 1'b0),
                        make_subpacket(left1, right1, status_frame_base),
                        make_subpacket(left0, right0, 1'b0)
                    };
                    packet_body_ecc <= {incoming_ecc, pending_ecc2,
                                        pending_ecc1, pending_ecc0};
                    packet_frame_base <= next_audio_frame_base;
                    packet_valid <= 1'b1;
                    collect_count <= 2'd0;
                    if (next_audio_frame_base == 8'd188)
                        next_audio_frame_base <= 8'd0;
                    else
                        next_audio_frame_base <=
                            next_audio_frame_base + 8'd4;
                end
            endcase
        end
    end
endmodule
