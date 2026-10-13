`timescale 1ns/1ps
module tb_subtitle_fields;
reg [124:0] value;
reg [5:0] position;
reg [1:0] reply_kind;
integer bit_id,len,k,checks=0;
subtitle_uart_controller dut(.clk(1'b0),.rst(1'b0),.rx_data(8'd0),.rx_valid(1'b0),.rx_framing_error(1'b0),
 .cfg_text(),.cfg_length(),.cfg_enable(),.cfg_update_valid(),.reply_valid(),.reply_data(),.reply_last(),.reply_ready(1'b0));
subtitle_uart_controller_reference reference_dut(.clk(1'b0),.rst(1'b0),.rx_data(8'd0),.rx_valid(1'b0),.rx_framing_error(1'b0),
 .cfg_text(),.cfg_length(),.cfg_enable(),.cfg_update_valid(),.reply_valid(),.reply_data(),.reply_last(),.reply_ready(1'b0));
initial begin
 force dut.snapshot=value;force reference_dut.snapshot=value;
 force dut.index=position;force reference_dut.index=position;
 force dut.kind=reply_kind;force reference_dut.kind=reply_kind;
 reply_kind=2;
 // Each source bit at every text length and character position checks the
 // selector boundaries and wrap at character 32 against the old formatter.
 for(bit_id=0;bit_id<122;bit_id=bit_id+1)begin
  if(bit_id==120)value='1;
  else if(bit_id==121)value={$random,$random,$random,$random};
  else value=125'b1<<bit_id;
  for(len=0;len<16;len=len+1)begin
   value[123:120]=len;
   for(k=0;k<64;k=k+1)begin
    position=k;#1;
    if({dut.reply_data,dut.reply_last} !== {reference_dut.reply_data,reference_dut.reply_last})
     $fatal(1,"query mismatch bit=%0d length=%0d index=%0d new=%h old=%h",bit_id,len,k,dut.reply_data,reference_dut.reply_data);
    checks++;
   end
  end
 end
 $display("PASS subtitle query fields: %0d old/new comparisons",checks);$finish;
end
endmodule
