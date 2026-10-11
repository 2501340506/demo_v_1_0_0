// Two independent request mailboxes sharing one physical sector adapter.
// req && !busy accepts and latches a request. A pulse is sufficient; the
// caller may also hold req through accepted. busy includes queued service,
// so arbitration delay never starts the physical adapter's timeout.
module sd_sector_service #(
 parameter integer CLK_FREQ_HZ=100_000_000, TIMEOUT_MS=500
)(
 input wire clk,rst,
 input wire p_req,input wire [31:0] p_lba,input wire p_cancel,
 output wire p_busy,p_accepted,p_valid,p_done,
 output wire [7:0] p_error,
 input wire a_req,input wire [31:0] a_lba,input wire a_cancel,
 input wire a_urgent,input wire a_enable,
 output wire a_busy,a_accepted,a_valid,a_done,
 output wire [7:0] a_error,
 output wire [7:0] sector_byte,output wire [8:0] sector_index,
 output wire sd_sec_read,output wire [31:0] sd_sec_read_addr,
 input wire [7:0] sd_sec_read_data,
 input wire sd_sec_read_data_valid,sd_sec_read_end,sd_sec_read_failed
);
 reg p_pending,a_pending;
 reg [31:0] p_address,a_address;
 reg active,owner,last_owner,discard;
 reg p_cancel_done,a_cancel_done;
 wire physical_busy,physical_valid,physical_done;
 wire [7:0] physical_error;
 wire choose_audio=a_pending && a_enable && !a_cancel &&
                    (!p_pending || p_cancel || a_urgent || !last_owner);
 wire dispatch=!active && !physical_busy &&
               ((p_pending && !p_cancel) || (a_pending && a_enable && !a_cancel));
 wire cancel_owner=owner ? a_cancel : p_cancel;
 assign p_busy=p_pending || (active && !owner) || p_cancel_done;
 assign a_busy=a_pending || (active && owner) || a_cancel_done;
 assign p_accepted=!rst && p_req && !p_busy && !p_cancel;
 assign a_accepted=!rst && a_req && !a_busy && !a_cancel && a_enable;
 assign p_valid=active && !owner && !discard && !p_cancel && physical_valid;
 assign a_valid=active && owner && !discard && !a_cancel && physical_valid;
 assign p_done=p_cancel_done || (active && !owner && physical_done);
 assign a_done=a_cancel_done || (active && owner && physical_done);
 assign p_error=p_cancel_done ? 8'h13 :
                (active && !owner ? (discard || p_cancel ? 8'h13 : physical_error) : 8'd0);
 assign a_error=a_cancel_done ? 8'h13 :
                (active && owner ? (discard || a_cancel ? 8'h13 : physical_error) : 8'd0);

 sd_sector_adapter #(.CLK_FREQ_HZ(CLK_FREQ_HZ),.TIMEOUT_MS(TIMEOUT_MS)) adapter(
 .clk(clk),.rst(rst),.sector_req(dispatch),.sector_lba(choose_audio?a_address:p_address),
 .sector_busy(physical_busy),.sector_valid(physical_valid),.sector_byte(sector_byte),
 .sector_byte_index(sector_index),.sector_done(physical_done),.sector_error(physical_error),
 .sd_sec_read(sd_sec_read),.sd_sec_read_addr(sd_sec_read_addr),
 .sd_sec_read_data(sd_sec_read_data),.sd_sec_read_data_valid(sd_sec_read_data_valid),
 .sd_sec_read_end(sd_sec_read_end),.sd_sec_read_failed(sd_sec_read_failed));

 always @(posedge clk or posedge rst) begin
  if(rst) begin
   p_pending<=0;a_pending<=0;p_address<=0;a_address<=0;
   active<=0;owner<=0;last_owner<=1;discard<=0;
   p_cancel_done<=0;a_cancel_done<=0;
  end else begin
   p_cancel_done<=0;a_cancel_done<=0;
   if(p_accepted) begin p_pending<=1;p_address<=p_lba;end
   if(a_accepted) begin a_pending<=1;a_address<=a_lba;end
   if(p_pending && p_cancel) begin p_pending<=0;p_cancel_done<=1;end
   if(a_pending && a_cancel) begin a_pending<=0;a_cancel_done<=1;end
   if(dispatch) begin
    active<=1;owner<=choose_audio;last_owner<=choose_audio;discard<=0;
    if(choose_audio)a_pending<=0;else p_pending<=0;
   end
   // Cancellation drains an already issued physical read; it cannot hand
   // remaining bytes to the other client or reset that client's mailbox.
   if(active && cancel_owner)discard<=1;
   if(active && physical_done)begin active<=0;discard<=0;end
  end
 end
endmodule
