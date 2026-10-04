`timescale 1ns/1ps
module tb_media_commit_cdc;
 reg src=0,dst=0,rst=1,valid=0;
 reg [1:0] id=0;
 always #5 src=~src;
 always #19 dst=~dst;
 wire ready,update,enable;wire [1:0] image;
 media_commit_cdc dut(.src_clk(src),.dst_clk(dst),.src_rst(rst),.dst_rst(rst),
 .src_image(id),.src_valid(valid),.src_ready(ready),
 .media_id(image),.media_update(update),.media_enable(enable));
 integer sent=0,received=0,blocked=0,i;
 reg [1:0] expected[0:31];
 reg [1:0] held=0;
 reg was_busy=0;
 always @(posedge src) if(!rst) begin
  if(was_busy && dut.held_image!==held) $fatal(1,"held CDC bus changed before acknowledgement");
  was_busy=!ready;held=dut.held_image;
  if(valid && !ready) blocked=blocked+1;
  if(valid && ready) begin expected[sent]=id;sent=sent+1;end
 end
 always @(posedge dst) if(!rst && update) begin
  if(!enable || received>=sent || image!==expected[received]) $fatal(1,"CDC delivery mismatch");
  received=received+1;
 end
 initial begin
  repeat(4) @(negedge src);rst=0;
  repeat(10) @(negedge src);
  if(enable || update) $fatal(1,"enabled without first commit");
  for(i=0;i<24;i=i+1) begin
   id=(i/2)%4;valid=1;
   do @(posedge src);while(!ready);
   @(negedge src);
  end
  valid=0;repeat(40) @(negedge src);
  if(received!=24 || sent!=24 || blocked==0) $fatal(1,"CDC missing events/backpressure");
  $display("PASS S8 held-data CDC: 24 back-to-back events, repeated IDs and all four images");
  $finish;
 end
 initial begin #20000;$fatal(1,"timeout");end
endmodule
