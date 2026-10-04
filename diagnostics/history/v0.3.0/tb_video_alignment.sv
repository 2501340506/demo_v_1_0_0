`timescale 1ns/1ps
module tb_video_alignment;
    reg clk=0, rst=1;
    always #20 clk=~clk;
    wire hs0,vs0,de0,hs,vs,de,read_en,read_req;
    wire [9:0] x0,x;
    wire [23:0] rgb;
    reg [23:0] read_data=0;
    video_timing_data timing(.video_clk(clk),.rst(rst),.read_req(read_req),
        .read_req_ack(read_req),.hs(hs0),.vs(vs0),.de(de0),.video_x(x0));
    video_delay delay_line(.video_clk(clk),.rst(rst),.read_en(read_en),
        .read_data(read_data),.hs(hs0),.vs(vs0),.de(de0),.video_x(x0),
        .hs_r(hs),.vs_r(vs),.de_r(de),.vout_data(rgb),.video_x_r(x));

    // Unmodified S1 timing/data path, renamed by the runner for comparison.
    wire old_hs0,old_vs0,old_de0,old_hs,old_vs,old_de,old_read_en,old_read_req;
    wire [23:0] old_rgb;
    s1_video_timing_data old_timing(.video_clk(clk),.rst(rst),.read_req(old_read_req),
        .read_req_ack(old_read_req),.hs(old_hs0),.vs(old_vs0),.de(old_de0));
    s1_video_delay old_delay(.video_clk(clk),.rst(rst),.read_en(old_read_en),
        .read_data(read_data),.hs(old_hs0),.vs(old_vs0),.de(old_de0),
        .hs_r(old_hs),.vs_r(old_vs),.de_r(old_de),.vout_data(old_rgb));

    function [23:0] pixel(input integer col, input integer row);
        pixel={row[8:0],col[9:0],5'b10101};
    endfunction
    // Model the existing synchronous FIFO read port: one pixel per read_en.
    integer source_index=0;
    always @(posedge clk) begin
        if(rst) begin source_index=0; read_data<=0; end
        else if(read_en) begin
            read_data<=pixel(source_index%640,source_index/640);
            source_index=(source_index==307199)?0:source_index+1;
        end
    end

    integer cycles=0,ref_x=0,ref_line=0,frame_cycles=0;
    integer active_pixels=0,active_lines=0,blank_lines=0,frames=0;
    reg anchored=0,prev_vs=0,expected_de;
    // Absolute raster reference anchored only to VS, never to DUT counters/x.
    always @(negedge clk) begin
        if(rst) begin
            cycles=0;anchored=0;prev_vs=0;frame_cycles=0;
            active_pixels=0;active_lines=0;blank_lines=0;frames=0;
            if ({hs0,vs0,de0,x0,hs,vs,de,x,rgb,read_en,read_req} !== 0)
                $fatal(1,"reset did not clear aligned outputs");
        end else begin
            cycles=cycles+1;
            // S1 left its second timing register unreset: compare after fill.
            if(cycles>30 && {hs0,vs0,de0,hs,vs,de,read_en,read_req,rgb} !==
                {old_hs0,old_vs0,old_de0,old_hs,old_vs,old_de,old_read_en,old_read_req,old_rgb})
                $fatal(1,"S1 video/read-request regression at cycle %0d",cycles);
            if(!anchored && prev_vs && !vs) begin
                anchored=1;ref_x=656;ref_line=0;
            end else if(anchored) begin
                ref_x=(ref_x+1)%800;
                if(ref_x==656) ref_line=(ref_line+1)%525;
            end
            if(anchored) begin
                expected_de=(ref_x<640 && ref_line>=35 && ref_line<515);
                if(x !== ref_x || hs !== !(ref_x>=656 && ref_x<752) ||
                    vs !== !(ref_line<2) || de !== expected_de)
                    $fatal(1,"raster mismatch line=%0d x=%0d actual x=%0d hs/vs/de=%b%b%b",
                        ref_line,ref_x,x,hs,vs,de);
                if(de) begin
                    active_pixels=active_pixels+1;
                    if(rgb !== pixel(ref_x,ref_line-35))
                        $fatal(1,"RGB alignment mismatch line=%0d x=%0d rgb=%h",ref_line,ref_x,rgb);
                end else if(rgb !== 0) $fatal(1,"nonzero blanking RGB");
                if(ref_x==0) begin
                    if(expected_de) active_lines=active_lines+1;
                    else blank_lines=blank_lines+1;
                end
                frame_cycles=frame_cycles+1;
                if(frame_cycles==420000) begin
                    if(active_pixels!=307200 || active_lines!=480 || blank_lines!=45)
                        $fatal(1,"incorrect frame dimensions");
                    frames=frames+1;
                    $display("PASS frame %0d: 800x525, 640x480, x=0..799 on all lines, aligned RGB and S1 equivalence",frames);
                    frame_cycles=0;active_pixels=0;active_lines=0;blank_lines=0;
                end
            end
            prev_vs=vs;
        end
    end
    initial begin
        repeat(4) @(posedge clk); #1 rst=0;
        wait(frames==2);
        @(posedge clk); #1 rst=1;
        repeat(4) @(posedge clk); #1 rst=0;
        wait(frames==1);
        $display("PASS reset/restart and complete raster recovery");
        $finish;
    end
    // VS resets low; each reset needs an initial frame before a falling-edge anchor.
    initial begin #100000000; $fatal(1,"video alignment watchdog"); end
endmodule
