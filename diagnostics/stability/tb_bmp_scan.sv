`timescale 1ns/1ps
module tb_bmp_scan #(parameter integer BASELINE=0);
    reg clk=0;always #5 clk=~clk;
    reg rst=1,start=0,dv=0,ending=0;
    reg [31:0] limit=0,first_sector=0;
    reg [7:0] data=0,bytes[0:511];
    wire req,done,found,ready;
    wire [31:0] addr,found_sector;
    integer reads=0,found_count=0,i;
    bmp_read dut(.clk(clk),.rst(rst),.ready(ready),.scan_start(start),
      .scan_start_sector(first_sector),.scan_max_sector(limit),.scan_target_count(3'd1),
`ifndef STABILITY_S2
      .scan_error(),
`endif
      .scan_done(done),.scan_found_valid(found),.scan_found_sector(found_sector),.scan_found_total(),
      .load_start(1'b0),.load_sector(32'd0),.load_done(),.load_error(),.bmp_error(),
      .sd_init_done(!rst),.state_code(),.bmp_width(16'd640),.bmp_height(16'd480),
      .write_req(),.write_req_ack(1'b0),.sd_sec_read(req),.sd_sec_read_addr(addr),
      .sd_sec_read_data(data),.sd_sec_read_data_valid(dv),.sd_sec_read_failed(1'b0),.sd_sec_read_end(ending),
      .bmp_data_wr_en(),.bmp_data());
    always @(posedge clk) if(!rst && found) found_count=found_count+1;
    task tick(input integer n);repeat(n) @(negedge clk);endtask
    task put32(input integer pos,input [31:0] value);
      begin bytes[pos]=value[7:0];bytes[pos+1]=value[15:8];bytes[pos+2]=value[23:16];bytes[pos+3]=value[31:24];end
    endtask
    task header(input integer w,h,bpp,input [31:0] len);
      begin
        for(i=0;i<512;i=i+1)bytes[i]=0;
        bytes[0]="B";bytes[1]="M";put32(2,len);put32(10,54);put32(14,40);
        put32(18,w);put32(22,h);bytes[26]=1;bytes[28]=bpp;
      end
    endtask
    task boot(input [31:0] base,last);
      begin rst=1;start=0;dv=0;ending=0;first_sector=base;limit=last;tick(4);rst=0;tick(4);
        reads=0;found_count=0;start=1;tick(1);start=0;
      end
    endtask
    task sector(input [31:0] expected);
      integer n;
      begin
        wait(req);if(addr!==expected)$fatal(1,"request %0d expected %0d",addr,expected);
        reads=reads+1;@(negedge clk);
        for(n=0;n<512;n=n+1)begin data=bytes[n];dv=1;tick(1);end
        dv=0;ending=1;tick(1);ending=0;tick(3);
      end
    endtask
    task fast_case(input integer w,h,bpp,input [31:0] len,input integer span);
      integer intermediate;
      begin
        boot(0,span+1800);header(w,h,bpp,len);sector(0);
        if(done||found_count!=0)$fatal(1,"bad candidate registered");
        if(BASELINE) begin
            for(i=0;i<512;i=i+1)bytes[i]=0;
            for(intermediate=1;intermediate<span;intermediate=intermediate+1)sector(intermediate);
        end
        header(640,480,24,921654);sector(span);
        if(!done||found_count!=1||found_sector!=span||reads!=(BASELINE ? span+1 : 2))$fatal(1,"good image after skip");
        $display("PASS measured BASELINE=%0d %0dx%0d/%0d-bit reads=%0d found=%0d",BASELINE,w,h,bpp,reads,found_sector);
      end
    endtask
    task fallback(input [255:0] name);
      begin
        sector(0);if(done||found_count!=0)$fatal(1,"fallback ended early");
        header(640,480,24,921654);sector(1);
        if(!done||found_count!=1||found_sector!=1)$fatal(1,"fallback missed next image");
        $display("PASS one-sector fallback %0s",name);
      end
    endtask
    initial begin
        fast_case(800,600,24,1440054,2813);
        fast_case(640,480,32,1228854,2401);
        fast_case(3,100,24,1254,3); // Row padding: 12 bytes per row, not 9.
        if(BASELINE)$finish;
        boot(0,2);header(3,100,24,954);fallback("short padded payload");
        boot(0,4000);header(800,600,24,1440054);bytes[0]=0;fallback("non-BMP / ordinary data");
        boot(0,4000);header(800,600,24,1440054);bytes[26]=2;fallback("planes malformed");
        boot(0,4000);header(800,600,24,1440054);put32(10,20);fallback("offset overlaps DIB");
        boot(0,4000);header(800,600,24,1000);fallback("length insufficient");
        boot(0,4000);header(800,600,24,0);fallback("zero length");
        boot(0,1);header(800,600,24,1440054);fallback("span beyond scan range");
        boot(0,4000);header(800,600,24,1440054);put32(30,1);fallback("compression not trusted");
        boot(0,2812);header(800,600,24,1440054);sector(0);tick(10);
        if(!done||!ready||found_count!=0||reads!=1||req)$fatal(1,"exact end boundary");
        $display("PASS candidate ends exactly at scan boundary, no out-of-range read");
        boot(32'hfffffffe,32'hffffffff);header(3,100,24,1254);sector(32'hfffffffe);
        if(done||addr!=32'hffffffff)$fatal(1,"address overflow did not fallback");
        bytes[0]=0;sector(32'hffffffff);tick(5);
        if(!done||req)$fatal(1,"last sector termination");
        $display("PASS widened address arithmetic and final sector termination");
        boot(0,1);header(800,600,24,32'hffffffff);fallback("huge file length cannot wrap");
        $finish;
    end
    initial begin #40000000;$fatal(1,"scan watchdog");end
endmodule
