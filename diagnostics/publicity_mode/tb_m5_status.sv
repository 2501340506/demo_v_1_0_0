`timescale 1ns/1ps
// Production top status CDC -> final RGB. Source metadata is
// injected here; real controller/SD/audio state changes are covered separately.
module tb_m5_status;
 reg clk=0,pix=0,rst=1;always #5 clk=~clk;always #7 pix=~pix;
 reg hs=1,vs=1,de=0;reg [9:0] x=0;integer y=-1,tick=0;
 reg [1:0] app=0,page=0;reg [2:0] voice=0;reg busy=0,error=0,auto_on=0;
 wire [23:0] source_tuple={8'd0,auto_on,voice,busy,error,8'd0,app};
 top dut(.clk(clk),.rst_n(!rst),.key1(1'b1),.key2(1'b1),.key4(1'b1),
 .sw1(1'b0),.sw2(1'b0),.sd_miso(1'b1),.uart_rx(1'b1));
 initial begin
 force dut.video_clk=pix;force dut.sd_card_clk=clk;
 force dut.rst_video=rst;force dut.rst_sd=rst;force dut.rst_mem=1;force dut.rst_panel=1;
 force dut.hs=hs;force dut.vs=vs;force dut.de=de;force dut.video_x=x;
 force dut.vout_rgba_raw=32'h123456ff;force dut.pixel_descriptor=0;
 force dut.pixel_identity={4'd0,app};force dut.audio_image=page;
 force dut.app_status_cdc.src_state=source_tuple;
 end
 always @(negedge pix)begin
  if(rst)begin tick=0;y=-1;x=0;vs=1;de=0;end
  else begin
   tick=(tick+1)%26400;x=tick%800;y=tick/800-1;
   vs=tick>=800;de=tick>=800 && tick<26400 && x<640;hs=!(x>=656 && x<752);
  end
 end
 function [34:0] bitmap(input [7:0] ch);
 begin case(ch)
 "1":bitmap={5'd4,5'd12,5'd4,5'd4,5'd4,5'd4,5'd14};
 "2":bitmap={5'd14,5'd17,5'd1,5'd2,5'd4,5'd8,5'd31};
 "3":bitmap={5'd30,5'd1,5'd1,5'd14,5'd1,5'd1,5'd30};
 "4":bitmap={5'd2,5'd6,5'd10,5'd18,5'd31,5'd2,5'd2};
 "A":bitmap={5'd14,5'd17,5'd17,5'd31,5'd17,5'd17,5'd17};
 "B":bitmap={5'd30,5'd17,5'd17,5'd30,5'd17,5'd17,5'd30};
 "C":bitmap={5'd15,5'd16,5'd16,5'd16,5'd16,5'd16,5'd15};
 "D":bitmap={5'd30,5'd17,5'd17,5'd17,5'd17,5'd17,5'd30};
 "E":bitmap={5'd31,5'd16,5'd16,5'd30,5'd16,5'd16,5'd31};
 "M":bitmap={5'd17,5'd27,5'd21,5'd21,5'd17,5'd17,5'd17};
 "N":bitmap={5'd17,5'd25,5'd21,5'd19,5'd17,5'd17,5'd17};
 "O":bitmap={5'd14,5'd17,5'd17,5'd17,5'd17,5'd17,5'd14};
 "P":bitmap={5'd30,5'd17,5'd17,5'd30,5'd16,5'd16,5'd16};
 "R":bitmap={5'd30,5'd17,5'd17,5'd30,5'd20,5'd18,5'd17};
 "S":bitmap={5'd15,5'd16,5'd16,5'd14,5'd1,5'd1,5'd30};
 "T":bitmap={5'd31,5'd4,5'd4,5'd4,5'd4,5'd4,5'd4};
 "U":bitmap={5'd17,5'd17,5'd17,5'd17,5'd17,5'd17,5'd14};
 "V":bitmap={5'd17,5'd17,5'd17,5'd17,5'd17,5'd10,5'd4};
 "W":bitmap={5'd17,5'd17,5'd17,5'd21,5'd21,5'd21,5'd10};
 "Y":bitmap={5'd17,5'd17,5'd10,5'd4,5'd4,5'd4,5'd4};
 "/":bitmap={5'd1,5'd2,5'd2,5'd4,5'd8,5'd8,5'd16};
 default:bitmap=0;endcase end endfunction
 function [23:0] golden(input integer px,input integer py);
 reg [8*13-1:0] label_text;reg [7:0] ch;reg [34:0] bits;integer n,row,col;
 begin
 label_text="             ";
 if(busy)label_text=error?"ERROR        ":"BUSY         ";
 else if(error)label_text="NO SET       ";
 else case(app)1:label_text="EDU          ";2:label_text="SCENE        ";default:label_text="COMPAT       ";endcase
 n=(px-400)/16;ch=label_text[(12-n)*8+:8];
 if(n==7)ch="1"+page;if(n==8)ch="/";if(n==9)ch="4";
 if(n==10 && app==1)ch=auto_on?"A":"M";
 if(n==11 && app==1)case(voice)0:ch="N";1:ch="W";2:ch="V";3:ch="D";default:ch="E";endcase
 row=(py-8)/2;col=((px-400)%16)/2;bits=bitmap(ch);
 golden=(row<7 && col<5 && bits[34-row*5-col])?
   ((error || (app==1 && voice==4))?24'hff4040:24'hffffff):24'h102030;
 end endfunction
 reg check=0;reg valid[0:10];reg [23:0] expected[0:10];integer i,count=0,windows=0;
 always @(posedge pix)begin
 for(i=10;i>0;i--)begin valid[i]=valid[i-1];expected[i]=expected[i-1];end
 valid[0]=check && de && x>=400 && x<608 && y>=8 && y<24;
 expected[0]=golden(x,y);#1;
 if(valid[10])begin
  if(dut.final_rgb!==expected[10])$fatal(1,"status final RGB actual=%h expected=%h app=%d voice=%d busy=%b error=%b",dut.final_rgb,expected[10],app,voice,busy,error);
  count++;
 end
 end
 task frames(input integer n);repeat(n)begin @(negedge vs);@(posedge vs);end endtask
 task inspect;begin check=0;frames(2);
 if(dut.app_status_pixel!==source_tuple)$fatal(1,"status tuple CDC");
 check=1;frames(1);check=0;repeat(20)@(negedge pix);windows++;
 end endtask
 integer v,p;
 initial begin
 repeat(10)@(negedge clk);rst=0;
 inspect();app=2;inspect();app=1;
 for(v=0;v<5;v++)begin voice=v;auto_on=v[0];page=v%4;inspect();end
 busy=1;error=0;inspect();error=1;inspect();busy=0;inspect();
 error=0;voice=3;for(p=0;p<4;p++)begin page=p;inspect();end
 if(count!=windows*3328 || windows!=14)$fatal(1,"status coverage %0d/%0d",count,windows);
 $display("PASS M5 production status: %0d exact final RGB pixels across %0d CDC windows; EDU/SCENE/COMPAT, pages, AUTO, N/W/V/D/E, BUSY/ERROR/NO SET",count,windows);$finish;
 end
 initial begin #50000000;$fatal(1,"status watchdog");end
endmodule
