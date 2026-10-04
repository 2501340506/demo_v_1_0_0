`timescale 1ns/1ps
module tb_hdmi_packets;
    parameter integer PATTERN = 0;
    parameter integer SILENCE = 0;
    reg clk=0,rst_n=0;
    always #20 clk=~clk;
    integer x=0,line=0,cycles=0;
    wire hs=!(x>=656 && x<752),vs=!(line<2);
    wire de=(x<640 && line>=35 && line<515);
    wire [23:0] rgb={line[7:0],x[7:0],(x[7:0]^line[7:0])};
    reg select_media=0;
    wire tv,tr,mr,seq_error,tap;
    wire signed [15:0] tl,rr,tapl,tapr;
    wire [9:0] c0,c1,c2;
    wire overflow,tick;
    integer generated=0;
    // Stop the source after a multiple of four accepted samples; drain packets.
    wire tone_enable=generated<3200;
    pcm_test_tone tone(.clk(clk),.rst_n(rst_n),.enable(tone_enable),
        .sample_valid(tv),.sample_ready(tr),
        .sample_left(tl),.sample_right(rr),.sample_tick(tick),.overflow(overflow));
    // PATTERN=1 drives each selected producer continuously. This exercises
    // switching during a stalled packet, distinct stereo and signed extremes.
    integer test_index=0,media_index=0;
    function [15:0] left_pattern(input integer n);
        case(n%8)
            0:left_pattern=16'h8000; 1:left_pattern=16'h7fff;
            2:left_pattern=0; 3:left_pattern=16'hffff;
            default:left_pattern=n*73;
        endcase
    endfunction
    wire pattern_running=(test_index+media_index)<800;
    wire test_valid=PATTERN ? pattern_running : (tv && tone_enable);
    wire media_valid=PATTERN && pattern_running;
    wire signed [15:0] test_left=SILENCE ? 16'sd0 : PATTERN ? left_pattern(test_index) : tl;
    wire signed [15:0] test_right=SILENCE ? 16'sd0 : PATTERN ? ~left_pattern(test_index) : rr;
    wire signed [15:0] media_left=left_pattern(media_index+10000);
    wire signed [15:0] media_right=media_index*137;
    media_hdmi_audio_bridge dut(.pixel_clk(clk),.pixel_rst_n(rst_n),
        .video_hsync(hs),.video_vsync(vs),.video_de(de),.video_x(x[9:0]),.video_rgb(rgb),
        .select_media(select_media),.test_valid(test_valid),.test_ready(tr),
        .test_left(test_left),.test_right(test_right),.media_valid(media_valid),
        .media_ready(mr),.media_left(media_left),.media_right(media_right),
        .channel0_symbol(c0),.channel1_symbol(c1),.channel2_symbol(c2),
        .sequence_error(seq_error),.pcm_tap_valid(tap),.pcm_tap_left(tapl),.pcm_tap_right(tapr));
    integer fd,accepted=0,packets=0,video_pixels=0,di=0,ni,nj,nk,j;
    integer rd0=0,rd1=0,rd2=0;
    integer old_x=0,old_line=0,qx=0,qline=0;
    reg qhs=1,qvs=1,qde=0;
    reg [23:0] qrgb=0;
    reg [31:0] header;
    reg [63:0] subpacket[0:3];
    integer island_phase=0,phase_count=0,controls=0;
    reg seen_video_sync=0;
    reg last_vs=1;
    integer preamble_count=0,guard_count=0;
    integer stalled_switches=0,locked_priority_arrivals=0;
    reg held=0,held_source;
    reg signed [15:0] held_l,held_r;

    function integer terc(input [9:0] s);
        case(s)
            10'h29c:terc=0;10'h263:terc=1;10'h2e4:terc=2;10'h2e2:terc=3;
            10'h171:terc=4;10'h11e:terc=5;10'h18e:terc=6;10'h13c:terc=7;
            10'h2cc:terc=8;10'h139:terc=9;10'h19c:terc=10;10'h2c6:terc=11;
            10'h28e:terc=12;10'h271:terc=13;10'h163:terc=14;10'h2c3:terc=15;
            default:terc=-1;
        endcase
    endfunction
    function [9:0] control(input reg v,input reg h);
        case({v,h})
            0:control=10'h354;1:control=10'h0ab;2:control=10'h154;3:control=10'h2ab;
        endcase
    endfunction
    function [7:0] decode_video(input [9:0] s);
        reg [7:0] q;
        integer k;
        begin
            q=s[9] ? ~s[7:0] : s[7:0];
            decode_video[0]=q[0];
            for(k=1;k<8;k=k+1) decode_video[k]=q[k]^q[k-1]^!s[8];
        end
    endfunction
    function integer disparity(input [9:0] s);
        integer k;
        begin disparity=-10; for(k=0;k<10;k=k+1) disparity=disparity+2*s[k]; end
    endfunction

    always @(posedge clk) begin
        if(rst_n) begin
            if(tr && mr) $fatal(1,"both PCM sources ready");
            if(held && (!dut.sample_valid || dut.sample_left!==held_l || dut.sample_right!==held_r || dut.selected!==held_source))
                $fatal(1,"PCM selection/data changed while stalled");
            held=dut.sample_valid && !dut.sample_ready;
            held_l=dut.sample_left;held_r=dut.sample_right;held_source=dut.selected;
            if(held && select_media!=held_source) stalled_switches=stalled_switches+1;
            if(dut.u_symbol_core.u_packet_scheduler.locked &&
               dut.u_symbol_core.u_packet_scheduler.locked_source==2 &&
               dut.u_symbol_core.acr_valid) locked_priority_arrivals=locked_priority_arrivals+1;
            if(tap) begin
                $fdisplay(fd,"A %04h %04h",tapl,tapr);
                accepted=accepted+1;
                if(PATTERN) begin
                    if(tr) test_index<=test_index+1;
                    if(mr) media_index<=media_index+1;
                end else generated<=generated+1;
            end
            old_x=qx;old_line=qline;
            // Encoder sees the bridge's previous registered video bundle.
            #1;
            if(seq_error) $fatal(1,"packet sequence error");
            if(!PATTERN && overflow) $fatal(1,"48k PCM overflow");
            if(last_vs && !qvs) seen_video_sync=1;
            last_vs=qvs;
            if(qde) begin
                if(island_phase!=0) $fatal(1,"data island overlaps active video");
                if({decode_video(c2),decode_video(c1),decode_video(c0)}!==qrgb)
                    $fatal(1,"TMDS RGB decode mismatch");
                rd0=rd0+disparity(c0);rd1=rd1+disparity(c1);rd2=rd2+disparity(c2);
                if(rd0>8 || rd0< -8 || rd1>8 || rd1< -8 || rd2>8 || rd2< -8)
                    $fatal(1,"unbounded TMDS disparity");
                video_pixels=video_pixels+1;controls=0;
            end else begin
                rd0=0;rd1=0;rd2=0;
                case(island_phase)
                    0: begin
                        if(c1==10'h0ab && c2==10'h0ab) begin
                            if(controls<12 || old_x!=653) $fatal(1,"bad island start/control spacing");
                            island_phase=1;phase_count=1;controls=0;
                            if(c0!==control(qvs,qhs)) $fatal(1,"preamble sync");
                        end else if(old_x>=790 && old_line>=35 && old_line<515 && seen_video_sync) begin
                            if(old_x<798) begin
                                if(c0!==control(qvs,qhs) || c1!==10'h0ab || c2!==10'h354)
                                    $fatal(1,"video preamble mismatch");
                                preamble_count=preamble_count+1;
                            end else begin
                                if(c0!==10'h2cc || c1!==10'h133 || c2!==10'h2cc)
                                    $fatal(1,"video guard mismatch");
                                guard_count=guard_count+1;
                            end
                        end else begin
                            if(c0!==control(qvs,qhs) || c1!==10'h354 || c2!==10'h354)
                                $fatal(1,"unexpected control/video announcement x=%0d line=%0d",old_x,old_line);
                            controls=controls+1;
                        end
                    end
                    1: begin
                        if(c0!==control(qvs,qhs) || c1!==10'h0ab || c2!==10'h0ab)
                            $fatal(1,"island preamble length/content");
                        phase_count=phase_count+1;
                        if(phase_count==8) begin island_phase=2;phase_count=0;end
                    end
                    2,4: begin
                        if(terc(c0)!=(12+{qvs,qhs}) || c1!==10'h133 || c2!==10'h133)
                            $fatal(1,"data guard band mismatch");
                        phase_count=phase_count+1;
                        if(phase_count==2) begin
                            phase_count=0;
                            if(island_phase==2) begin island_phase=3;di=0;end
                            else island_phase=0;
                        end
                    end
                    3: begin
                        ni=terc(c0);nj=terc(c1);nk=terc(c2);
                        if(ni<0 || nj<0 || nk<0 || (ni&3)!={qvs,qhs} || (ni&8)==0)
                            $fatal(1,"TERC4 or island sync invalid");
                        header[di]=(ni>>2)&1;
                        for(j=0;j<4;j=j+1) begin
                            subpacket[j][2*di]=(nj>>j)&1;
                            subpacket[j][2*di+1]=(nk>>j)&1;
                        end
                        di=di+1;
                        if(di==32) begin
                            $fdisplay(fd,"P %08h %016h %016h %016h %016h",header,subpacket[0],subpacket[1],subpacket[2],subpacket[3]);
                            packets=packets+1;island_phase=4;phase_count=0;
                        end
                    end
                endcase
            end
            qx=x;qline=line;qhs=hs;qvs=vs;qde=de;qrgb=de?rgb:0;
        end
    end
    always @(negedge clk) if(rst_n) begin
        cycles=cycles+1;
        x=(x+1)%800;
        if(x==656) line=(line+1)%525;
        if(PATTERN) select_media=(cycles/17)%2;
    end
    initial begin
        fd=$fopen(PATTERN ? "pattern_packets.txt" : "tone_packets.txt","w");
        repeat(4) @(negedge clk);rst_n=1;
        repeat(PATTERN ? 850000 : 1700000) @(negedge clk);
        #5;
        if(accepted!=(PATTERN?800:3200)) $fatal(1,"sample acceptance count %0d",accepted);
        if(video_pixels<307200 || preamble_count==0 || guard_count==0) $fatal(1,"video coverage missing");
        if(PATTERN && (test_index<100 || media_index<100)) $fatal(1,"source mux not exercised");
        if(PATTERN && stalled_switches==0) $fatal(1,"stalled source switch not exercised");
        $fdisplay(fd,"END %0d %0d %0d",accepted,packets,video_pixels);
        $fclose(fd);
        $display("PASS HDMI symbols: pattern=%0d accepted=%0d packets=%0d pixels=%0d",PATTERN,accepted,packets,video_pixels);
        $display("PASS coverage: stalled selection changes=%0d higher priority arrivals while audio locked=%0d",stalled_switches,locked_priority_arrivals);
        $finish;
    end
endmodule
