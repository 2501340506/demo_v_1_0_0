// Test-only legacy connector. Production top instantiates loader/reader directly.
module frame_split_test_adapter #(
 parameter BURST_SIZE=64,FRAME_WIDTH=32,FRAME_HEIGHT=32,WRITE_V_FLIP=1
)(
 input rst,mem_clk,Sdr_init_done,Sdr_init_ref_vld,Sdr_busy,
 output App_rd_en,output [20:0] App_rd_addr,input Sdr_rd_en,input [31:0] Sdr_rd_dout,
 input read_clk,read_req,output read_req_ack,read_finish,
 input [20:0] read_addr_0,read_addr_1,read_addr_2,read_addr_3,
 input [1:0] read_addr_index,input [20:0] read_len,input read_en,output [31:0] read_data,
 input display_commit_request,output display_commit_ack,
 output App_wr_en,output [20:0] App_wr_addr,output [31:0] App_wr_din,output [3:0] App_wr_dm,
 input write_clk,write_req,output write_req_ack,write_finish,
 input write_cancel_req,output write_cancel_ack,
 input [20:0] write_addr_0,write_addr_1,write_addr_2,write_addr_3,
 input [1:0] write_addr_index,input [20:0] write_len,input write_en,input [31:0] write_data,
 input source_done,source_error,display_valid,
 output error_toggle,output [2:0] memory_error,reader_error,output underflow
);
 wire rd_busy,wr_busy;
 wire write_fifo_aclr=loader.fifo_clear;
 media_frame_loader #(.BURST_SIZE(BURST_SIZE),.FRAME_WIDTH(FRAME_WIDTH),.FRAME_HEIGHT(FRAME_HEIGHT),.WRITE_V_FLIP(WRITE_V_FLIP)) loader(
 .rst(rst),.mem_clk(mem_clk),.write_clk(write_clk),.write_rst(rst),
 .Sdr_init_done(Sdr_init_done),.Sdr_init_ref_vld(Sdr_init_ref_vld),.Sdr_busy(Sdr_busy),
 .App_rd_busy(rd_busy),.O_wr_busy(wr_busy),.App_wr_en(App_wr_en),.App_wr_addr(App_wr_addr),.App_wr_din(App_wr_din),.App_wr_dm(App_wr_dm),
 .write_req(write_req),.write_req_ack(write_req_ack),.write_finish(write_finish),
 .write_cancel_req(write_cancel_req),.write_cancel_ack(write_cancel_ack),
 .write_addr_0(write_addr_0),.write_addr_1(write_addr_1),.write_addr_2(write_addr_2),.write_addr_3(write_addr_3),
 .write_addr_index(write_addr_index),.write_len(write_len),.write_en(write_en),.write_data(write_data),
 .source_done(source_done),.source_error(source_error),.error_toggle(error_toggle),.memory_error(memory_error));
 media_frame_reader #(.BURST_SIZE(BURST_SIZE)) reader(
 .rst(rst),.mem_clk(mem_clk),.read_clk(read_clk),.read_rst(rst),
 .Sdr_init_done(Sdr_init_done),.Sdr_init_ref_vld(Sdr_init_ref_vld),.Sdr_busy(Sdr_busy),
 .App_wr_busy(wr_busy),.O_rd_busy(rd_busy),.App_rd_en(App_rd_en),.App_rd_addr(App_rd_addr),.Sdr_rd_en(Sdr_rd_en),.Sdr_rd_dout(Sdr_rd_dout),
 .read_req(read_req),.read_req_ack(read_req_ack),.read_finish(read_finish),
 .display_commit_request(display_commit_request),.display_commit_ack(display_commit_ack),
 .read_addr_0(read_addr_0),.read_addr_1(read_addr_1),.read_addr_2(read_addr_2),.read_addr_3(read_addr_3),
 .read_addr_index(read_addr_index),.read_len(read_len),.read_en(read_en),.read_data(read_data),.display_valid(display_valid),
 .underflow(underflow),.reader_error(reader_error));
endmodule
