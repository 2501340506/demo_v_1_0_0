// One EG4 32k block, byte writes and synchronous 16-bit reads.
// FONT rows are stored MSB first; caller swaps the two byte lanes.
module scene_bram32k(
 input wr_clk,wr_en,input [11:0] wr_addr,input [7:0] wr_data,
 input rd_clk,input [10:0] rd_addr,output [15:0] rd_data
);
 EG_PHY_BRAM32K #(.MODE("DP16K"),.DATA_WIDTH_A("16"),.DATA_WIDTH_B("16"),
  .REGMODE_A("NOREG"),.REGMODE_B("NOREG")) ram(
  .clka(wr_clk),.csa(1'b1),.wea(wr_en),.rsta(1'b0),.ocea(1'b1),
  .addra(wr_addr[11:1]),.dia({wr_data,wr_data}),.bytea(wr_addr[0]),.bytewea(1'b1),.doa(),
  .clkb(rd_clk),.csb(1'b1),.web(1'b0),.rstb(1'b0),.oceb(1'b1),
  .addrb(rd_addr),.dib(16'd0),.byteb(1'b0),.byteweb(1'b0),.dob(rd_data));
endmodule
