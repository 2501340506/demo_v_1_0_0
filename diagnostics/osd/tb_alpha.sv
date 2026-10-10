`timescale 1ns/1ps
module tb_alpha;
 reg clk=0,rst=1,vs=1,de=0,glyph=0;
 reg [9:0] x=0;
 reg [23:0] rgb=0;
 wire [23:0] out_rgb,bypass;
 wire active;
 always #5 clk=~clk;
 osd_alpha_band dut(.clk(clk),.rst(rst),.vs(vs),.de(de),.pixel_x(x),
  .rgb_in(rgb),.glyph_active(glyph),.rgb_out(out_rgb),.active(active));
 osd_alpha_band #(.ENABLE(0)) off_dut(.clk(clk),.rst(rst),.vs(vs),.de(de),.pixel_x(x),
  .rgb_in(rgb),.glyph_active(glyph),.rgb_out(bypass),.active());
 integer y,col,frame,checks=0,rr,gg,bb;
 reg band;
 reg [23:0] want;
 initial begin
  #21;rst=0;
  for(frame=0;frame<2;frame=frame+1)begin
   @(negedge clk);vs=0;de=0;
   repeat(4)@(negedge clk);vs=1;
   for(y=0;y<480;y=y+1)begin
    for(col=0;col<640;col=col+1)begin
     @(negedge clk);de=1;x=col;glyph=frame;
     case(col%4)
      0:rgb=24'hffff00;
      1:rgb=24'hff4444;
      2:rgb=24'hffffff;
      3:rgb={8'(col),8'(y),8'(col+y)};
     endcase
     band=(col>=4 && col<284 && y>=4 && y<28) ||
          (col>=8 && col<632 && y>=440 && y<464);
     rr=rgb[23:16]/2;gg=rgb[15:8]/2;bb=rgb[7:0]/2;
     want=(band && !glyph)?{8'(rr),8'(gg),8'(bb)}:rgb;
     #1;
     if(out_rgb!==want || active!==(band && !glyph) || bypass!==rgb)
      $fatal(1,"alpha x=%0d y=%0d glyph=%b rgb=%h got=%h want=%h",col,y,glyph,rgb,out_rgb,want);
     checks=checks+1;
    end
    @(negedge clk);de=0;#1;
    if(out_rgb!==rgb || active || bypass!==rgb)$fatal(1,"blanking");
    repeat(2)@(negedge clk);
   end
  end
  $display("PASS alpha band: %0d pixels; actual DE/VS coordinates, both boundaries, RGB color collisions, explicit glyph mask, bypass",checks);
  $finish;
 end
 initial begin #10000000;$fatal(1,"alpha watchdog");end
endmodule
