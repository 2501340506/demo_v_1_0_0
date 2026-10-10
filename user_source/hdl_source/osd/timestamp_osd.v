// Elapsed video time: 60 frame starts per second, modulo 100 minutes.
// RGB stays combinational; ENABLE=0 elaborates only a wire bypass.
module timestamp_osd #(
    parameter integer ENABLE = 1,
    parameter integer OSD_X = 500,
    parameter integer OSD_Y = 8
)(
    input clk, rst, vs, de,
    input [9:0] pixel_x,
    input [23:0] rgb_in,
    output wire [23:0] rgb_out,
    output wire active
);
generate if (ENABLE) begin : enabled
    wire [8:0] line_y;
    wire frame_start;
    osd_pixel_position position(.clk(clk),.rst(rst),.vs(vs),.de(de),
        .line_y(line_y),.frame_start(frame_start),.first_active());
    reg [5:0] frames;
    reg [3:0] minute_tens, minute_ones, second_tens, second_ones;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            frames<=0; minute_tens<=0; minute_ones<=0;
            second_tens<=0; second_ones<=0;
        end else if(frame_start) begin
            if(frames==59) begin
                frames<=0;
                if(second_ones==9) begin
                    second_ones<=0;
                    if(second_tens==5) begin
                        second_tens<=0;
                        if(minute_ones==9) begin
                            minute_ones<=0;
                            minute_tens<=minute_tens==9 ? 4'd0 : minute_tens+1'b1;
                        end else minute_ones<=minute_ones+1'b1;
                    end else second_tens<=second_tens+1'b1;
                end else second_ones<=second_ones+1'b1;
            end else frames<=frames+1'b1;
        end
    end
    wire [9:0] dx=pixel_x-OSD_X;
    wire [8:0] dy=line_y-OSD_Y;
    reg [7:0] character;
    always @* begin
        case(dx[9:4])
            0: character=8'd48+{4'd0,minute_tens};
            1: character=8'd48+{4'd0,minute_ones};
            2: character=":";
            3: character=8'd48+{4'd0,second_tens};
            4: character=8'd48+{4'd0,second_ones};
            default: character=" ";
        endcase
    end
    wire [4:0] glyph;
    osd_font_5x7 font(.character(character),.row(dy[3:1]),.pixels(glyph));
    wire in_region=de && pixel_x>=OSD_X && pixel_x<OSD_X+80 &&
                   line_y>=OSD_Y && line_y<OSD_Y+16;
    assign active=in_region && dx[3:1]<5 && dy[3:1]<7 && glyph[3'd4-dx[3:1]];
    assign rgb_out=active ? 24'hffffff : rgb_in;
end else begin : disabled
    assign active=1'b0;
    assign rgb_out=rgb_in;
end endgenerate
endmodule
