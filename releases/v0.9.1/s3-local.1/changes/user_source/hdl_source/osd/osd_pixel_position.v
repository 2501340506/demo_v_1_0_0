// Active-area Y and frame events shared by zero-latency OSD layers.
// VS is active low. first_active follows the reader's blanking-time commit.
module osd_pixel_position (
    input clk, rst, vs, de,
    output reg [8:0] line_y,
    output wire frame_start,
    output wire first_active
);
    reg vs_q, de_q, pending;
    assign frame_start = vs_q && !vs;
    assign first_active = vs && de && pending;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            line_y <= 0;
            vs_q <= 1;
            de_q <= 0;
            pending <= 1;
        end else begin
            vs_q <= vs;
            de_q <= de;
            if (!vs) begin
                line_y <= 0;
                pending <= 1;
            end else begin
                if (de_q && !de) line_y <= line_y + 1'b1;
                if (first_active) pending <= 0;
            end
        end
    end
endmodule
