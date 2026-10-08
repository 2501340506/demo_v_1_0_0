`timescale 1ns/1ps
module tb_sd_sector_adapter;
    reg clk=0; always #5 clk=~clk;
    reg rst=1, req=0, raw_valid=0, raw_end=0, raw_failed=0;
    reg [31:0] lba=0;
    reg [7:0] raw_byte=0;
    wire busy, valid, done, read_req;
    wire [7:0] data, error_code;
    wire [8:0] index;
    wire [31:0] address;
    integer seen=0, completions=0, starts=0;
    reg previous_read=0, previous_done=0;
    sd_sector_adapter #(.CLK_FREQ_HZ(1000),.TIMEOUT_MS(20)) dut (
        .clk(clk),.rst(rst),.sector_req(req),.sector_lba(lba),
        .sector_busy(busy),.sector_valid(valid),.sector_byte(data),
        .sector_byte_index(index),.sector_done(done),.sector_error(error_code),
        .sd_sec_read(read_req),.sd_sec_read_addr(address),
        .sd_sec_read_data_valid(raw_valid),.sd_sec_read_data(raw_byte),
        .sd_sec_read_end(raw_end),.sd_sec_read_failed(raw_failed)
    );
    always @(posedge clk) begin
        if(rst) begin previous_read=0;previous_done=0;end
        else begin
            if(read_req && !previous_read) starts=starts+1;
            if(valid) begin
                if(index!==9'(seen) || data!==8'(seen ^ 8'ha5))
                    $fatal(1,"byte/index mismatch at %0d",seen);
                if(done) $fatal(1,"done overlaps a valid byte");
                seen=seen+1;
            end
            if(done) begin
                if(previous_done || read_req || !busy) $fatal(1,"completion contract");
                completions=completions+1;
            end
            previous_read=read_req; previous_done=done;
        end
    end
    task tick; begin @(negedge clk); end endtask
    task issue(input [31:0] location);
        begin
            while(busy) tick();
            seen=0; lba=location; req=1; tick(); req=0;
            if(!busy || !read_req || address!==location) $fatal(1,"request not accepted");
            lba=32'hdeadbeef; tick();
            if(address!==location) $fatal(1,"LBA not latched");
        end
    endtask
    task finish_check(input [7:0] expected, input integer count, input integer old_completions);
        integer cycles;
        begin
            cycles=0;
            while(!done && cycles<30) begin tick();cycles=cycles+1;end
            if(!done || error_code!==expected || seen!=count)
                $fatal(1,"result error=%h expected=%h bytes=%0d expected=%0d",error_code,expected,seen,count);
            tick();
            while(busy) tick();
            if(completions!=old_completions+1) $fatal(1,"missing/duplicate done");
        end
    endtask
    task transfer(input integer count, input integer gap, input bit same_cycle);
        integer i, old_completions;
        begin
            old_completions=completions;
            issue(32'h12345678+32'(starts));
            for(i=0;i<count;i=i+1) begin
                raw_valid=1;raw_byte=8'(i ^ 8'ha5);
                raw_end=same_cycle && i==count-1;
                tick();raw_valid=0;raw_end=0;
                if(i<count-1) repeat(gap) tick();
            end
            if(!same_cycle) begin tick();raw_end=1;tick();raw_end=0;end
            finish_check(count==512 ? 8'h00 : 8'h12, count>512 ? 512 : count,old_completions);
        end
    endtask
    integer old_done, old_starts;
    initial begin
        repeat(3) tick();rst=0;tick();
        transfer(512,0,1);
        $display("PASS sector continuous bytes and simultaneous final byte/end");
        transfer(512,2,0);
        $display("PASS sector gapped bytes exceed total deadline without timeout");
        transfer(511,0,1);
        $display("PASS sector short transfer reports length error");
        transfer(513,0,0);
        $display("PASS sector overlong transfer reports length error");
        old_done=completions;issue(32'd72);
        raw_failed=1;tick();raw_failed=0;
        finish_check(8'h10,0,old_done);
        $display("PASS sector failure without normal end completes once");
        old_done=completions;issue(32'd73);
        finish_check(8'h11,0,old_done);
        $display("PASS sector no-progress timeout releases request");
        transfer(512,0,0);
        $display("PASS sector next transaction after failure");
        old_done=completions;issue(32'd74);
        rst=1;tick();rst=0;repeat(3) tick();
        if(busy || read_req || done || completions!=old_done) $fatal(1,"reset did not abort silently");
        transfer(512,1,1);
        $display("PASS sector reset during read and restart");
        old_starts=starts;repeat(30) tick();
        if(starts!=old_starts || busy || read_req) $fatal(1,"duplicate request after completion");
        $display("PASS sector adapter all scenarios");
        $finish;
    end
    initial begin #1000000;$fatal(1,"test watchdog");end
endmodule
