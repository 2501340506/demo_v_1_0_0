module video_delay
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
reg [20:0] de_d;
reg[DATA_WIDTH - 1:0]  vout_data_r;
// x/hs/vs share one 32-entry BRAM ring. The read slot trails the write slot by
// 20 entries, keeping the original 21-clock delay; outputs stay zero until 20
// clocks after reset, as the reset shift chain did.
reg [11:0] delay_ram [0:31]; /* fehdl force_ram=1, ram_style="bram" */
reg [11:0] delay_q;
reg [4:0] write_slot;
reg [4:0] fill_count;
reg primed;
// TD21 exposed a short register -> BRAM data Hold path. Preserve one
// identity LUT per bus bit, adding no cycles to the video delay contract.
wire [11:0] ram_input;
wire [11:0] timing_input={video_x,hs,vs};
genvar timing_bit;
generate for(timing_bit=0;timing_bit<12;timing_bit=timing_bit+1)begin:g_input_hold
 (* keep="true" *) AL_MAP_LUT1 #(.INIT(2'b10),.EQN("A"))
  u_hold(.o(ram_input[timing_bit]),.a(timing_input[timing_bit]));
end endgenerate

assign read_en = de_d[18];
assign de_r = de_d[20];
assign vout_data = vout_data_r;
assign {video_x_r,hs_r,vs_r} = primed ? delay_q : 12'd0;
always @(posedge video_clk) begin
	delay_ram[write_slot] <= ram_input;
	delay_q <= delay_ram[write_slot - 5'd20];
end
always @(posedge video_clk or posedge rst) begin
	if(rst) begin
		write_slot <= 5'd0;
		fill_count <= 5'd0;
		primed <= 1'b0;
	end else begin
		write_slot <= write_slot + 1'b1;
		if(fill_count != 5'd20) fill_count <= fill_count + 1'b1;
		primed <= fill_count == 5'd20;
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
	if(rst)
		de_d <= 21'b0;
	else
		de_d <= {de_d[19:0],de};
end
endmodule
