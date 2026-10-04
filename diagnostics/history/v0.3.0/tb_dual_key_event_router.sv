`timescale 1ns/1ps

module tb_dual_key_event_router;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1;
    reg key1_stable = 1, key2_stable = 1;
    reg key1_press_event = 0, key2_press_event = 0;
    reg key1_release_event = 0, key2_release_event = 0;
    wire combo_active, combo_press_event, combo_release_event;
    wire key1_single_press_event, key2_single_press_event;
    wire key1_single_release_event, key2_single_release_event;
    integer combo_presses = 0, combo_releases = 0;
    integer key1_singles = 0, key2_singles = 0;

    dual_key_event_router #(.COMBO_WINDOW_CYCLES(10)) dut (
        .clk(clk), .rst(rst),
        .key1_stable(key1_stable), .key2_stable(key2_stable),
        .key1_press_event(key1_press_event), .key2_press_event(key2_press_event),
        .key1_release_event(key1_release_event), .key2_release_event(key2_release_event),
        .gesture_active(), .combo_active(combo_active), .combo_press_event(combo_press_event),
        .combo_release_event(combo_release_event),
        .key1_single_press_event(key1_single_press_event),
        .key2_single_press_event(key2_single_press_event),
        .key1_single_release_event(key1_single_release_event),
        .key2_single_release_event(key2_single_release_event)
    );

    always @(posedge clk) begin
        if (combo_press_event) combo_presses = combo_presses + 1;
        if (combo_release_event) combo_releases = combo_releases + 1;
        if (key1_single_press_event) key1_singles = key1_singles + 1;
        if (key2_single_press_event) key2_singles = key2_singles + 1;
    end

    task tick(input integer n);
        repeat (n) @(posedge clk);
    endtask

    task press1;
        begin key1_stable = 0; key1_press_event = 1; tick(1); key1_press_event = 0; end
    endtask
    task press2;
        begin key2_stable = 0; key2_press_event = 1; tick(1); key2_press_event = 0; end
    endtask
    task release_both;
        begin key1_stable = 1; key2_stable = 1; key1_release_event = 1; key2_release_event = 1; tick(1); key1_release_event = 0; key2_release_event = 0; end
    endtask

    initial begin
        tick(2); rst = 0;

        // KEY1 first, KEY2 inside the 10-cycle window: combo only.
        press1; tick(3); press2; tick(2);
        if (combo_presses != 1 || key1_singles != 0 || key2_singles != 0)
            $fatal(1, "KEY1-first chord emitted a single-key event");
        release_both; tick(1);
        if (combo_releases != 1) $fatal(1, "KEY1-first chord release missing");

        // KEY2 first, KEY1 inside the window: combo only.
        press2; tick(3); press1; tick(2);
        if (combo_presses != 2 || key1_singles != 0 || key2_singles != 0)
            $fatal(1, "KEY2-first chord emitted a single-key event");
        release_both; tick(1);

        // KEY1 held beyond the window, then released: single KEY1 event.
        press1; tick(12);
        if (key1_singles != 1 || combo_presses != 2)
            $fatal(1, "single KEY1 timeout classification failed");
        key1_stable = 1; key1_release_event = 1; tick(1); key1_release_event = 0;

        // KEY2 held beyond the window, then released: single KEY2 event.
        press2; tick(12);
        if (key2_singles != 1 || combo_presses != 2)
            $fatal(1, "single KEY2 timeout classification failed");
        key2_stable = 1; key2_release_event = 1; tick(1); key2_release_event = 0;

        $display("PASS dual-key chord window and single-event exclusion");
        $finish;
    end
endmodule
