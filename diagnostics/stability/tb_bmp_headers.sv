`timescale 1ns/1ps
// Header matrix exercises both scan and load with the same external bytes.
module tb_bmp_headers;
    reg clk=0; always #5 clk=~clk;
    reg rst=1,scan_start=0,load_start=0;
    reg [7:0] data=0;
    reg [31:0] scan_limit=0;
    reg dv=0,ending=0;
    wire ready,scan_done,found,req,sd_req,we,done,error;
    wire [31:0] addr,found_sector;
    wire [2:0] error_code;
    wire [23:0] rgb;
    reg [2:0] ack_pipe=0;
    reg [7:0] bytes[0:511];
    integer i, pixels=0, successes=0,errors=0,found_count=0,requests=0;
    integer offset=54, length=66;
    bmp_read dut(.clk(clk),.rst(rst),.ready(ready),.scan_start(scan_start),
      .scan_start_sector(32'd0),.scan_max_sector(scan_limit),.scan_target_count(3'd1),
      .scan_done(scan_done),.scan_found_valid(found),.scan_found_sector(found_sector),.scan_found_total(),
      .load_start(load_start),.load_sector(32'd0),.load_done(done),.load_error(error),.bmp_error(error_code),
      .sd_init_done(!rst),.state_code(),.bmp_width(16'd4),.bmp_height(16'd1),
      .write_req(req),.write_req_ack(ack_pipe[2]),.sd_sec_read(sd_req),.sd_sec_read_addr(addr),
      .sd_sec_read_data(data),.sd_sec_read_data_valid(dv),.sd_sec_read_end(ending),
      .bmp_data_wr_en(we),.bmp_data(rgb));
    always @(posedge clk) begin
        ack_pipe <= rst ? 0 : {ack_pipe[1:0],req};
        if(!rst) begin
            if(found) found_count=found_count+1;
            if(done) successes=successes+1;
            if(error) begin
                errors=errors+1;
                if(error_code!=1) $fatal(1,"expected header error");
            end
            if(req) requests=requests+1;
            if(we) begin
                if(rgb!==24'hc35a17) $fatal(1,"extended header RGB alignment");
                pixels=pixels+1;
            end
        end
    end
    task tick(input integer n);repeat(n) @(negedge clk);endtask
    task put32(input integer pos,input [31:0] value);
        begin bytes[pos]=value[7:0];bytes[pos+1]=value[15:8];bytes[pos+2]=value[23:16];bytes[pos+3]=value[31:24];end
    endtask
    task normal_header(input integer dib,input integer pixel_start);
        begin
            for(i=0;i<512;i=i+1) bytes[i]=0;
            offset=pixel_start;length=pixel_start+12;
            bytes[0]=8'h42;bytes[1]=8'h4d;put32(2,length);put32(10,pixel_start);
            put32(14,dib);put32(18,4);put32(22,1);bytes[26]=1;bytes[28]=24;
            for(i=pixel_start;i<pixel_start+12;i=i+3) begin
                bytes[i]=8'h17;bytes[i+1]=8'h5a;bytes[i+2]=8'hc3;
            end
        end
    endtask
    task reset_case;
        begin
            rst=1;scan_start=0;load_start=0;dv=0;ending=0;tick(4);rst=0;tick(4);
            pixels=0;successes=0;errors=0;found_count=0;requests=0;
        end
    endtask
    task sector(input integer gap);
        integer n,k;
        begin
            wait(sd_req);@(negedge clk);
            for(n=0;n<512;n=n+1) begin
                data=bytes[n];dv=1;tick(1);dv=0;
                for(k=1;k<gap;k=k+1) tick(1);
            end
            ending=1;tick(1);ending=0;tick(3);
        end
    endtask
    task check_case(input [255:0] name,input good,input integer gap);
        begin
            reset_case();scan_start=1;tick(1);scan_start=0;sector(gap);tick(3);
            if(!scan_done || found_count!=good) $fatal(1,"scan header case %0s",name);
            // No reset between scan and load: exercise the shared checker state.
            load_start=1;tick(1);load_start=0;sector(gap);
            if(good) begin
                sector(gap);tick(4);
                if(successes!=1 || errors!=0 || pixels!=4 || !ready) $fatal(1,"accepted load %0s",name);
            end else if(errors!=1 || successes!=0 || pixels!=0 || requests!=0 || !ready)
                $fatal(1,"rejected load %0s",name);
            $display("PASS scan/load header %0s",name);
        end
    endtask
    initial begin
        normal_header(40,54);check_case("standard exact length",1,1);
        normal_header(108,122);check_case("V4 extended DIB",1,2);
        normal_header(124,138);check_case("V5 extended DIB",1,1);
        normal_header(40,80);check_case("gap before pixels",1,2);
        normal_header(12,54);check_case("unsupported short DIB",0,1);
        normal_header(40,54);bytes[26]=2;check_case("planes must be one",0,1);
        normal_header(40,54);bytes[27]=1;check_case("planes high byte",0,2);
        normal_header(40,54);put32(18,800);check_case("wrong width",0,1);
        normal_header(40,54);put32(18,32'h00010004);check_case("full width high bits",0,1);
        normal_header(40,54);put32(22,32'h00010001);check_case("full height high bits",0,1);
        normal_header(40,54);put32(22,32'hffffffff);check_case("negative height",0,2);
        normal_header(40,54);bytes[28]=32;check_case("unsupported bit depth",0,1);
        normal_header(40,54);put32(30,1);check_case("compressed BMP",0,1);
        normal_header(40,54);bytes[0]=0;check_case("bad signature",0,1);
        normal_header(40,54);put32(10,53);check_case("offset before header end",0,1);
        normal_header(108,122);put32(10,54);check_case("offset overlaps extended DIB",0,1);
        normal_header(40,54);put32(10,66);check_case("offset equals file length",0,1);
        normal_header(40,54);put32(10,67);check_case("offset beyond file length",0,1);
        normal_header(40,54);put32(2,65);check_case("one byte too short",0,2);
        normal_header(40,54);put32(10,32'hfffffff8);put32(2,32'hffffffff);
        check_case("required end does not wrap",0,1);
        // Recovery to a normal header after rejections, without resetting parser.
        normal_header(40,54);load_start=1;tick(1);load_start=0;sector(1);sector(1);tick(4);
        if(successes!=1 || pixels!=4 || error_code!=0) $fatal(1,"valid header after rejection");
        $display("PASS valid header after rejection without reset");
        normal_header(40,54);bytes[26]=2;reset_case();scan_limit=1;
        scan_start=1;tick(1);scan_start=0;sector(1);
        if(scan_done || found_count!=0 || addr!=1) $fatal(1,"invalid scan did not advance one sector");
        normal_header(40,54);sector(1);tick(3);
        if(!scan_done || found_count!=1 || found_sector!=1) $fatal(1,"good image after rejected header lost");
        $display("PASS mixed scan rejects bad header and discovers next good image");
        $finish;
    end
    initial begin #1000000;$fatal(1,"headers watchdog");end
endmodule
