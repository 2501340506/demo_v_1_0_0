`timescale 1ns/1ps
module tb_scenario_cdc;
 reg pix=0,clk=0;always #17 pix=~pix;always #5 clk=~clk;
 reg rst=1,accept=0,frame=0;wire tick,ftick;
 scene_event_cdc dut(pix,rst,accept,frame,clk,rst,tick,ftick);
 integer emitted=0,received=0,frames=0,got_frames=0;
 always @(posedge pix)if(!rst)begin if(accept)emitted++;if(frame)frames++;end
 always @(posedge clk)if(!rst)begin if(tick)received++;if(ftick)got_frames++;end
 reg [12:0] state=0;reg first=0;wire [1:0] stage;wire [7:0] t;wire en,bf,bs;
 scenario_frame view(.clk(pix),.rst(rst),.first_active(first),.scene_state(state),.stage(stage),.t_now(t),.enable(en),.blink_fast(bf),.blink_slow(bs));
 initial begin
  repeat(4)@(negedge pix);rst=0;
  for(integer i=0;i<8192;i++)begin
   accept=i%5!=0;frame=i%29==0;@(negedge pix);
   state={1'b1,2'(i%4),2'(i%4),8'(i%240)};
   first=1;#1;if(t!=i%240 || stage!=i%4 || !en)$fatal(1,"first pixel mismatch");
   @(negedge pix);first=0;state=0;#1;
   if(t!=i%240 || stage!=i%4 || !en)$fatal(1,"frame state not held");
  end
  accept=0;frame=0;repeat(30)@(negedge clk);
  if(emitted!=received || frames!=got_frames)$fatal(1,"CDC lost samples %d/%d frames %d/%d",emitted,received,frames,got_frames);
  $display("PASS M4 CDC/frame: %0d samples across wraps, %0d frame events, 8192 first-pixel and frame-hold checks",received,frames);$finish;
 end
endmodule
