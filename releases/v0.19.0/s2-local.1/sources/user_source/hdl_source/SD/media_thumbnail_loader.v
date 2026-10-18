`timescale 1ns/1ps
// Both representations belong to one cache entry. Never publish either until
// both writers have drained. The grant stays fixed throughout an issued burst.
module media_thumbnail_loader #(
 parameter MENU_ENABLE=0,
 parameter ADDR_BITS=21, BURST_SIZE=64,
 parameter WRITE_V_FLIP=1, FRAME_WIDTH=640, FRAME_HEIGHT=480
)(
 input rst, mem_clk, write_clk, write_rst,
 input Sdr_init_done, Sdr_init_ref_vld, Sdr_busy, App_rd_busy,
 output O_wr_busy, App_wr_en, output [ADDR_BITS-1:0] App_wr_addr,
 output [31:0] App_wr_din, output [3:0] App_wr_dm,
 input menu_mode,
 input write_req, output write_req_ack,
 input write_cancel_req, output write_cancel_ack,
 input [ADDR_BITS-1:0] write_addr_0,write_addr_1,write_addr_2,write_addr_3,
 input [1:0] write_addr_index,input [ADDR_BITS-1:0] write_len,
 input write_en,input [31:0] write_data,output write_ready,
 input source_done,source_error,output reg write_finish,
 output reg error_toggle,output reg [2:0] memory_error
);
 wire [1:0] busy,en,ack,cancel_ack,ready,finish,fault;
 wire [ADDR_BITS-1:0] addr[0:1];
 wire [31:0] data[0:1];
 wire [2:0] code[0:1];
 reg grant;
 reg [1:0] finished,fault_seen;
 reg [9:0] x;
 reg [8:0] row;
 wire menu=MENU_ENABLE && menu_mode;
 reg [1:0] menu_mem_sync;
 always @(posedge mem_clk or posedge rst)begin
  if(rst)menu_mem_sync<=0;
  else menu_mem_sync<={menu_mem_sync[0],menu};
 end
 wire menu_mem=menu_mem_sync[1];
 reg [2:0] xp,yp;
 always @(posedge write_clk or posedge write_rst)begin
  if(write_rst)begin xp<=0;yp<=0;end
  else if(write_req || write_cancel_req)begin xp<=0;yp<=0;end
  else if(write_en)begin
   xp<=xp==4?0:xp+1'b1;
   if(x==FRAME_WIDTH-1)begin xp<=0;yp<=yp==4?0:yp+1'b1;end
  end
 end
 wire take_menu=(xp==0 || xp==2) && (WRITE_V_FLIP?(yp==2 || yp==4):(yp==0 || yp==2));
 wire take_thumb=!x[0] && (WRITE_V_FLIP ? row[0] : !row[0]);
 assign write_ready=ready[0] && (menu || !take_thumb || ready[1]);
 assign write_req_ack=ack[0] && (menu || ack[1]);
 assign write_cancel_ack=cancel_ack[0] && (menu || cancel_ack[1]);
 assign O_wr_busy=|busy;
 assign App_wr_en=en[grant];
 assign App_wr_addr=addr[grant];
 assign App_wr_din=data[grant];
 assign App_wr_dm=0;
 always @(posedge write_clk or posedge write_rst) begin
  if(write_rst) begin x<=0;row<=0;end
  else if(write_req || write_cancel_req)begin x<=0;row<=0;end
  else if(write_en)begin
   if(x==FRAME_WIDTH-1)begin x<=0;row<=row+1'b1;end
   else x<=x+1'b1;
  end
 end
 always @(posedge mem_clk or posedge rst) begin
  if(rst)begin grant<=0;finished<=0;fault_seen<=0;write_finish<=0;error_toggle<=0;memory_error<=0;end
  else begin
   // An idle writer gets one opportunity every other clock. A started burst
   // holds busy until all registered requests have left that writer.
   if(!( |busy) && !(|en) && !Sdr_busy)grant<=~grant;
   write_finish<=0;
   if((ack[0] && (menu_mem || ack[1])) || write_cancel_req)finished<=0;
   else begin
    finished<=finished|finish|(menu_mem?2'b10:2'b00);
    if(&(finished|finish|(menu_mem?2'b10:2'b00)) && !(&finished))write_finish<=1;
   end
   fault_seen<=fault;
   if(fault!=fault_seen)begin
    memory_error<=fault[0]!=fault_seen[0]?code[0]:code[1];
    error_toggle<=~error_toggle;
   end
  end
 end
 media_frame_loader #(.MENU_ENABLE(MENU_ENABLE),.BURST_GATE_ENABLE(1),.ADDR_BITS(ADDR_BITS),.BURST_SIZE(BURST_SIZE),
  .WRITE_V_FLIP(WRITE_V_FLIP),.FRAME_WIDTH(FRAME_WIDTH),.FRAME_HEIGHT(FRAME_HEIGHT)) full_writer(
  .rst(rst),.mem_clk(mem_clk),.write_clk(write_clk),.write_rst(write_rst),
  .Sdr_init_done(Sdr_init_done),.Sdr_init_ref_vld(Sdr_init_ref_vld),.Sdr_busy(Sdr_busy),
  .App_rd_busy(App_rd_busy),.burst_permit(!grant),.O_wr_busy(busy[0]),
  .App_wr_en(en[0]),.App_wr_addr(addr[0]),.App_wr_din(data[0]),.App_wr_dm(),
  .menu_mode(menu),.write_req(write_req),.write_req_ack(ack[0]),.write_cancel_req(write_cancel_req),.write_cancel_ack(cancel_ack[0]),
  .write_addr_0(write_addr_0),.write_addr_1(write_addr_1),.write_addr_2(write_addr_2),.write_addr_3(write_addr_3),
  .write_addr_index(write_addr_index),.write_len(write_len),.write_en(write_en && (!menu || take_menu)),.write_data(write_data),.write_ready(ready[0]),
  .source_done(source_done),.source_error(source_error),.write_finish(finish[0]),.error_toggle(fault[0]),.memory_error(code[0]));
 media_frame_loader #(.BURST_GATE_ENABLE(1),.ADDR_BITS(ADDR_BITS),.BURST_SIZE(BURST_SIZE),
  .WRITE_V_FLIP(WRITE_V_FLIP),.FRAME_WIDTH(FRAME_WIDTH/2),.FRAME_HEIGHT(FRAME_HEIGHT/2)) thumb_writer(
  .rst(rst),.mem_clk(mem_clk),.write_clk(write_clk),.write_rst(write_rst),
  .Sdr_init_done(Sdr_init_done),.Sdr_init_ref_vld(Sdr_init_ref_vld),.Sdr_busy(Sdr_busy),
  .App_rd_busy(App_rd_busy),.burst_permit(grant),.O_wr_busy(busy[1]),
  .App_wr_en(en[1]),.App_wr_addr(addr[1]),.App_wr_din(data[1]),.App_wr_dm(),
  .menu_mode(1'b0),.write_req(write_req && !menu),.write_req_ack(ack[1]),.write_cancel_req(write_cancel_req && !menu),.write_cancel_ack(cancel_ack[1]),
  .write_addr_0(21'd1228800),.write_addr_1(21'd1305600),.write_addr_2(21'd1382400),.write_addr_3(21'd1459200),
  .write_addr_index(write_addr_index),.write_len(write_len >> 2),.write_en(write_en && !menu && take_thumb),.write_data(write_data),.write_ready(ready[1]),
  .source_done(source_done && !menu),.source_error(source_error && !menu),.write_finish(finish[1]),.error_toggle(fault[1]),.memory_error(code[1]));
endmodule
