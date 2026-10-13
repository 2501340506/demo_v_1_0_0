module video_delay_ref
#(
	parameter DATA_WIDTH = 24                       // Video data one clock data width
)
(
	input                       video_clk,          // Video pixel clock
	input                       rst,
	output                      read_en,            // Read data enable
	input[DATA_WIDTH - 1:0]     read_data,          // Read data
	input                      hs,                 // horizontal synchronization
	input                      vs,                 // vertical synchronization
	input                      de,                 // video valid
	input [9:0]                video_x,

	output                      hs_r,                 // horizontal synchronization
	output                      vs_r,                 // vertical synchronization
	output                      de_r,                 // video valid
	output[DATA_WIDTH - 1:0]    vout_data,          // video data
	output [9:0]               video_x_r

);
reg [20:0] hs_d;
reg [20:0] vs_d;
reg [20:0] de_d;
reg [9:0] x_d [0:20];
integer i;
reg[DATA_WIDTH - 1:0]  vout_data_r;

assign read_en = de_d[18];
assign hs_r = hs_d[20];
assign vs_r = vs_d[20];
assign de_r = de_d[20];
assign vout_data = vout_data_r;
assign video_x_r = x_d[20];
always @(posedge video_clk or posedge rst) begin
    if (rst) begin
        for (i = 0; i < 21; i = i + 1)
            x_d[i] <= 10'd0;
    end else begin
        x_d[0] <= video_x;
        for (i = 1; i < 21; i = i + 1)
            x_d[i] <= x_d[i-1];
    end
end
always@(posedge video_clk or posedge rst)
begin
	if(rst == 1'b1)
		vout_data_r <= {DATA_WIDTH{1'b0}};
	else if(de_d[19])
		vout_data_r <= read_data;
	else
		vout_data_r <= {DATA_WIDTH{1'b0}};
end
always @(posedge video_clk or posedge rst)begin
	if(rst)begin
    	hs_d <= 20'b0;
        vs_d <= 20'b0;
        de_d <= 20'b0;
    end
	else begin
    	
    	hs_d <= {hs_d[19:0],hs};
        vs_d <= {vs_d[19:0],vs};
        de_d <= {de_d[19:0],de};
    end
end
endmodule
