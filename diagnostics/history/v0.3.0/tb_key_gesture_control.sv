`timescale 1ns/1ps
module tb_key_gesture_control;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1, enable = 1, key1 = 1, key2 = 1;
    wire next_event, prev_event, short_event, combo_event, activity;
    wire auto_en, next_pending, prev_pending, auto_tick, request;
    wire next_req, prev_req, auto_req;
    integer cycle = 0, stable_cycle = -1, long_cycle = -1;
    integer nexts = 0, prevs = 0, shorts = 0, combos = 0, auto_requests = 0;
    key_gesture_control #(.CLK_FREQ_HZ(1000), .LONG_PRESS_MS(1000), .COMBO_WINDOW_MS(100)) dut (
        .clk(clk), .rst(rst), .enable(enable), .key_next(key1), .key_auto(key2),
        .next_event(next_event), .previous_event(prev_event),
        .auto_toggle_event(short_event), .combo_event(combo_event), .manual_activity(activity)
    );
    media_player_control #(.AUTO_PLAY_CYCLES(3000)) player (
        .clk(clk), .rst(rst), .enable(enable), .scan_done(1'b1), .display_valid(1'b1),
        .load_busy(1'b0), .first_image_committed(1'b1), .manual_activity(activity),
        .request_accept(request), .image_count(3'd4), .current_image(2'd0), .mode(2'd0),
        .next_event(next_event), .previous_event(prev_event), .auto_toggle_event(short_event),
        .auto_play_en(auto_en), .next_pending(next_pending), .previous_pending(prev_pending),
        .auto_tick(auto_tick), .load_request(request), .next_load_request(next_req),
        .previous_load_request(prev_req), .auto_load_request(auto_req), .target_image()
    );
    // Observe after NBA: duration is measured from the actual stable transition.
    reg previous_stable = 1, previous_activity = 0;
    integer idle_cycle = 0, accepted_cycle = 0;
    always @(posedge clk) begin
        // Count requests at the edge on which the consumer accepts them.
        if (!rst && auto_req) begin
            auto_requests = auto_requests + 1;
            accepted_cycle = cycle + 1;
        end
        #1;
        cycle = cycle + 1;
        if (!rst) begin
            if (previous_stable && !dut.key2_stable) stable_cycle = cycle;
            if (prev_event) begin prevs = prevs + 1; long_cycle = cycle; end
            if (short_event) shorts = shorts + 1;
            if (next_event) nexts = nexts + 1;
            if (combo_event) combos = combos + 1;
            if (previous_activity && !activity) idle_cycle = cycle;
            if (activity && auto_req) $fatal(1, "autoplay allowed during gesture");
        end
        previous_stable = dut.key2_stable;
        previous_activity = activity;
    end
    task tick(input integer n); repeat(n) @(negedge clk); endtask
    task tap2; key2 = 0; tick(50); key2 = 1; tick(30); endtask
    integer p, s, c, a, n;
    initial begin
        tick(3); rst = 0;
        // No injected internal timer: prove exact duration from stable input.
        p = prevs; s = shorts;
        key2 = 0; tick(1050);
        if (prevs !== p + 1 || long_cycle - stable_cycle !== 1000)
            $fatal(1, "long timing includes chord delay: elapsed=%0d", long_cycle - stable_cycle);
        tick(1200); key2 = 1; tick(30);
        if (prevs !== p + 1 || shorts !== s || dut.key2_held !== 0)
            $fatal(1, "held long repeats or release leaks short");
        $display("PASS stable-edge long threshold is exactly 1000 cycles and fires once");

        // Matching debounce delays preserve the raw hold duration.
        s = shorts; p = prevs;
        key2 = 0; tick(999); key2 = 1; tick(30);
        if (shorts !== s + 1 || prevs !== p) $fatal(1, "999-cycle press was not short");
        key2 = 0; tick(1001); key2 = 1; tick(30);
        if (shorts !== s + 1 || prevs !== p + 1 || long_cycle - stable_cycle !== 1000)
            $fatal(1, "1001-cycle press was not exclusive long");
        tap2();
        if (auto_en !== 0) $fatal(1, "short toggle rearm failed");
        $display("PASS real-window threshold sides and quick tap recovery");

        // Expiry collides with first stable edge; then with chord window middle.
        tap2();
        if (auto_en !== 1) $fatal(1, "autoplay not enabled");
        a = auto_requests; n = nexts; c = combos; s = shorts; p = prevs;
        key1 = 0;
        wait(!dut.key1_stable); @(negedge clk); player.auto_count = 2999;
        tick(1);
        if (auto_requests !== a || player.auto_count !== 0) $fatal(1, "stable edge lost priority");
        tick(25); player.auto_count = 2999; tick(1);
        if (auto_requests !== a || player.auto_count !== 0) $fatal(1, "chord window lost priority");
        key2 = 0; tick(1200); key1 = 1; tick(30);
        if (activity !== 1 || nexts !== n || prevs !== p || shorts !== s || combos !== c + 1)
            $fatal(1, "chord duration or partial release leaked an event");
        key2 = 1; tick(30);
        if (auto_en !== 1 || auto_requests !== a || activity !== 0) $fatal(1, "chord changed autoplay");
        // Full 3-second wait after the event pipeline has drained.
        wait(auto_requests == a + 1); @(negedge clk);
        if (auto_requests !== a + 1 || accepted_cycle - idle_cycle !== 3000)
            $fatal(1, "autoplay did not restart a full period: %0d", accepted_cycle - idle_cycle);
        tap2();
        $display("PASS stable edge, chord wait and partial release block autoplay then resume");

        // Overlap after classification stays single; KEY2 still times from its edge.
        n = nexts; p = prevs; c = combos;
        key1 = 0; tick(180); key2 = 0; tick(1050);
        key1 = 1; key2 = 1; tick(30);
        if (nexts !== n + 1 || prevs !== p + 1 || combos !== c || long_cycle - stable_cycle !== 1000)
            $fatal(1, "late overlapping single timing changed");
        $display("PASS outside-window overlap keeps independent exact long timing");
        // Reset during pending recognition cancels it, then accepts fresh input.
        key2 = 0; tick(50); rst = 1; key2 = 1; tick(3); rst = 0; tick(30);
        s = shorts; tap2();
        if (shorts !== s + 1 || dut.key2_held !== 0) $fatal(1, "reset recovery");
        $display("PASS reset cancels pending gesture and rearms");
        $finish;
    end
    initial begin #500000; $fatal(1, "watchdog"); end
endmodule
