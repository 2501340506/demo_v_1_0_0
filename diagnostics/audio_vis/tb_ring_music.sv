`timescale 1ns/1ps
module tb_ring_music;
 reg clk=0,rst=1;always #5 clk=~clk;
 wire hs,vs,de;wire [9:0] x;wire [8:0] y;wire frame;
 video_timing_data timing(.video_clk(clk),.rst(rst),.read_req(),.read_req_ack(1'b1),.hs(hs),.vs(vs),.de(de),.video_x(x));
 osd_pixel_position pos(clk,rst,vs,de,y,frame, );
 reg signed [15:0] samples[0:47999];
 reg [9:0] count=0;integer pointer=0;
 wire valid=count==520;
 always @(posedge clk)if(rst)begin count<=0;pointer<=0;end else if(valid)begin count<=0;pointer<=pointer+1;end else count<=count+1'b1;
 wire [6:0] index;wire [4:0] height;
 audio_ring_levels levels(clk,rst,frame,valid,samples[pointer],samples[pointer],index,height);
 wire ho,vo,dout;wire [9:0] xo;wire [23:0] rgb;
 audio_ring_overlay ring(clk,rst,hs,vs,de,1'b1,x,y,{x[7:0],y[7:0],8'h60},height,index,ho,vo,dout,xo,rgb,2'd2);
 integer file=0,number=0,pixels=0,tablefile;
 initial begin
  $readmemh("music.hex",samples);
  repeat(3)@(negedge clk);rst=0;
 end
 always @(negedge clk)begin
  if(!rst && dout)begin
   if(file==0)begin
    file=$fopen($sformatf("music_%02d.hex",number),"w");
    tablefile=$fopen($sformatf("heights_%02d.txt",number),"w");
    for(integer i=0;i<96;i++)$fdisplay(tablefile,"%0d",(i<levels.filled ? levels.display_heights[i] : 0));
    $fclose(tablefile);
   end
   $fdisplay(file,"%06x",rgb);pixels++;
   if(pixels==640*480)begin
    $fclose(file);file=0;pixels=0;number++;
    if(number==20)begin $display("PASS music: 20 RTL frames, real PCM, %0d accepted samples",pointer);$finish;end
   end
  end
 end
 initial begin #100000000;$fatal(1,"music timeout");end
endmodule
