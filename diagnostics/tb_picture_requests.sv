`timescale 1ns/1ps
// Actual controller + BMP reader; SD sectors and SDRAM acknowledgement are modeled.
module tb_picture_requests;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1, key_next = 1, key_auto = 1, finish_toggle = 0;
    reg ack = 0, init_done = 0, data_valid = 0, sector_end = 0;
    reg [3:0] ack_pipe = 0;
    reg [7:0] sector_data = 0;
    wire [3:0] code;
    wire valid, req, we;
    wire [31:0] pixel;
    wire [1:0] wb, db;
    integer pixels = 0, commits = 0;
    integer next_events = 0, prev_events = 0, short_events = 0;
    integer starts = 0;
    reg [1:0] started_idx [0:255];
    always @(posedge clk) if (!rst) begin
        if (dut.load_start_pulse) begin
            started_idx[starts] = dut.load_idx;
            starts = starts + 1;
        end
        if (dut.key1_press_event) next_events = next_events + 1;
        if (dut.prev_event) prev_events = prev_events + 1;
        if (dut.short_event) short_events = short_events + 1;
    end
    reg old_busy = 0;
    reg bad_header = 0;
    reg hold_finish = 0, finish_pending = 0;
    sd_card_bmp #(.CLK_FREQ_HZ(1000), .SCAN_MAX_SECTOR(4),
                  .SCAN_TARGET_COUNT(4), .LONG_PRESS_MS(1000),
                  .AUTO_PLAY_MS(3000)) dut (
        .clk(clk), .rst(rst), .key_next(key_next), .key_auto(key_auto),
        .state_code(code), .bmp_width(16'd4), .bmp_height(16'd1),
        .combo_event_count(), .combo_debug_active(),
        .display_valid(valid), .write_finish_toggle(finish_toggle),
        .write_buf_idx(wb), .disp_buf_idx(db), .write_req(req),
        .write_req_ack(ack), .write_en(we), .write_data(pixel),
        .SD_nCS(), .SD_DCLK(), .SD_MOSI(), .SD_MISO(1'b1)
    );
    initial begin
        force dut.sd_init_done = init_done;
        force dut.sd_sec_read_data = sector_data;
        force dut.sd_sec_read_data_valid = data_valid;
        force dut.sd_sec_read_end = sector_end;
    end
    function [7:0] bmp_byte(input integer pos);
        case (pos)
            0: bmp_byte = bad_header ? 0 : 8'h42;
            1: bmp_byte = 8'h4d;
            2: bmp_byte = 66; // 54-byte header + four RGB pixels
            10: bmp_byte = 54;
            14: bmp_byte = 40;
            18: bmp_byte = 4;
            22: bmp_byte = 1;
            26: bmp_byte = 1;
            28: bmp_byte = 24;
            default: bmp_byte = pos >= 54 && pos < 66 ? (8'h55 + dut.sd_sec_read_addr[3:0]) : 0;
        endcase
    endfunction
    // Model a sector transfer with gaps between bytes.
    integer b;
    initial forever begin
        @(negedge clk);
        if (!rst && dut.sd_sec_read) begin
            for (b = 0; b < 512; b = b + 1) begin
                sector_data = bmp_byte(b);
                data_valid = 1;
                @(negedge clk);
                data_valid = 0;
                @(negedge clk);
            end
            sector_end = 1;
            @(negedge clk);
            sector_end = 0;
            @(negedge clk);
        end
    end
    always @(posedge clk) begin
            ack_pipe <= {ack_pipe[2:0], req};
            ack <= ack_pipe[3];
        if (rst) begin
            pixels <= 0;
            finish_toggle <= 0;
            old_busy <= 0;
            commits <= 0;
            finish_pending <= 0;
            ack_pipe <= 0;
        end else begin
            if (we) begin
                if (pixels == 3) begin
                    pixels <= 0;
                    finish_pending <= 1;
                end else pixels <= pixels + 1;
            end
            old_busy <= dut.load_busy;
            if (finish_pending && !hold_finish) begin
                finish_toggle <= ~finish_toggle;
                finish_pending <= 0;
            end
            if (dut.load_busy && dut.source_done_now && dut.write_finish_now &&
                (dut.write_started_seen || req)) commits <= commits + 1;
        end
    end
    task tick(input integer n);
        repeat(n) @(negedge clk);
    endtask
    task next_key;
        key_next = 0; tick(25); key_next = 1; tick(25);
    endtask
    task drain;
        integer n;
        begin
            n = 0;
            while ((dut.load_busy || dut.next_req_pending || dut.prev_req_pending) && n < 15000) begin
                tick(1); n = n + 1;
            end
            if (n == 15000) $fatal(1, "requests did not drain");
            tick(2);
        end
    endtask
    integer i, before_count, ne, pe, se, start_base;
    reg [1:0] saved_idx, saved_buf;
    initial begin
        tick(5); rst = 0; init_done = 1;
        wait(dut.scan_done);
        bad_header = 1; tick(1200);
        if (valid || dut.first_image_committed) $fatal(1, "bad first image was displayed");
        bad_header = 0;
        wait(valid); tick(3);
        $display("PASS first image retries after header rejection and commits only on success");
        before_count = commits;
        next_key();
        repeat(8) next_key();
        drain();
        if (commits - before_count != 2) $fatal(1, "same direction did not coalesce");
        $display("PASS rapid same-key requests coalesce into current + one pending load");
        before_count = commits;
        next_key();
        key_auto = 0; tick(1030); key_auto = 1; tick(25);
        next_key();
        if (!dut.prev_req_pending || !dut.next_req_pending)
            $fatal(1, "opposite pending request lost");
        drain();
        if (commits - before_count != 3 || dut.auto_play_en)
            $fatal(1, "next/previous arbitration or long/short exclusion failed");
        $display("PASS both directions drain with next priority; long hold leaves autoplay off");
        for (i = 0; i < 20; i = i + 1) begin
            next_key(); next_key(); drain();
        end
        $display("PASS 20 rounds of back-to-back loads");
        saved_idx = dut.img_idx; saved_buf = db; before_count = commits;
        bad_header = 1;
        next_key(); tick(2500);
        if (dut.load_busy || !dut.bmp_ready || !valid ||
            dut.img_idx != saved_idx || db != saved_buf || commits != before_count)
            $fatal(1, "header rejection did not release busy and preserve image");
        repeat(3) next_key();
        drain();
        if (commits != before_count || db != saved_buf) $fatal(1, "failed load committed");
        bad_header = 0; next_key(); drain();
        if (commits != before_count + 1) $fatal(1, "good load after rejection failed");
        $display("PASS rejected headers release busy, preserve image, and allow later keys");
        // First load fails; next request is already pending and must survive failure.
        before_count = commits;
        bad_header = 1; next_key(); next_key(); bad_header = 0;
        drain();
        if (commits != before_count + 1) $fatal(1, "pending request lost on failure");
        $display("PASS pending request survives header rejection");
        // A real write in flight must NOT be aborted just because source is idle.
        before_count = commits; saved_buf = db;
        hold_finish = 1; next_key(); tick(2500);
        if (!dut.load_busy || !dut.source_done_seen || !dut.write_started_seen ||
            commits != before_count || db != saved_buf)
            $fatal(1, "in-flight write was released early");
        hold_finish = 0; drain();
        if (commits != before_count + 1) $fatal(1, "delayed write did not commit");
        $display("PASS real writes wait for SDRAM completion");
        ne = next_events; before_count = commits;
        key_next = 0; tick(2000); key_next = 1; tick(25); drain();
        if (next_events != ne + 1 || commits != before_count + 1)
            $fatal(1, "held KEY1 repeated");
        next_key(); drain();
        if (next_events != ne + 2) $fatal(1, "KEY1 failed to rearm");
        $display("PASS KEY1 two-second equivalent hold and release/repress");
        pe = prev_events; se = short_events;
        key_auto = 0; tick(998); key_auto = 1; tick(25);
        if (short_events != se + 1 || prev_events != pe || !dut.auto_play_en)
            $fatal(1, "below-threshold release classification");
        key_auto = 0; tick(25); key_auto = 1; tick(25);
        if (short_events != se + 2 || dut.auto_play_en)
            $fatal(1, "short press did not toggle exactly once");
        se = short_events; pe = prev_events; before_count = commits;
        key_auto = 0; tick(1025); key_auto = 1; tick(25); drain();
        if (prev_events != pe + 1 || short_events != se || dut.auto_play_en || commits != before_count + 1)
            $fatal(1, "above-threshold long/short exclusion");
        $display("PASS KEY2 threshold boundaries and short/long exclusion");
        before_count = commits; pe = prev_events; se = short_events;
        hold_finish = 1; next_key();
        key_auto = 0; tick(2100); key_auto = 1; tick(25);
        if (!dut.prev_req_pending || prev_events != pe + 1 || short_events != se)
            $fatal(1, "busy long press lost or repeated");
        hold_finish = 0; drain();
        if (commits != before_count + 2) $fatal(1, "busy previous request execution count");
        $display("PASS held KEY2 queues exactly one request during delayed completion");
        // Arrange an expiry on the actual stable KEY1 edge, without forcing the event.
        key_auto = 0; tick(25); key_auto = 1; tick(25);
        key_next = 0;
        wait(dut.key1_press_event); @(negedge clk);
        dut.auto_cnt = 2999;
        @(posedge clk); #1;
        if (dut.load_start_pulse || !dut.next_req_pending)
            $fatal(1, "autoplay stole manual event cycle");
        @(negedge clk); key_next = 1; tick(25); drain();
        key_auto = 0; tick(25); key_auto = 1; tick(25);
        if (dut.auto_play_en) $fatal(1, "autoplay shutdown failed");
        $display("PASS autoplay expiry yields to stable manual edge");
        before_count = commits; start_base = starts; saved_idx = dut.img_idx;
        hold_finish = 1;
        next_key(); next_key();
        key_auto = 0; tick(1030); key_auto = 1; tick(25);
        hold_finish = 0; drain();
        if (starts != start_base + 3 || commits != before_count + 3 ||
            started_idx[start_base] != ((saved_idx + 1) % 4) ||
            started_idx[start_base+1] != ((saved_idx + 2) % 4) ||
            started_idx[start_base+2] != ((saved_idx + 1) % 4))
            $fatal(1, "four-image direction priority/order failed");
        $display("PASS four-image next/next/previous execution order");
        // Isolate arbitration collision: old pending is consumed while a new event arrives.
        @(negedge clk); dut.next_req_pending = 1;
        force dut.key1_press_event = 1;
        @(posedge clk); #1;
        if (!dut.load_start_pulse || !dut.next_req_pending)
            $fatal(1, "same-cycle next capture lost");
        @(negedge clk); release dut.key1_press_event; drain();
        @(negedge clk); dut.prev_req_pending = 1;
        force dut.prev_event = 1;
        @(posedge clk); #1;
        if (!dut.load_start_pulse || !dut.prev_req_pending)
            $fatal(1, "same-cycle previous capture lost");
        @(negedge clk); release dut.prev_event; tick(2); drain();
        $display("PASS simultaneous pending consumption and new event capture");
        // Expiry at the long-event production edge must not preempt the registered event.
        key_auto = 0; tick(25); key_auto = 1; tick(25);
        key_auto = 0;
        wait(dut.key2_long_due); @(negedge clk); dut.auto_cnt = 2999;
        @(posedge clk); #1;
        if (dut.load_start_pulse || !dut.prev_event)
            $fatal(1, "autoplay preempted KEY2 threshold");
        tick(25); key_auto = 1; tick(25); drain();
        key_auto = 0; tick(25); key_auto = 1;
        wait(dut.key2_release_event); @(negedge clk); dut.auto_cnt = 2999;
        @(posedge clk); #1;
        if (dut.load_start_pulse) $fatal(1, "autoplay preempted short release");
        tick(3);
        if (dut.auto_play_en || dut.auto_cnt != 0) $fatal(1, "short release did not reset autoplay");
        $display("PASS autoplay expiry at KEY2 threshold and short release");
        $finish;
    end
    initial begin #3000000; $fatal(1, "simulation watchdog"); end
endmodule
