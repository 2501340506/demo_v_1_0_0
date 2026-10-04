`timescale 1ns/1ps
module tb_pcm_test_tone;
    reg clk=0, rst_n=0, enable=0, sample_ready=1;
    always #20 clk=~clk;
    wire sample_valid, sample_tick, overflow;
    wire signed [15:0] sample_left,sample_right;
    pcm_test_tone dut(.*);
    integer cycle=0, ticks=0, pops=0, last_tick=0, window_ticks=0;
    integer rd=0,wr=0,expected_count=0, crossings=0, last_nonzero=0;
    integer max_sample=0,min_sample=0,idx,expected;
    integer queue[0:8191];
    reg held=0;
    reg signed [15:0] held_l,held_r;
    reg expect_overflow=0;
    real angle,value;
    // Independent real-valued frequency/LUT reference and accepted-sample queue.
    always @(posedge clk) begin
        if (!rst_n || !enable) begin
            cycle=0; ticks=0; pops=0; last_tick=0; window_ticks=0;
            rd=0;wr=0;expected_count=0;held=0;
            crossings=0;last_nonzero=0;max_sample=0;min_sample=0;
        end else begin
            cycle=cycle+1;
            if (held && (!sample_valid || sample_left !== held_l || sample_right !== held_r))
                $fatal(1,"PCM changed while waiting, including accepting edge");
            held=sample_valid && !sample_ready; held_l=sample_left;held_r=sample_right;
            if (sample_valid && sample_ready) begin
                if (expected_count==0 || sample_left !== queue[rd] || sample_right !== queue[rd])
                    $fatal(1,"accepted sample mismatch at %0d: %0d expected %0d",pops,sample_left,queue[rd]);
                rd=rd+1; expected_count=expected_count-1; pops=pops+1;
                if (sample_left>0 && last_nonzero<0) crossings=crossings+1;
                if (sample_left!=0) last_nonzero=sample_left;
                if (sample_left>max_sample) max_sample=sample_left;
                if (sample_left<min_sample) min_sample=sample_left;
            end
            if (sample_tick) begin
                if (last_tick && cycle-last_tick!=520 && cycle-last_tick!=521)
                    $fatal(1,"bad sample interval");
                last_tick=cycle;
                idx=$rtoi(ticks * (440.0/48000.0) * 16.0 + 0.0000001) % 16;
                angle=6.283185307179586 * idx/16.0;
                value=12000.0*$sin(angle);
                expected=value>=0 ? $rtoi(value+0.5) : $rtoi(value-0.5);
                if (expected_count<8) begin
                    queue[wr]=expected;wr=wr+1;expected_count=expected_count+1;
                end
                ticks=ticks+1;window_ticks=window_ticks+1;
            end
            if (cycle%25000==0) begin
                if (window_ticks!=48) $fatal(1,"not 48 samples per 25000 cycles");
                window_ticks=0;
            end
            if (overflow && !expect_overflow) $fatal(1,"unexpected FIFO overflow");
        end
    end
    task tick(input integer n); repeat(n) @(negedge clk); endtask
    initial begin
        tick(3);rst_n=1;enable=1;
        tick(2500000); // 100 ms: 4800 samples, 44 periods (43 completed rising crossings).
        if (ticks!=4800 || crossings!=43 || max_sample!=12000 || min_sample!=-12000)
            $fatal(1,"rate/frequency/amplitude: ticks %0d crossings %0d range %0d..%0d",ticks,crossings,min_sample,max_sample);
        $display("PASS 100 ms at 48 kHz, 440 Hz DDS, stereo and +/-12000 amplitude");
        // Backpressure shorter than FIFO capacity must neither drop nor reorder.
        sample_ready=0;tick(3000);sample_ready=1;tick(10);
        if (expected_count!=0 || overflow) $fatal(1,"FIFO did not drain");
        $display("PASS backpressure stability and ordered FIFO recovery");
        sample_ready=0;tick(4200); // Eight entries, then arrange full pop+push together.
        wait(sample_tick); @(negedge clk);sample_ready=1;
        tick(10);
        if (overflow) $fatal(1,"full simultaneous pop/push lost sample");
        $display("PASS full FIFO accepts concurrent pop/push");
        expect_overflow=1;sample_ready=0;tick(5200);
        if (!overflow || !sample_valid) $fatal(1,"full FIFO must report overflow and retain head");
        sample_ready=1;tick(10);
        if (!overflow) $fatal(1,"overflow must remain sticky");
        $display("PASS sustained backpressure reports overflow without corrupting queued PCM");
        enable=0;tick(2);
        if (sample_valid || sample_tick || overflow) $fatal(1,"disable should flush stream");
        enable=1;expect_overflow=0;tick(522);
        // The scoreboard checked the accepted zero sample; empty FIFO data is unspecified.
        if (pops!=1) $fatal(1,"restart from phase zero");
        rst_n=0;tick(2);
        if (sample_valid || overflow) $fatal(1,"reset did not clear stream");
        $display("PASS disable/restart and reset");$finish;
    end
    initial begin #110000000; $fatal(1,"PCM watchdog"); end
endmodule
