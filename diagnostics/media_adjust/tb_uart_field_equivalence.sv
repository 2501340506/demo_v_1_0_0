`timescale 1ns/1ps
module tb_uart_field_equivalence;
reg [153:0] value;
reg [6:0] index;
reg [15:0] mask;
reg boot_mode;
integer sample, event_id, phase_id, char_id, checks=0;
uart_event_logger dut(.clk(1'b0),.rst(1'b0),.events(16'd0),
 .image_index(2'd0),.sector(32'd0),.error_code(3'd0),.phase(4'd0),
 .auto_enabled(1'b0),.sd_debug(64'd0),.uart_tx(),.reply_valid(1'b0),
 .reply_data(8'd0),.reply_last(1'b0),.reply_ready());
uart_event_logger_reference reference_dut(.clk(1'b0),.rst(1'b0),.events(16'd0),
 .image_index(2'd0),.sector(32'd0),.error_code(3'd0),.phase(4'd0),
 .auto_enabled(1'b0),.sd_debug(64'd0),.uart_tx(),.reply_valid(1'b0),
 .reply_data(8'd0),.reply_last(1'b0),.reply_ready());
task compare;
 begin
  #1;
  if ({dut.tx_hex,dut.tx_data} !== {reference_dut.tx_hex,reference_dut.tx_data})
   $fatal(1,"formatter mismatch boot=%b index=%d mask=%h snapshot=%h new=%h old=%h",
    boot_mode,index,mask,value,{dut.tx_hex,dut.tx_data},{reference_dut.tx_hex,reference_dut.tx_data});
  checks=checks+1;
 end
endtask
initial begin
 force dut.snapshot=value;force reference_dut.snapshot=value;
 force dut.char_index=index;force reference_dut.char_index=index;
 force dut.remaining=mask;force reference_dut.remaining=mask;
 force dut.boot=boot_mode;force reference_dut.boot=boot_mode;
 boot_mode=0;mask=1;
 // Every source bit through every selector position, including zero and ones.
 for(sample=0;sample<156;sample=sample+1)begin
  if(sample==154)value=0;
  else if(sample==155)value='1;
  else value=154'b1<<sample;
  for(char_id=0;char_id<128;char_id=char_id+1)begin index=char_id;compare();end
 end
 // Event name/phase interactions plus independent random field contents.
 for(event_id=0;event_id<16;event_id=event_id+1)
  for(phase_id=0;phase_id<16;phase_id=phase_id+1)begin
   value={$random,$random,$random,$random,$random};value[68:65]=phase_id;
   mask=16'b1<<event_id;
   for(char_id=0;char_id<128;char_id=char_id+1)begin index=char_id;compare();end
  end
 boot_mode=1;
 for(char_id=0;char_id<128;char_id=char_id+1)begin index=char_id;compare();end
 $display("PASS UART formatter equivalence: %0d comparisons; walking bits, all character indices, events, phases, random snapshots and banner",checks);
 $finish;
end
endmodule
