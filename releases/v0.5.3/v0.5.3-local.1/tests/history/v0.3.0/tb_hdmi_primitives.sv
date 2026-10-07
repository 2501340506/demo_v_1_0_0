`timescale 1ns/1ps
module tb_hdmi_primitives;
    reg clk=0,rst_n=0;
    always #20 clk=~clk;
    reg [55:0] data=0;
    wire [7:0] ecc3,ecc7;
    hdmi_bch8 #(.DATA_BYTES(3)) b3(.data(data[23:0]),.ecc(ecc3));
    hdmi_bch8 #(.DATA_BYTES(7)) b7(.data(data),.ecc(ecc7));
    reg [2:0] mode=0;
    reg [7:0] video=0;
    reg [3:0] island=0;
    reg [1:0] control=0;
    wire [9:0] symbol[0:2];
    genvar c;
    generate for(c=0;c<3;c=c+1) begin: channel
        hdmi_tmds_channel_encoder #(.CHANNEL(c)) encoder(.clk(clk),.rst_n(rst_n),
            .mode(mode),.video_data(video),.data_island_data(island),.control_data(control),.symbol(symbol[c]));
    end endgenerate
    wire [23:0] ah;
    wire [223:0] ab;
    wire [7:0] ae;
    wire [31:0] abe;
    wire av;
    reg acr_v=0,info_v=0,audio_v=0,claim=0,consume=0;
    wire acr_r,info_r,audio_r,pv;
    wire [1:0] source;
    wire [23:0] ph;
    wire [7:0] pe;
    wire [223:0] pb;
    wire [31:0] pbe;
    hdmi_audio_packet_scheduler scheduler(.clk(clk),.rst_n(rst_n),
        .acr_valid(acr_v),.acr_ready(acr_r),.acr_header(24'd1),.acr_header_ecc(8'd0),.acr_body(224'd1),.acr_body_ecc(32'd0),
        .info_valid(info_v),.info_ready(info_r),.info_header(24'h84),.info_header_ecc(8'd0),.info_body(224'd2),.info_body_ecc(32'd0),
        .audio_valid(audio_v),.audio_ready(audio_r),.audio_header(24'd2),.audio_header_ecc(8'd0),.audio_body(224'd3),.audio_body_ecc(32'd0),
        .packet_valid(pv),.packet_lock(claim),.packet_ready(consume),.packet_source(source),
        .packet_header(ph),.packet_header_ecc(pe),.packet_body(pb),.packet_body_ecc(pbe));
    hdmi_audio_acr_packetizer acr(.clk(clk),.rst_n(rst_n),.packet_ready(1'b1),
        .packet_valid(av),.packet_header(ah),.packet_body(ab),.packet_header_ecc(ae),.packet_body_ecc(abe));
    integer fd,n,m;
    initial begin
        fd=$fopen("primitives.txt","w");
        repeat(3) @(negedge clk);rst_n=1;
        audio_v=1;claim=1;
        @(negedge clk);claim=0;acr_v=1;info_v=1;
        repeat(5) begin
            @(negedge clk);
            if(!pv || source!=2 || ph!=2 || pb!=3 || acr_r || info_r || audio_r)
                $fatal(1,"claimed audio packet changed under higher priority arrival");
        end
        consume=1;#1;
        if(!audio_r || acr_r || info_r) $fatal(1,"wrong source consumed");
        @(negedge clk);consume=0;audio_v=0;#1;
        if(source!=0 || ph!=1) $fatal(1,"ACR priority");
        consume=1;@(negedge clk);consume=0;acr_v=0;#1;
        if(source!=1 || ph!=24'h84) $fatal(1,"InfoFrame priority");
        info_v=0;
        $display("PASS packet claim holds audio across higher priority arrivals; ACR then InfoFrame priority");
        for(n=0;n<256;n=n+1) begin
            data={n[7:0],~n[7:0],8'h01,n[7:0],8'h80,~n[7:0],8'h00};
            #1;$fdisplay(fd,"B %014h %02h %02h",data,ecc3,ecc7);
        end
        $fdisplay(fd,"R %056h",ab);
        for(m=0;m<5;m=m+1) begin
            for(n=0;n<(m==1 ? 1024 : 16);n=n+1) begin
                @(negedge clk);mode=m;video=n*73;island=n;control=n;
                @(posedge clk);#1;
                $fdisplay(fd,"T %0d %02h %01h %01h %03h %03h %03h",mode,video,island,control,symbol[0],symbol[1],symbol[2]);
            end
        end
        $fclose(fd);$display("PASS primitive vectors generated");$finish;
    end
endmodule
