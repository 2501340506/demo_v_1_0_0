`timescale 1ns/1ps
module tb_uart_queue;
reg clk=0,rst=1,hold_queue=1;
always #5 clk=~clk;
reg [15:0] events=0;
reg [31:0] sector=0;
wire tx;
uart_event_logger #(.CLK_FREQ_HZ(100000),.BAUD_RATE(10000),.QUEUE_DEPTH(8)) dut(
 .clk(clk),.rst(rst),.events(events),.image_index(2'd1),.sector(sector),.error_code(3'd2),
 .phase(4'd3),.auto_enabled(1'b1),.sd_debug(64'h123456789abcdef0),.uart_tx(tx),
 .reply_valid(1'b0),.reply_data(8'd0),.reply_last(1'b0),.reply_ready());
reg [153:0] model[$];
reg [153:0] read_expected,snapshot_expected,word_expected;
integer accepted=0,popped=0,loaded=0,full_replace=0,lost=0,old_count;
reg will_pop,will_push,will_load;
// Isolate queue traffic from the slow UART so full replacement and pointer
// wrap are exercised repeatedly. Separate wire-level tests cover serialization.
initial begin
 force dut.boot=hold_queue;
 force dut.active=1'b0;
 force dut.reply_owner=1'b0;
end
always @(posedge clk) if(!rst)begin
 old_count=model.size();
 will_pop=!hold_queue && !dut.loading && old_count!=0;
 will_push=(|dut.pending[57:42]) && (old_count<8 || will_pop);
 will_load=dut.loading;
 if(dut.pop!==will_pop || dut.push!==will_push)$fatal(1,"queue admission mismatch");
 if(will_load)snapshot_expected=read_expected;
 if(will_pop)begin
  if(will_push && dut.wr_ptr==dut.rd_ptr)$fatal(1,"BRAM simultaneous address collision");
  read_expected=model.pop_front();popped++;
  if(old_count==8 && will_push)full_replace++;
 end
 if(will_push)begin
  word_expected={dut.pending,64'h123456789abcdef0};
  model.push_back(word_expected);accepted++;
 end else if(|dut.pending[57:42])lost++;
 #1;
 if(dut.count!==model.size())$fatal(1,"queue count mismatch");
 if(will_pop && dut.queue_read!==read_expected)$fatal(1,"synchronous RAM read mismatch");
 if(will_load)begin
  if(dut.snapshot!==snapshot_expected || dut.remaining!==snapshot_expected[121:106])$fatal(1,"loaded snapshot mismatch");
  loaded++;
 end
end
integer cycle;
initial begin
 repeat(3)@(negedge clk);rst=0;
 for(cycle=0;cycle<1024;cycle++)begin
  @(negedge clk);events=16'h0100;sector=cycle;
  hold_queue=cycle<12 || (cycle%37<5);
 end
 @(negedge clk);events=0;hold_queue=0;
 repeat(24)@(negedge clk);
 if(model.size()!=0 || accepted!=loaded || popped!=loaded || full_replace<100 || lost<100)
  $fatal(1,"insufficient queue stress accepted=%d loaded=%d replacements=%d lost=%d",accepted,loaded,full_replace,lost);
 $display("PASS UART BRAM queue: %0d loaded, %0d full replacements, %0d overflow events, wrapped pointers, no simultaneous address collision",loaded,full_replace,lost);
 $finish;
end
endmodule
