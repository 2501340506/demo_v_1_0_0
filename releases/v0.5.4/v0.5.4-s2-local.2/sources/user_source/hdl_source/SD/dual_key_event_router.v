// KEY1/KEY2 stable-event router.
// Inputs are already synchronized and debounced. A second key pressed within
// COMBO_WINDOW_CYCLES turns the gesture into one combo event; otherwise the
// first key is released as a delayed single-key event.
module dual_key_event_router #(
    parameter integer COMBO_WINDOW_CYCLES = 20_000_000
) (
    input  wire clk,
    input  wire rst,
    input  wire key1_stable,
    input  wire key2_stable,
    input  wire key1_press_event,
    input  wire key2_press_event,
    input  wire key1_release_event,
    input  wire key2_release_event,
    output reg  combo_active,
    output reg  combo_press_event,
    output reg  combo_release_event,
    output reg  key1_single_press_event,
    output reg  key2_single_press_event,
    output reg  key1_single_release_event,
    output reg  key2_single_release_event,
    output wire gesture_active
);
    localparam [2:0] ST_IDLE = 3'd0;
    localparam [2:0] ST_KEY1 = 3'd1;
    localparam [2:0] ST_KEY2 = 3'd2;
    localparam [2:0] ST_COMBO = 3'd3;
    localparam [2:0] ST_SINGLE = 3'd4;
    localparam integer COUNT_WIDTH = (COMBO_WINDOW_CYCLES <= 2) ? 1 : $clog2(COMBO_WINDOW_CYCLES + 1);

    reg [2:0] state;
    reg [COUNT_WIDTH-1:0] window_count;

    assign gesture_active = (state != ST_IDLE) || key1_press_event || key2_press_event ||
        key1_release_event || key2_release_event || key1_single_press_event ||
        key2_single_press_event || key1_single_release_event || key2_single_release_event ||
        combo_press_event || combo_release_event;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= ST_IDLE;
            window_count <= {COUNT_WIDTH{1'b0}};
            combo_active <= 1'b0;
            combo_press_event <= 1'b0;
            combo_release_event <= 1'b0;
            key1_single_press_event <= 1'b0;
            key2_single_press_event <= 1'b0;
            key1_single_release_event <= 1'b0;
            key2_single_release_event <= 1'b0;
        end else begin
            combo_press_event <= 1'b0;
            combo_release_event <= 1'b0;
            key1_single_press_event <= 1'b0;
            key2_single_press_event <= 1'b0;
            key1_single_release_event <= 1'b0;
            key2_single_release_event <= 1'b0;

            case (state)
                ST_IDLE: begin
                    window_count <= {COUNT_WIDTH{1'b0}};
                    if (key1_release_event && key2_stable)
                        key1_single_release_event <= 1'b1;
                    if (key2_release_event && key1_stable)
                        key2_single_release_event <= 1'b1;
                    if (key1_press_event && !key2_stable) begin
                        state <= ST_COMBO;
                        combo_active <= 1'b1;
                        combo_press_event <= 1'b1;
                    end else if (key2_press_event && !key1_stable) begin
                        state <= ST_COMBO;
                        combo_active <= 1'b1;
                        combo_press_event <= 1'b1;
                    end else if (key1_press_event) begin
                        state <= ST_KEY1;
                        window_count <= {{(COUNT_WIDTH-1){1'b0}}, 1'b1};
                    end else if (key2_press_event) begin
                        state <= ST_KEY2;
                        window_count <= {{(COUNT_WIDTH-1){1'b0}}, 1'b1};
                    end
                end
                ST_KEY1: begin
                    if (key2_press_event || key2_stable == 1'b0 && key1_stable == 1'b0) begin
                        state <= ST_COMBO;
                        combo_active <= 1'b1;
                        combo_press_event <= 1'b1;
                        window_count <= {COUNT_WIDTH{1'b0}};
                    end else if (window_count >= COMBO_WINDOW_CYCLES - 1) begin
                        state <= ST_SINGLE;
                        key1_single_press_event <= 1'b1;
                        window_count <= {COUNT_WIDTH{1'b0}};
                    end else begin
                        window_count <= window_count + 1'b1;
                    end
                end
                ST_KEY2: begin
                    if (key1_press_event || key1_stable == 1'b0 && key2_stable == 1'b0) begin
                        state <= ST_COMBO;
                        combo_active <= 1'b1;
                        combo_press_event <= 1'b1;
                        window_count <= {COUNT_WIDTH{1'b0}};
                    end else if (window_count >= COMBO_WINDOW_CYCLES - 1) begin
                        state <= ST_SINGLE;
                        key2_single_press_event <= 1'b1;
                        window_count <= {COUNT_WIDTH{1'b0}};
                    end else begin
                        window_count <= window_count + 1'b1;
                    end
                end
                // Once a single gesture is committed, overlapping keys stay
                // independent until both keys have been released.
                ST_SINGLE: begin
                    key1_single_press_event <= key1_press_event;
                    key2_single_press_event <= key2_press_event;
                    key1_single_release_event <= key1_release_event;
                    key2_single_release_event <= key2_release_event;
                    if (key1_stable && key2_stable)
                        state <= ST_IDLE;
                end
                ST_COMBO: begin
                    if (key1_stable && key2_stable) begin
                        state <= ST_IDLE;
                        combo_active <= 1'b0;
                        combo_release_event <= 1'b1;
                    end
                end
                default: begin
                    state <= ST_IDLE;
                    combo_active <= 1'b0;
                end
            endcase

            // A pending key released before the window expires is still a
            // single key gesture; emit its press and release together.
            if (state == ST_KEY1 && key1_release_event && key2_stable) begin
                state <= ST_IDLE;
                key1_single_press_event <= 1'b1;
                key1_single_release_event <= 1'b1;
            end else if (state == ST_KEY2 && key2_release_event && key1_stable) begin
                state <= ST_IDLE;
                key2_single_press_event <= 1'b1;
                key2_single_release_event <= 1'b1;
            end
        end
    end
endmodule
