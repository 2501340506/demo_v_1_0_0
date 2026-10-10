`timescale 1ns/1ps
module tb_timestamp;
 reg clk=0,rst=1,vs=1,de=0;
 reg [9:0] x=0;
 reg [23:0] bg=24'h123456;
 wire [23:0] rgb,bypass; wire hit,off_hit;
 always #5 clk=~clk;
 timestamp_osd dut(.clk(clk),.rst(rst),.vs(vs),.de(de),.pixel_x(x),.rgb_in(bg),.rgb_out(rgb),.active(hit));
 timestamp_osd #(.ENABLE(0)) off_dut(.clk(clk),.rst(rst),.vs(vs),.de(de),.pixel_x(x),.rgb_in(bg),.rgb_out(bypass),.active(off_hit));
 integer frames=0,pixels=0,lit=0,n;
 function [15:0] expected_digits(input integer count);
  integer sec,mins;
  begin sec=(count/60)%6000;mins=sec/60;
   expected_digits={(4'(mins/10)),(4'(mins%10)),(4'((sec%60)/10)),(4'(sec%10))};
  end
 endfunction
 wire [15:0] digits={dut.enabled.minute_tens,dut.enabled.minute_ones,dut.enabled.second_tens,dut.enabled.second_ones};
 task check_count;
  begin #1;if(digits!==expected_digits(frames) || dut.enabled.frames!==frames%60)
   $fatal(1,"time at frame %0d got %h want %h",frames,digits,expected_digits(frames));end
 endtask
 task pulse;
  begin
   @(negedge clk);vs=0;de=0;frames=frames+1;
   repeat(3)@(negedge clk);check_count(); // VS low spans multiple cycles, count once
   vs=1;repeat(3)@(negedge clk);check_count();
  end
 endtask
 // Independent seven rows, MSB on left. Same public 5x7 font contract.
 function [34:0] glyph(input integer c);
  case(c)
   0:glyph={5'd14,5'd17,5'd19,5'd21,5'd25,5'd17,5'd14};
   1:glyph={5'd4,5'd12,5'd4,5'd4,5'd4,5'd4,5'd14};
   2:glyph={5'd14,5'd17,5'd1,5'd2,5'd4,5'd8,5'd31};
   3:glyph={5'd30,5'd1,5'd1,5'd14,5'd1,5'd1,5'd30};
   4:glyph={5'd2,5'd6,5'd10,5'd18,5'd31,5'd2,5'd2};
   5:glyph={5'd31,5'd16,5'd16,5'd30,5'd1,5'd1,5'd30};
   6:glyph={5'd14,5'd16,5'd16,5'd30,5'd17,5'd17,5'd14};
   7:glyph={5'd31,5'd1,5'd2,5'd4,5'd8,5'd8,5'd8};
   8:glyph={5'd14,5'd17,5'd17,5'd14,5'd17,5'd17,5'd14};
   9:glyph={5'd14,5'd17,5'd17,5'd15,5'd1,5'd1,5'd14};
   default:glyph={5'd0,5'd4,5'd4,5'd0,5'd4,5'd4,5'd0};
  endcase
 endfunction
 task draw;
  integer y,col,cellno,digit,gx,gy;reg want;reg [34:0] bits;
  reg [15:0] snapshot;
  begin
   snapshot=expected_digits(frames);
   for(y=0;y<480;y=y+1)begin
    for(col=0;col<640;col=col+1)begin
     @(negedge clk);de=1;x=col;bg={8'(col),8'(y),8'(col+y)};
     want=0;gx=((col-500)%16)/2;gy=(y-8)/2;cellno=(col-500)/16;
     case(cellno)0:digit=snapshot[15:12];1:digit=snapshot[11:8];2:digit=10;3:digit=snapshot[7:4];default:digit=snapshot[3:0];endcase
     bits=glyph(digit);
     if(col>=500 && col<580 && y>=8 && y<24 && gx<5 && gy<7)want=bits[34-gy*5-gx];
     #1;if(hit!==want || rgb!==(want?24'hffffff:bg) || bypass!==bg || off_hit)
      $fatal(1,"pixel x=%0d y=%0d digits=%h",col,y,snapshot);
     if(digits!==snapshot)$fatal(1,"time changed in active frame");
     pixels=pixels+1;if(want)lit=lit+1;
    end
    @(negedge clk);de=0;#1;if(hit || rgb!==bg || bypass!==bg)$fatal(1,"blanking");
    @(negedge clk);
   end
  end
 endtask
 initial begin
  #21;rst=0;check_count();draw();
  // Every real edge over the full 100-minute counter cycle; no forced registers.
  for(n=1;n<=360000;n=n+1)begin
   pulse();
   if(n==59 || n==60 || n==35940 || n==36000 || n==45240 || n==215940 || n==216000 || n==284160 || n==359940 || n==360000)draw();
  end
  pulse();@(negedge clk);rst=1;frames=0;#1;check_count();
  @(negedge clk);rst=0;pulse();check_count();
  $display("PASS timestamp: full 360000-frame cycle, 60-frame tick, all carries/wrap, reset, %0d pixels, %0d foreground, stable active frame and disabled bypass",pixels,lit);
  $finish;
 end
 initial begin #100000000;$fatal(1,"timestamp watchdog");end
endmodule
