`timescale 1ns/1ps
// Adapted from lesson 3. Sources are external valid/ready PCM streams:
// S6 supplies silence, S7 uses S2 test PCM, S8 supplies committed-media PCM.
module media_hdmi_audio_bridge (
    input wire pixel_clk, pixel_rst_n,
    input wire video_hsync, video_vsync, video_de,
    input wire [9:0] video_x,
    input wire [23:0] video_rgb,
    input wire select_media,
    input wire test_valid,
    output wire test_ready,
    input wire signed [15:0] test_left, test_right,
    input wire media_valid,
    output wire media_ready,
    input wire signed [15:0] media_left, media_right,
    output wire [9:0] channel0_symbol, channel1_symbol, channel2_symbol,
    output wire sequence_error,
    output wire pcm_tap_valid,
    output wire signed [15:0] pcm_tap_left, pcm_tap_right
);
    reg hs_q, vs_q, de_q;
    reg [9:0] x_q;
    reg [23:0] rgb_q;
    always @(posedge pixel_clk or negedge pixel_rst_n) begin
        if (!pixel_rst_n) begin
            hs_q<=1; vs_q<=1; de_q<=0; x_q<=0; rgb_q<=0;
        end else begin
            hs_q<=video_hsync; vs_q<=video_vsync; de_q<=video_de;
            x_q<=video_x; rgb_q<=video_de ? video_rgb : 24'd0;
        end
    end

    // Freeze selection while a presented sample is stalled, including its
    // eventual accepting edge. Unselected producers see ready=0.
    reg source_held, held_select;
    wire selected = source_held ? held_select : select_media;
    wire sample_valid = selected ? media_valid : test_valid;
    wire signed [15:0] sample_left = selected ? media_left : test_left;
    wire signed [15:0] sample_right = selected ? media_right : test_right;
    wire sample_ready;
    assign test_ready = pixel_rst_n && !selected && sample_ready;
    assign media_ready = pixel_rst_n && selected && sample_ready;
    always @(posedge pixel_clk or negedge pixel_rst_n) begin
        if (!pixel_rst_n) begin source_held<=0; held_select<=0; end
        else if (source_held) begin
            if (sample_valid && sample_ready) source_held<=0;
        end else if (sample_valid && !sample_ready) begin
            source_held<=1; held_select<=selected;
        end
    end
    hdmi_audio_symbol_core u_symbol_core (
        .pixel_clk(pixel_clk),.rst_n(pixel_rst_n),
        .video_hsync(hs_q),.video_vsync(vs_q),.video_de(de_q),
        .video_x(x_q),.video_rgb(rgb_q),
        .sample_valid(sample_valid),.sample_ready(sample_ready),
        .sample_left(sample_left),.sample_right(sample_right),
        .channel0_symbol(channel0_symbol),.channel1_symbol(channel1_symbol),
        .channel2_symbol(channel2_symbol),.sequence_error(sequence_error)
    );
    assign pcm_tap_valid = pixel_rst_n && sample_valid && sample_ready;
    assign pcm_tap_left = sample_left;
    assign pcm_tap_right = sample_right;
endmodule
