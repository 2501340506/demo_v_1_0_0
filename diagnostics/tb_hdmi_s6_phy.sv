`timescale 1ns/1ps
module tb_hdmi_s6_phy;
    parameter integer SILENCE = 1;
    reg clk=0,serial=0,rst=1;
    always #20 clk=~clk;
    initial begin #1;forever #4 serial=~serial;end
    wire hs0,vs0,de0,hs,vs,de,read_en,request;
    wire [9:0] x0,x,c0,c1,c2;
    wire [23:0] rgb;
    reg [23:0] read_data=0;
    video_timing_data timing(.video_clk(clk),.rst(rst),.read_req(request),
        .read_req_ack(request),.hs(hs0),.vs(vs0),.de(de0),.video_x(x0));
    video_delay delay_line(.video_clk(clk),.rst(rst),.read_en(read_en),
        .read_data(read_data),.hs(hs0),.vs(vs0),.de(de0),.video_x(x0),
        .hs_r(hs),.vs_r(vs),.de_r(de),.vout_data(rgb),.video_x_r(x));
    integer source_index=0;
    function [23:0] pixel(input integer n);
        pixel={n[7:0],n[15:8],n[7:0]^8'h96};
    endfunction
    always @(posedge clk) begin
        if(rst) begin source_index=0;read_data<=0;end
        else if(read_en) begin
            read_data<=pixel(source_index);
            source_index=(source_index+1)%307200;
        end
    end
    wire valid,ready,overflow,tap,sequence_error;
    wire signed [15:0] tap_l,tap_r,source_l,source_r;
    pcm_test_tone pacing(.clk(clk),.rst_n(~rst),.enable(1'b1),
        .sample_valid(valid),.sample_ready(ready),.sample_left(source_l),.sample_right(source_r),
        .sample_tick(),.overflow(overflow));
    media_hdmi_audio_bridge bridge(.pixel_clk(clk),.pixel_rst_n(~rst),
        .video_hsync(hs),.video_vsync(vs),.video_de(de),.video_x(x),.video_rgb(rgb),
        .select_media(1'b0),.test_valid(valid),.test_ready(ready),
        .test_left(SILENCE ? 16'sd0 : source_l),.test_right(SILENCE ? 16'sd0 : source_r),.media_valid(1'b0),.media_ready(),
        .media_left(16'sd0),.media_right(16'sd0),
        .channel0_symbol(c0),.channel1_symbol(c1),.channel2_symbol(c2),
        .sequence_error(sequence_error),.pcm_tap_valid(tap),.pcm_tap_left(tap_l),.pcm_tap_right(tap_r));
    wire p0,p1,p2,pc;
    hdmi_phy_wrapper phy(.I_pixel_clk(clk),.I_serial_clk(serial),.I_rst(rst),
        .I_tmds_channel_0(c0),.I_tmds_channel_1(c1),.I_tmds_channel_2(c2),
        .I_tmds_channel_clk(10'b1111100000),
        .O_tmds_ch0_p(p0),.O_tmds_ch1_p(p1),.O_tmds_ch2_p(p2),.O_tmds_clk_p(pc));
    function [7:0] decode(input [9:0] s);
        reg [7:0] q;integer k;
        begin
            q=s[9]?~s[7:0]:s[7:0];decode[0]=q[0];
            for(k=1;k<8;k=k+1) decode[k]=q[k]^q[k-1]^!s[8];
        end
    endfunction
    reg de_q=0;reg [23:0] rgb_q=0;
    reg next_de; reg [23:0] next_rgb;
    integer pixels=0,samples=0,cycles=0;
    always @(posedge clk) begin
        if(rst) begin de_q=0;rgb_q=0;pixels=0;samples=0;cycles=0;end
        else begin
            next_de=de;next_rgb=rgb;
            cycles=cycles+1;
            if(tap) begin
                if(SILENCE && (tap_l!==0 || tap_r!==0)) $fatal(1,"nonzero silent PCM");
                if(!SILENCE && (tap_l!==source_l || tap_r!==source_r)) $fatal(1,"tone PCM mismatch");
                samples=samples+1;
            end
            #1;
            if(overflow || sequence_error) $fatal(1,"integrated PCM/packet error");
            if(de_q) begin
                if({decode(c2),decode(c1),decode(c0)}!==rgb_q) $fatal(1,"real raster RGB mismatch");
                pixels=pixels+1;
            end
            de_q=next_de;rgb_q=next_rgb;
        end
    end
    // Compare serial output against the complete symbol captured by the
    // existing lane loader. Two 5x-clock pipeline stages precede ODDR output.
    reg [9:0] expected0=0,expected1=0,expected2=0;
    reg load_d0=0,load_d1=0;
    reg [9:0] captured0=0,captured1=0,captured2=0;
    integer bit_index=0,words=0;
    reg checking=0;
    always @(posedge serial) begin
        if(rst) begin load_d0=0;load_d1=0;checking=0;words=0;end
        else begin
            if(load_d1) begin
                expected0=captured0;expected1=captured1;expected2=captured2;
                bit_index=0;checking=1;
            end
            load_d1=load_d0;
            load_d0=phy.u0_lane_lvds_8_1.S_load_en_2d===1'b1;
            if(load_d0) begin captured0=c0;captured1=c1;captured2=c2;end
            #0.5;
            if(checking) begin
                if({p2,p1,p0}!=={expected2[bit_index],expected1[bit_index],expected0[bit_index]} || pc !== (bit_index>=5))
                    $fatal(1,"PHY rising bit mismatch index=%0d",bit_index);
                bit_index=bit_index+1;
            end
        end
    end
    always @(negedge serial) begin
        #0.5;
        if(!rst && checking) begin
            if({p2,p1,p0}!=={expected2[bit_index],expected1[bit_index],expected0[bit_index]} || pc !== (bit_index>=5))
                $fatal(1,"PHY falling bit mismatch index=%0d",bit_index);
            if(bit_index==9) begin words=words+1;checking=0;end
            else bit_index=bit_index+1;
        end
    end
    initial begin
        repeat(5) @(negedge clk);rst=0;
        repeat(850000) @(negedge clk);
        if(pixels<614400 || samples<1600 || words<840000) $fatal(1,"S6 coverage incomplete");
        $display("PASS S6 real raster RGB=%0d PCM samples=%0d serialized words=%0d, all lanes LSB-first and clock 0000011111",pixels,samples,words);
        rst=1;repeat(5) @(negedge clk);rst=0;
        repeat(450000) @(negedge clk);
        if(pixels<307200 || words<440000) $fatal(1,"restart coverage incomplete");
        $display("PASS S6 reset/restart RGB=%0d PCM samples=%0d PHY words=%0d",pixels,samples,words);
        $finish;
    end
endmodule
