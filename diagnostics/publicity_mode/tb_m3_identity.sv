`timescale 1ns/1ps
// All identity bits change, including version wrap and identical page numbers.
module tb_m3_identity;
 reg src=0,dst=0,rst=1,valid=0;reg [7:0] id=0;
 always #5 src=~src;always #19 dst=~dst;
 wire ready,update,enable;wire [7:0] image;
 media_commit_cdc #(.WIDTH(8)) dut(.src_clk(src),.dst_clk(dst),.src_rst(rst),.dst_rst(rst),
 .src_image(id),.src_valid(valid),.src_ready(ready),.media_id(image),.media_update(update),.media_enable(enable));
 integer sent=0,received=0,blocked=0,i;reg [7:0] expected[0:255],held=0;reg was_busy=0;
 always @(posedge src)if(!rst)begin
  if(was_busy && dut.held_image!==held)$fatal(1,"identity changed before acknowledgement");
  was_busy=!ready;held=dut.held_image;
  if(valid && !ready)blocked++;
  if(valid && ready)begin expected[sent]=id;sent++;end
 end
 always @(posedge dst)if(!rst && update)begin
  if(!enable || received>=sent || image!==expected[received])$fatal(1,"identity/page delivery mismatch");
  received++;
 end
 initial begin
  repeat(4)@(negedge src);rst=0;repeat(10)@(negedge src);
  if(enable || update)$fatal(1,"identity enabled without commit");
  for(i=0;i<192;i++)begin
   id={4'(i/12),2'((i/4)%3),2'(i%4)};valid=1;
   do @(posedge src);while(!ready);@(negedge src);
  end
  valid=0;repeat(40)@(negedge src);
  if(received!=192 || sent!=192 || blocked==0)$fatal(1,"identity coverage");
  $display("PASS M3 8-bit identity CDC: 192 commits, version wrap, all applications/pages, backpressure");$finish;
 end
 initial begin #100000;$fatal(1,"identity CDC timeout");end
endmodule
