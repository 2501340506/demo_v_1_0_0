`timescale 1ns/1ps
module tb_hazard_layer;
 reg clk=0;always #5 clk=~clk;
 reg rst=1;reg [23:0] rgb=0;reg [7:0] arrival=255,now_t=0;
 reg [1:0] stage=0;reg enable=1,thumbnail=0,fast=0,slow=0;
 reg [47:0] side=0;wire [47:0] out_side;wire [23:0] out_rgb;
 hazard_layer #(.SIDE_WIDTH(48)) dut(.clk(clk),.rst(rst),.rgb_in(rgb),.arrival(arrival),
  .t_now(now_t),.stage(stage),.enable(enable),.thumbnail(thumbnail),.blink_fast(fast),.blink_slow(slow),
  .side_in(side),.side_out(out_side),.rgb_out(out_rgb));
 parameter VECTOR_DIR=".";
 reg [7:0] pixels[0:1228799],expected[0:921599];
 reg [23:0] previous=0;reg [47:0] previous_side=0;
 integer checks=0,files=0,fd,n,t,phase,i,v;string name;
 function [23:0] reference(input [23:0] p,input integer a,s,tm,bf,bs,en,thumb);
  reg [23:0] color,fc,result;integer c,k,value;
  begin
   case(s)
    1:begin color=24'h603010;fc=24'hffe000;end
    2:begin color=24'h0060e0;fc=24'hffffff;end
    3:begin color=24'h00c040;fc=24'h00ff00;end
    default:begin color=0;fc=0;end
   endcase
   result=p;
   if(en && !thumb)begin
    if(s!=0 && a<240 && a<=tm)begin
     if(tm-a<6 && bf)result=fc;
     else begin
      k=(s==2 && tm-a>=6)?1:3;
      for(c=0;c<3;c++)begin value=(p[c*8+:8]+k*color[c*8+:8])/(k+1);result[c*8+:8]=8'(value);end
     end
    end else if(a==250 && bs)result=24'h00ff00;
   end
   reference=result;
  end
 endfunction
 task pixel(input [23:0] p,input [7:0] a,input [23:0] exp);
  begin
   @(negedge clk);rgb=p;arrival=a;side={16'(checks),32'(checks*37)};
   @(posedge clk);#1;
   if(out_rgb!==previous || out_side!==previous_side)
    $fatal(1,"hazard pixel/side delay check=%0d got=%h want=%h side=%h want=%h",checks,out_rgb,previous,out_side,previous_side);
   previous=exp;previous_side=side;checks++;
  end
 endtask
 initial begin
  repeat(3)@(negedge clk);rst=0;
  for(integer s=0;s<4;s++)begin
   name=$sformatf("%s/PIC%0d.rgba",VECTOR_DIR,s+1);fd=$fopen(name,"rb");if(!fd)$fatal(1,"open %s",name);
   n=$fread(pixels,fd);$fclose(fd);if(n!=1228800)$fatal(1,"short RGBA");
   for(integer ti=0;ti<3;ti++)begin
    t=ti==0?0:ti==1?120:239;
    for(phase=0;phase<2;phase++)begin
     name=$sformatf("%0s/PIC%0d_t%0s_%0s.rgb",VECTOR_DIR,s+1,ti==0?"000":ti==1?"120":"239",phase==0?"bright":"dark");
     fd=$fopen(name,"rb");if(!fd)$fatal(1,"open %s",name);
     n=$fread(expected,fd);$fclose(fd);if(n!=921600)$fatal(1,"short expected");
     stage=2'(s);now_t=8'(t);fast=phase==0;slow=fast;
     for(i=0;i<307200;i++)pixel({pixels[4*i],pixels[4*i+1],pixels[4*i+2]},pixels[4*i+3],{expected[3*i],expected[3*i+1],expected[3*i+2]});
     files++;$display("PASS saved M2 expected stage=%0d t=%0d phase=%0d",s,t,phase);
    end
   end
  end
  for(integer s=0;s<4;s++)for(integer ti=0;ti<5;ti++)for(integer ph=0;ph<4;ph++)begin
   stage=2'(s);now_t=ti==0?0:ti==1?5:ti==2?6:ti==3?120:239;fast=ph[0];slow=ph[1];
   for(v=0;v<256;v++)pixel({8'(v),8'(v*7+1),8'(v*13+3)},8'(v),
    reference({8'(v),8'(v*7+1),8'(v*13+3)},v,s,now_t,fast,slow,1,0));
  end
  for(integer bypass=0;bypass<2;bypass++)begin
   enable=bypass!=0;thumbnail=bypass!=0;
   for(v=0;v<256;v++)pixel({8'(v),8'(v+1),8'(v+2)},8'(v),{8'(v),8'(v+1),8'(v+2)});
  end
  pixel(0,255,0);pixel(0,255,0);
  @(negedge clk);rst=1;#1;if(out_rgb!==0 || out_side!==0)$fatal(1,"async reset");
  repeat(2)@(negedge clk);previous=0;previous_side=0;side=0;rgb=0;arrival=255;rst=0;pixel(24'habcdef,250,24'habcdef);pixel(0,255,0);
  $display("PASS hazard layer: saved_frames=%0d pixel_side_checks=%0d all_T boundaries phases bypass reset",files,checks);$finish;
 end
 initial begin #1000000000;$fatal(1,"hazard watchdog");end
endmodule
