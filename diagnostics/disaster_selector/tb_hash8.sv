`timescale 1ns/1ps
module tb_hash8;
 parameter VEC_DIR=".";
 hazard_layer_v3 dut(.clk(1'b0),.rst(1'b1),.rgb_in(24'd0),.t_in(8'd0),
  .de(1'b0),.frame_start(1'b0),.t_now(8'd0),.hazard(3'd0),.role(3'd0),
  .enable(1'b0),.thumbnail(1'b0),.frame_cnt(10'd0),.rgb_out());
 reg [7:0] h,want,got;
 integer a,b;
 initial begin
  for(a=0;a<256;a=a+1)for(b=0;b<256;b=b+1)begin
   h=a*73+b*151+(a^b)*37;
   want=h^(h>>4);got=dut.hash8(a[7:0],b[7:0]);
   if(got!==want)$fatal(1,"hash mismatch a=%0d b=%0d got=%h want=%h",a,b,got,want);
  end
  $display("PASS hash8: all 65536 input pairs bit-exact");$finish;
 end
endmodule
