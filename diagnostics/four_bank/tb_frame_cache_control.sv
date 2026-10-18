`timescale 1ns/1ps
module tb_frame_cache_control;
    reg clk=0, rst=1;
    always #5 clk=~clk;
    reg rescan_event=0, scan_accept=0, scan_result_valid=0, scan_success=0;
    reg [2:0] scan_image_count=0;
    wire scan_request, scan_result_ready, scan_busy;
    reg direct_request=0, direct_manual=1;
    reg [1:0] direct_image=0;
    wire request_valid, request_manual, request_ready, foreground_busy;
    wire [1:0] request_image;
    reg load_accept=0, load_result_valid=0, load_success=0, load_timeout=0;
    reg cancel_ack=0, communication_fault=0;
    wire load_request, load_result_ready, cancel_request, storage_busy, storage_stopped;
    wire [1:0] load_image, load_bank;
    reg display_ack=0, committed_ready=1;
    wire display_request, display_valid, first_image_committed, committed_valid;
    wire [1:0] display_image, display_bank, current_image, current_bank, committed_image;
    wire [2:0] image_count;
    wire [3:0] cache_valid, cache_failed;
    wire [7:0] cache_banks;
    wire cache_complete, cache_hit, request_failed, load_failed, retry_event;
    wire [1:0] cache_complete_image, cache_hit_image, failed_image;
    reg use_player=0, next_event=0, previous_event=0, auto_toggle=0;
    wire player_request, player_next, player_previous, player_auto, player_accept;
    wire auto_en, next_pending, previous_pending, auto_tick;
    wire [1:0] player_target;
    assign request_valid=use_player ? player_request : direct_request;
    assign request_image=use_player ? player_target : direct_image;
    assign request_manual=use_player ? (player_next || player_previous) : direct_manual;
    assign player_accept=use_player && request_ready && player_request;
    media_player_control #(.AUTO_PLAY_CYCLES(20)) player (
        .clk(clk),.rst(rst),.enable(use_player && !scan_busy),.scan_done(!scan_busy),
        .display_valid(display_valid),.load_busy(foreground_busy),
        .first_image_committed(first_image_committed),
        .manual_activity(next_event || previous_event),.request_accept(player_accept),
        .image_count(image_count),.current_image(current_image),.mode(2'd0),
        .next_event(next_event),.previous_event(previous_event),.auto_toggle_event(auto_toggle),
        .auto_play_en(auto_en),.next_pending(next_pending),.previous_pending(previous_pending),
        .auto_tick(auto_tick),.load_request(player_request),.next_load_request(player_next),
        .previous_load_request(player_previous),.auto_load_request(player_auto),.target_image(player_target)
    );
    wire [3:0] request_ready_by_image;
    media_frame_cache_control dut (.*);

    integer cycles=0, accepted_loads=0, commits=0, completions=0, hits=0, failures=0;
    reg held_display=0, held_load=0;
    reg [3:0] saved_display, saved_load;
    integer a,b;
    always @(posedge clk) begin
        cycles=cycles+1;
        if(cycles>20000) $fatal(1,"watchdog");
        if(!rst) begin
            if(held_display && {display_image,display_bank} !== saved_display)
                $fatal(1,"display target changed before frame acknowledgement");
            if(held_load && {load_image,load_bank} !== saved_load)
                $fatal(1,"load identity changed before completion/cancel");
            if(load_request && load_accept) accepted_loads=accepted_loads+1;
            if(display_request && display_ack) commits=commits+1;
            held_display=display_request && !display_ack;
            saved_display={display_image,display_bank};
            held_load=storage_busy && !(load_result_ready && load_result_valid) && !(cancel_request && cancel_ack);
            saved_load={load_image,load_bank};
        end else begin held_display=0; held_load=0; end
        #2;
        if(!rst) begin
            if(cache_complete) completions=completions+1;
            if(cache_hit) hits=hits+1;
            if(request_failed) failures=failures+1;
            if(storage_busy && display_valid && load_bank==current_bank)
                $fatal(1,"overwriting visible bank %0d",current_bank);
            for(a=0;a<4;a=a+1) for(b=a+1;b<4;b=b+1)
                if(cache_valid[a] && cache_valid[b] && cache_banks[a*2+:2]==cache_banks[b*2+:2])
                    $fatal(1,"duplicate bank ownership");
        end
    end
    task tick; begin @(posedge clk); #3; end endtask
    task check(input bit condition,input string message);
        if(!condition) $fatal(1,"%s (cycle %0d)",message,cycles);
    endtask
    task reset_case;
        begin
            rst=1; rescan_event=0; scan_accept=0; scan_result_valid=0;
            direct_request=0; load_accept=0; load_result_valid=0; cancel_ack=0;
            communication_fault=0; display_ack=0; committed_ready=1;
            use_player=0; next_event=0; previous_event=0; auto_toggle=0;
            repeat(3) tick(); rst=0; tick();
        end
    endtask
    task scan(input integer count,input bit success);
        integer k;
        begin
            k=0; while(!scan_request && k<60) begin tick(); k=k+1; end
            check(scan_request,"scan request missing");
            repeat(3) tick(); check(scan_request,"scan request not held");
            scan_accept=1; tick(); scan_accept=0;
            check(scan_result_ready,"scan result not ready");
            scan_image_count=count; scan_success=success; scan_result_valid=1;
            tick(); scan_result_valid=0; tick();
        end
    endtask
    task expect_load(input integer idx,input integer bank);
        integer k;
        begin
            k=0; while(!load_request && k<60) begin tick(); k=k+1; end
            check(load_request,"load request missing");
            check(load_image==idx,"wrong scheduled image");
            if(bank>=0) check(load_bank==bank,"wrong allocated bank");
            repeat(3) tick();
            check(load_request && load_image==idx,"start request not held");
            load_accept=1; tick(); load_accept=0;
            check(load_result_ready,"load result not ready");
        end
    endtask
    task finish_load(input bit success,input bit timeout_error);
        begin
            check(load_result_ready,"completion without active load");
            load_success=success; load_timeout=timeout_error; load_result_valid=1;
            tick(); load_result_valid=0; load_timeout=0;
        end
    endtask
    task expect_display(input integer idx);
        integer k;
        begin
            k=0; while(!display_request && k<60) begin tick(); k=k+1; end
            check(display_request && display_image==idx,"wrong/missing display request");
        end
    endtask
    task commit_display(input integer idx);
        begin
            expect_display(idx);
            display_ack=1; tick(); display_ack=0;
            check(display_valid && current_image==idx && committed_valid && committed_image==idx,
                  "commit/panel/audio association");
            tick();
        end
    endtask
    task request(input integer idx,input bit manual);
        integer k;
        begin
            direct_image=idx; direct_manual=manual; direct_request=1;
            #1; k=0; while(!request_ready && k<60) begin tick(); k=k+1; end
            check(request_ready,"foreground request not accepted");
            tick(); direct_request=0;
        end
    endtask
    task rescan;
        begin rescan_event=1; tick(); rescan_event=0; end
    endtask
    task finish_cancel;
        integer k;
        begin
            k=0; while(!cancel_request && k<60) begin tick(); k=k+1; end
            check(cancel_request,"cancel missing");
            repeat(4) tick(); check(cancel_request && !scan_request,"scan before cancellation drained");
            cancel_ack=1; tick(); cancel_ack=0; tick();
        end
    endtask
    integer before_loads,before_commits,before_completions,old_bank,k;
    initial begin
        reset_case(); scan(4,1); expect_load(0,0); finish_load(1,0);
        expect_display(0);
        repeat(8) tick();
        check(!display_valid && !load_request,"first image must commit before background preload");
        commit_display(0);
        expect_load(1,1); finish_load(1,0);
        expect_load(2,2);
        before_commits=commits; before_loads=accepted_loads;
        request(1,1); expect_display(1);
        repeat(6) tick(); check(current_image==0,"switch before frame boundary");
        commit_display(1);
        check(accepted_loads==before_loads && storage_busy && load_image==2,"cache hit interrupted prefetch");
        check(hits>0 && commits==before_commits+1,"cache hit/commit event missing");
        // Miss for image 3 must follow the in-flight image 2, not restart it.
        request(3,1); repeat(5) tick(); check(load_image==2 && !display_request,"miss cancelled preload");
        finish_load(1,0); expect_load(3,3); finish_load(1,0); commit_display(3);
        check(cache_valid==4'b1111,"four images not cached");
        before_loads=accepted_loads; before_completions=completions;
        for(k=0;k<12;k=k+1) begin request(k%4,1); commit_display(k%4); end
        repeat(12) tick();
        check(accepted_loads==before_loads && !load_request,"full cache re-read a file");
        check(completions==before_completions,"cache switch fabricated load completion");
        $display("PASS cache: first display, background fill, concurrent hits, full-cache no reads");

        // Foreground image 3 precedes still-unloaded background image 2.
        reset_case(); scan(4,1); expect_load(0,0); finish_load(1,0); commit_display(0);
        expect_load(1,1); request(3,1); finish_load(1,0);
        expect_load(3,2); finish_load(1,0); commit_display(3);
        expect_load(2,3); finish_load(1,0);
        repeat(8) tick(); check(current_image==3 && cache_valid==15,"background completion changed display");
        // A full-cache rescan reserves old bank 2; the new map differs from image index.
        old_bank=current_bank; rescan(); scan(4,1); expect_load(0,0);
        check(current_bank==old_bank && display_valid,"rescan lost old display");
        finish_load(1,0); expect_display(0); repeat(6) tick();
        check(current_bank==old_bank,"old bank released before new first commit");
        commit_display(0); expect_load(1,1); finish_load(1,0);
        expect_load(2,2); finish_load(1,0); expect_load(3,3); finish_load(1,0);
        $display("PASS cache: miss priority, full-cache rescan, old bank released only on commit");

        // Rescan while preload active and a cache-hit display is in flight.
        reset_case(); scan(4,1); expect_load(0,0); finish_load(1,0); commit_display(0);
        expect_load(1,1); finish_load(1,0); expect_load(2,2);
        request(1,1); expect_display(1); rescan(); finish_cancel();
        repeat(5) tick(); check(!scan_request && current_bank==0,"rescan ignored pending display ownership");
        committed_ready=0; commit_display(1);
        repeat(5) tick(); check(!scan_request && committed_valid,"lost buffered audio event during rescan");
        committed_ready=1; tick(); scan(2,1); expect_load(0,0); finish_load(1,0); commit_display(0);
        expect_load(1,1); finish_load(1,0); repeat(8) tick();
        check(cache_valid==3 && image_count==2 && !load_request,"compacted directory count ignored");
        $display("PASS cache: rescan cancels write, completes pending display/audio, compacted count");

        // Display bank 0 forces new first image into bank 1, including failed scans.
        rescan(); scan(0,0); repeat(10) tick();
        check(display_valid && current_bank==0 && cache_valid==0 && !load_request,"scan failure lost old picture");
        rescan(); scan(0,1); repeat(10) tick();
        check(display_valid && !load_request && image_count==0,"empty directory lost old picture");
        rescan(); scan(1,1); expect_load(0,1); finish_load(1,0); commit_display(0);
        check(current_bank==1 && cache_banks[1:0]==1,"logical image incorrectly used as physical bank");
        $display("PASS cache: failed/empty scan keeps picture, non-display bank allocation");

        // One retry; background failures skip, manual request explicitly retries.
        reset_case(); scan(4,1); expect_load(0,0); finish_load(1,0); commit_display(0);
        expect_load(1,1); finish_load(0,0); expect_load(1,1); finish_load(0,0);
        expect_load(2,1); finish_load(1,0); expect_load(3,2); finish_load(1,0);
        repeat(10) tick(); check(cache_failed==2 && cache_valid==13 && !load_request,"failed preload not skipped");
        before_loads=accepted_loads; request(1,0); commit_display(2);
        check(accepted_loads==before_loads && cache_failed==2,"AUTO reloaded failed file instead of skipping it");
        request(1,1); expect_load(1,3); finish_load(1,0); commit_display(1);
        check(cache_valid==15 && cache_failed==0,"manual retry did not recover cache");
        $display("PASS cache: one retry, failed preload skipped, manual retry recovers");

        // Failed first load falls forward; all bad files leave old display intact.
        rescan(); scan(2,1); old_bank=current_bank;
        expect_load(0,0); finish_load(0,0); expect_load(0,0); finish_load(0,0);
        expect_load(1,0); finish_load(1,0); commit_display(1);
        check(current_image==1 && first_image_committed,"first valid fallback not committed");
        rescan(); scan(1,1); expect_load(0,1); finish_load(0,0); expect_load(0,1); finish_load(0,0);
        repeat(15) tick(); check(display_valid && current_bank==0 && !load_request && !first_image_committed,
                                "all-bad new directory lost picture or retried forever");
        $display("PASS cache: first-load retry/fallback, all-bad rescan preserves display");

        // Timeout leaves completed caches usable and stops all future file reads.
        reset_case(); scan(4,1); expect_load(0,0); finish_load(1,0); commit_display(0);
        expect_load(1,1); finish_load(1,0); expect_load(2,2); request(3,1); finish_load(0,1);
        repeat(8) tick(); check(storage_stopped && !foreground_busy && cache_valid==3,"timeout state/cache loss");
        before_loads=accepted_loads; request(1,1); commit_display(1); request(0,1); commit_display(0);
        direct_image=3; direct_request=1; repeat(8) tick(); check(!request_ready,"timeout accepted uncached request");
        direct_request=0; check(accepted_loads==before_loads && !load_request,"timeout restarted SD reads");
        rescan(); scan(1,1); expect_load(0,1); finish_load(1,0); commit_display(0);
        check(!storage_stopped,"rescan did not clear timeout stop");
        $display("PASS cache: timeout retains cache hits, stops reads, rescan recovers");

        // Cancel an offered request before the loader accepts it.
        reset_case(); scan(4,1);
        while(!load_request) tick(); rescan(); finish_cancel(); scan(1,1);
        expect_load(0,0); finish_load(1,0); commit_display(0);
        // Communication fault while actively loading, no load_result needed.
        rescan(); scan(2,1); expect_load(0,1);
        communication_fault=1; tick(); communication_fault=0; finish_cancel();
        repeat(6) tick(); check(storage_stopped && display_valid && current_bank==0 && !load_request,
                               "communication fault failed to cancel/preserve");
        $display("PASS cache: offered-start cancellation and active communication fault");

        // Use the real existing player: background load must not freeze AUTO.
        reset_case(); scan(4,1); expect_load(0,0); finish_load(1,0); commit_display(0);
        expect_load(1,1); finish_load(1,0); expect_load(2,2);
        use_player=1; auto_toggle=1; tick(); auto_toggle=0;
        expect_display(1); check(storage_busy && load_image==2,"AUTO waited for background completion");
        auto_toggle=1; tick(); auto_toggle=0;
        // While this commit is pending, coalesce two nexts and one previous.
        next_event=1; previous_event=1; tick(); next_event=0; previous_event=0;
        tick(); next_event=1; tick(); next_event=0;
        commit_display(1);
        repeat(5) tick(); check(foreground_busy && load_image==2,"next request did not wait for current preload");
        finish_load(1,0); commit_display(2); commit_display(1);
        check(!next_pending && !previous_pending && !auto_en,"pending direction merge/priority failed");
        expect_load(3,3); finish_load(1,0); repeat(8) tick();
        check(current_image==1,"background completion caused extra switch");
        $display("PASS cache: real player AUTO, next-before-previous, same-direction merge");

        // The user can press rescan on the same clock as both endpoint results.
        reset_case(); scan(4,1); expect_load(0,0); finish_load(1,0); commit_display(0);
        expect_load(1,1); finish_load(1,0); expect_load(2,2); request(1,1); expect_display(1);
        rescan_event=1; display_ack=1; load_result_valid=1; load_success=1;
        tick(); rescan_event=0; display_ack=0; load_result_valid=0;
        check(current_bank==1 && !cache_valid[2],"rescan/result collision published discarded frame");
        finish_cancel(); scan(1,1); expect_load(0,0); finish_load(1,0); commit_display(0);
        $display("PASS cache: coincident rescan, load success and display acknowledgement");

        // A just-accepted foreground target wins over a not-yet-issued preload.
        reset_case(); scan(4,1); expect_load(0,0); finish_load(1,0); commit_display(0);
        expect_load(1,1); finish_load(1,0); request(3,1);
        expect_load(3,2); finish_load(1,0); commit_display(3);
        expect_load(2,3); finish_load(1,0); repeat(5) tick();
        check(cache_valid==15 && current_image==3,"acceptance-edge priority failed");
        // Background completion cannot restart the real player's AUTO timer.
        reset_case(); scan(4,1); expect_load(0,0); finish_load(1,0); commit_display(0);
        expect_load(1,1); finish_load(1,0); expect_load(2,2);
        use_player=1; auto_toggle=1; tick(); auto_toggle=0;
        repeat(6) tick(); before_commits=player.auto_count;
        finish_load(1,0); check(player.auto_count>before_commits,"background completion reset AUTO timer");
        expect_load(3,3); finish_load(1,0);
        expect_display(1); commit_display(1);
        check(player.auto_count<3,"display commit did not restart AUTO interval");
        $display("PASS cache: acceptance-edge priority, background completion preserves AUTO interval");

        // A file that fails while AUTO is already waiting gets one retry, then
        // falls forward to the next image without requiring a fresh timer tick.
        reset_case(); scan(3,1); expect_load(0,0); finish_load(1,0); commit_display(0);
        expect_load(1,1); request(1,0); finish_load(0,0); expect_load(1,1); finish_load(0,0);
        expect_load(2,1); finish_load(1,0); commit_display(2);
        check(cache_failed==2 && cache_valid==5,"AUTO failure fallback changed cache ownership");
        $display("PASS cache: AUTO skips known failures and falls forward after in-flight failure");

        $display("PASS frame cache control: loads=%0d commits=%0d cache_completions=%0d hits=%0d request_failures=%0d cycles=%0d",
                  accepted_loads,commits,completions,hits,failures,cycles);
        $finish;
    end
endmodule
