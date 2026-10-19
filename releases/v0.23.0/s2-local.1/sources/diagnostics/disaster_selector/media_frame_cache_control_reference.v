`timescale 1ns/1ps
// Four logical frame banks. All ports are synchronous to the SD control clock.
// Integrated through sd_card_bmp's scan/load/display adapters in S3.
// Adapters must report load success only after parser success AND write drain.
// Requests/parameters stay stable until acceptance; display_ack means the
// reader actually committed at a frame boundary, not merely queued a target.
// Cancel supersedes an offered/accepted load and is held until cancel_ack;
// that acknowledgement must mean source stopped, burst finished and FIFO clear.
module media_frame_cache_control_reference #(parameter PAUSE_ENABLE=0,STRICT_FIRST_ENABLE=0)(
 input pause,strict_first,
    input clk, rst,
    input rescan_event,
    output scan_request,
    input scan_accept,
    input scan_result_valid, scan_success,
    input [2:0] scan_image_count,
    output scan_result_ready,
    output scan_busy,

    input request_valid,
    input [1:0] request_image,
    input request_manual,
    output request_ready,
    output [3:0] request_ready_by_image,
    output foreground_busy,

    output load_request,
    input load_accept,
    output reg [1:0] load_image, load_bank,
    input load_result_valid, load_success, load_timeout,
    output load_result_ready,
    output cancel_request,
    input cancel_ack,
    input communication_fault,
    output storage_busy,
    output reg storage_stopped,

    output reg display_request,
    output reg [1:0] display_image, display_bank,
    input display_ack,
    output reg display_valid,
    output reg [1:0] current_image, current_bank,
    output reg first_image_committed,
    // Audio/panel event, held for backpressure. Background completion never
    // writes this channel. current_* describe the actual reader immediately.
    output reg committed_valid,
    output reg [1:0] committed_image,
    input committed_ready,

    output reg [2:0] image_count,
    output reg [3:0] cache_valid, cache_failed,
    output [7:0] cache_banks,
    output reg cache_complete, cache_hit, request_failed, load_failed,
    output reg retry_event,
    output reg [1:0] cache_complete_image, cache_hit_image, failed_image
);
    localparam [1:0] SCAN_ISSUE=0, SCAN_WAIT=1, RUN=2, QUIESCE=3;
    localparam [1:0] LOAD_IDLE=0, LOAD_ISSUE=1, LOAD_WAIT=2, LOAD_CANCEL=3;
    reg [1:0] phase, load_state;
    reg [1:0] bank_map [0:3];
    reg foreground_pending;
    reg foreground_manual;
    reg [1:0] foreground_image;
    reg [2:0] image_last;   // always image_count-1, written on the same edges
    reg retry_used;

    assign cache_banks = {bank_map[3],bank_map[2],bank_map[1],bank_map[0]};
    assign scan_request = phase == SCAN_ISSUE;
    assign scan_result_ready = phase == SCAN_WAIT;
    assign scan_busy = phase != RUN;
    assign storage_busy = load_state != LOAD_IDLE;
    assign foreground_busy = foreground_pending || display_request || committed_valid;
    wire request_window = phase == RUN && !(PAUSE_ENABLE && pause) && !rescan_event && !communication_fault &&
                          first_image_committed && !foreground_busy;
    // Decode eligibility before selecting the owner target. The scenario
    // owner can use its own index directly, avoiding the unrelated player
    // wrap/preview mux in TD09's cache-ready -> scenario sent path.
    genvar ready_entry;
    generate for(ready_entry=0;ready_entry<4;ready_entry=ready_entry+1)begin:g_request_ready
        assign request_ready_by_image[ready_entry] = request_window && (image_count > ready_entry) &&
                           (!storage_stopped || (request_manual && cache_valid[ready_entry]));
    end endgenerate
    assign request_ready = request_ready_by_image[request_image];
    assign load_request = load_state == LOAD_ISSUE;
    assign load_result_ready = load_state == LOAD_WAIT || load_state == LOAD_CANCEL;
    assign cancel_request = load_state == LOAD_CANCEL;
    wire accept_request = request_valid && request_ready;
    wire stop_load = phase == QUIESCE || (phase == RUN && rescan_event) || communication_fault;

    reg [3:0] occupied;
    reg free_found, candidate_found;
    reg [1:0] free_bank, candidate_image;
    integer i, b, n;
    // No eviction during an epoch. The old display bank remains reserved even
    // after rescan invalidates the old directory's cache entries.
    always @* begin
        // Decode each physical bank in parallel. The equivalent dynamic
        // bit writes formed a serial mux chain on TD25's allocation path.
        for (b=0; b<4; b=b+1)
            occupied[b] = (cache_valid[0] && bank_map[0] == b[1:0]) ||
                          (cache_valid[1] && bank_map[1] == b[1:0]) ||
                          (cache_valid[2] && bank_map[2] == b[1:0]) ||
                          (cache_valid[3] && bank_map[3] == b[1:0]) ||
                          (display_valid && current_bank == b[1:0]) ||
                          (storage_busy && load_bank == b[1:0]);
        // Availability is a parallel reduction, independent of the priority
        // encoder. Arbitration only needs this bit; do not serialize it
        // through the four bank-selection muxes.
        free_found = !(&occupied); free_bank = 0;
        candidate_found = 0; candidate_image = 0;
        for (n=0; n<4; n=n+1) begin
            if (!candidate_found && n < image_count && !cache_valid[n] && !cache_failed[n]) begin
                candidate_found = 1; candidate_image = n[1:0];
            end
        end
        if (!occupied[0]) free_bank = 0;
        else if (!occupied[1]) free_bank = 1;
        else if (!occupied[2]) free_bank = 2;
        else if (!occupied[3]) free_bank = 3;
    end

    // Decode each entry independently. Dynamic partial vector writes infer
    // serial priority muxes through request arbitration in the TD mapper.
    // Preserve the original load -> phase -> manual-clear priority exactly.
    genvar entry;
    generate for(entry=0;entry<4;entry=entry+1)begin:g_cache_flags
        always @(posedge clk or posedge rst)begin
            if(rst)begin cache_valid[entry]<=0;cache_failed[entry]<=0;end
            else if(phase==QUIESCE && load_state==LOAD_IDLE && !display_request && !committed_valid)begin
                cache_valid[entry]<=0;cache_failed[entry]<=0;
            end else begin
                if(!stop_load && load_state==LOAD_WAIT && load_result_valid && !load_timeout && load_image==entry)begin
                    if(load_success)begin cache_valid[entry]<=1;cache_failed[entry]<=0;end
                    else if(retry_used)cache_failed[entry]<=1;
                end
                if(phase==RUN && !rescan_event && accept_request && request_manual && request_image==entry)
                    cache_failed[entry]<=0;
            end
        end
    end endgenerate

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            phase <= SCAN_ISSUE; load_state <= LOAD_IDLE;
            image_count <= 0; image_last <= 3'd7;
            for (i=0; i<4; i=i+1) bank_map[i] <= 0;
            foreground_pending <= 0; foreground_manual <= 0; foreground_image <= 0; retry_used <= 0;
            load_image <= 0; load_bank <= 0; storage_stopped <= 0;
            display_request <= 0; display_image <= 0; display_bank <= 0;
            display_valid <= 0; current_image <= 0; current_bank <= 0;
            first_image_committed <= 0; committed_valid <= 0; committed_image <= 0;
            cache_complete <= 0; cache_hit <= 0; request_failed <= 0; load_failed <= 0; retry_event <= 0;
            cache_complete_image <= 0; cache_hit_image <= 0; failed_image <= 0;
        end else begin
            cache_complete <= 0; cache_hit <= 0; request_failed <= 0; load_failed <= 0; retry_event <= 0;
            if (committed_valid && committed_ready) committed_valid <= 0;
            // Never abort an issued display commit: rescan waits for ownership
            // to transfer before invalidating the directory and allocating banks.
            if (display_request && display_ack) begin
                display_request <= 0;
                display_valid <= 1;
                current_image <= display_image; current_bank <= display_bank;
                committed_valid <= 1; committed_image <= display_image;
                first_image_committed <= 1;
                foreground_pending <= 0;
            end

            if (communication_fault) storage_stopped <= 1;
            if (stop_load && load_state != LOAD_IDLE && load_state != LOAD_CANCEL) begin
                load_state <= LOAD_CANCEL;
            end else case (load_state)
                LOAD_ISSUE: if (load_accept) load_state <= LOAD_WAIT;
                LOAD_WAIT: if (load_result_valid) begin
                    if (load_timeout) begin
                        storage_stopped <= 1;
                        load_state <= LOAD_IDLE;
                        load_failed <= 1; failed_image <= load_image;
                    end else if (load_success) begin
                        cache_complete <= 1; cache_complete_image <= load_image;
                        load_state <= LOAD_IDLE;
                    end else if (!retry_used) begin
                        retry_used <= 1;
                        retry_event <= 1;
                        load_state <= LOAD_ISSUE;
                    end else begin
                        if(STRICT_FIRST_ENABLE && strict_first && !first_image_committed)storage_stopped<=1;
                        load_failed <= 1; failed_image <= load_image;
                        load_state <= LOAD_IDLE;
                    end
                end
                LOAD_CANCEL: if (cancel_ack) load_state <= LOAD_IDLE;
                default: begin end
            endcase

            case (phase)
                SCAN_ISSUE: if (scan_accept) phase <= SCAN_WAIT;
                SCAN_WAIT: if (scan_result_valid) begin
                    phase <= RUN;
                    image_count <= scan_success ? scan_image_count : 3'd0;
                    image_last <= (scan_success ? scan_image_count : 3'd0) - 3'd1;
                    if (!scan_success) storage_stopped <= 1;
                    if (scan_success && scan_image_count != 0) begin
                        foreground_pending <= 1;
                        foreground_manual <= 0;
                        foreground_image <= 0;
                    end
                end
                QUIESCE: if (load_state == LOAD_IDLE && !display_request && !committed_valid) begin
                    image_count <= 0; image_last <= 3'd7;
                    foreground_pending <= 0; first_image_committed <= 0;
                    storage_stopped <= 0;
                    phase <= SCAN_ISSUE;
                end
                RUN: begin
                    if (rescan_event) begin
                        phase <= QUIESCE;
                    end else begin
                        if (accept_request) begin
                            foreground_pending <= 1;
                            foreground_manual <= request_manual;
                            foreground_image <= request_image;
                            if (cache_valid[request_image]) begin
                                cache_hit <= 1; cache_hit_image <= request_image;
                            end
                        end
                        if (foreground_pending && !display_request && !committed_valid) begin
                            if (cache_valid[foreground_image]) begin
                                display_image <= foreground_image;
                                display_bank <= bank_map[foreground_image];
                                display_request <= 1;
                            end else if (storage_stopped || communication_fault) begin
                                foreground_pending <= 0;
                                request_failed <= 1;
                            end else if (cache_failed[foreground_image]) begin
                                if (!foreground_manual && first_image_committed) begin
                                    // Preserve AUTO's existing bad-file fallback.
                                    // Walk one index per cycle rather than build
                                    // a combinational four-entry search. The
                                    // currently displayed valid entry bounds it.
                                    foreground_image <= ({1'b0,foreground_image} == image_last) ?
                                                        2'd0 : foreground_image+2'd1;
                                end else begin
                                    foreground_pending <= 0;
                                    request_failed <= 1;
                                end
                            end
                        end
                        // Do not start background work on the edge accepting a
                        // foreground target. An in-progress file finishes first.
                        if (!(PAUSE_ENABLE && pause) && load_state == LOAD_IDLE && !storage_stopped && !communication_fault &&
                            !accept_request && free_found) begin
                            if (foreground_pending) begin
                                if (!cache_valid[foreground_image] && !cache_failed[foreground_image]) begin
                                    load_image <= foreground_image; load_bank <= free_bank;
                                    bank_map[foreground_image] <= free_bank;
                                    retry_used <= 0; load_state <= LOAD_ISSUE;
                                end
                            end else if (candidate_found) begin
                                if (!first_image_committed) begin
                                    // A bad first file is retried once, then try
                                    // the next directory entry without losing the old picture.
                                    foreground_pending <= 1; foreground_manual <= 0;
                                    foreground_image <= candidate_image;
                                end else begin
                                    load_image <= candidate_image; load_bank <= free_bank;
                                    bank_map[candidate_image] <= free_bank;
                                    retry_used <= 0; load_state <= LOAD_ISSUE;
                                end
                            end
                        end
                    end
                end
                default: phase <= SCAN_ISSUE;
            endcase
        end
    end
endmodule
