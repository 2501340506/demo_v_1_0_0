 // The frame model stores every REAL scaler output (all 307200 pixels/bank).
 integer mx,my,mt,mb;
 always @(negedge pix)begin
  #1;mx=vx;my=top_dut.ring_y;
  if(memory_descriptor[17])begin
   mt=(my>=240?2:0)+(mx>=320?1:0);mb=(memory_descriptor>>(2*mt))&3;
   memory_pixel=memory_descriptor[8+mt]?frame_memory[mb*307200+(my%240)*1280+(mx%320)*2]:32'h000000ff;
  end else memory_pixel=visible?frame_memory[visible_bank*307200+my*640+mx]:32'h000000ff;
 end
 // A compact reference bitmap, independent of the production character ROM.
 function [34:0] bitmap(input [7:0] ch);
 begin case(ch)
 "0":bitmap={5'd14,5'd17,5'd19,5'd21,5'd25,5'd17,5'd14};
 "1":bitmap={5'd4,5'd12,5'd4,5'd4,5'd4,5'd4,5'd14};
 "2":bitmap={5'd14,5'd17,5'd1,5'd2,5'd4,5'd8,5'd31};
 "3":bitmap={5'd30,5'd1,5'd1,5'd14,5'd1,5'd1,5'd30};
 "4":bitmap={5'd2,5'd6,5'd10,5'd18,5'd31,5'd2,5'd2};
 "5":bitmap={5'd31,5'd16,5'd16,5'd30,5'd1,5'd1,5'd30};
 "6":bitmap={5'd14,5'd16,5'd16,5'd30,5'd17,5'd17,5'd14};
 "7":bitmap={5'd31,5'd1,5'd2,5'd4,5'd8,5'd8,5'd8};
 "8":bitmap={5'd14,5'd17,5'd17,5'd14,5'd17,5'd17,5'd14};
 "9":bitmap={5'd14,5'd17,5'd17,5'd15,5'd1,5'd1,5'd14};
 "B":bitmap={5'd30,5'd17,5'd17,5'd30,5'd17,5'd17,5'd30};
 "C":bitmap={5'd15,5'd16,5'd16,5'd16,5'd16,5'd16,5'd15};
 "V":bitmap={5'd17,5'd17,5'd17,5'd17,5'd17,5'd10,5'd4};
 "S":bitmap={5'd15,5'd16,5'd16,5'd14,5'd1,5'd1,5'd30};
 "P":bitmap={5'd30,5'd17,5'd17,5'd30,5'd16,5'd16,5'd16};
 "E":bitmap={5'd31,5'd16,5'd16,5'd30,5'd16,5'd16,5'd31};
 "D":bitmap={5'd30,5'd17,5'd17,5'd17,5'd17,5'd17,5'd30};
 "X":bitmap={5'd17,5'd17,5'd10,5'd4,5'd10,5'd17,5'd17};
 ":":bitmap={5'd0,5'd4,5'd4,5'd0,5'd4,5'd4,5'd0};
 "%":bitmap={5'd25,5'd26,5'd4,5'd4,5'd8,5'd22,5'd6};
 default:bitmap=0;endcase end endfunction
 function integer adjusted(input integer v,input integer b,input integer c);
 integer t;begin t=v*b/128;if(t>255)t=255;t=(((t-128)*c)>>>7)+128;
 adjusted=t<0?0:t>255?255:t;end endfunction
 function [23:0] golden(input [31:0] raw,input integer x,input integer y);
 integer j,v,a,age,col,fc,st,t,idx,item,n,row,bitx,tile,lx,ly;reg speed,visible_osd,border,validpix;
 reg [23:0] rgb;reg [7:0] ch;reg [34:0] bits;
 begin
 rgb=raw[31:8];a=raw[7:0];st=top_dut.scene_stage;t=top_dut.scene_time;age=t-a;
 case(st) 1:begin col='h603010;fc='hffe000;end 2:begin col='h0060e0;fc='hffffff;end
 3:begin col='h00c040;fc='h00ff00;end default:begin col=0;fc=0;end endcase
 if(top_dut.scene_enable && top_dut.pixel_identity[1:0]==2 && !memory_descriptor[17])begin
  if(a==250 && top_dut.scene_slow)rgb=24'h00ff00;
  else if(st!=0 && a<240 && a<=t)begin
   for(j=0;j<3;j++)begin
    if(age<6 && top_dut.scene_fast)v=(fc>>(j*8))&255;
    else if(st==2 && age>=6)v=(((rgb>>(j*8))&255)+((col>>(j*8))&255))/2;
    else v=(((rgb>>(j*8))&255)+3*((col>>(j*8))&255))/4;
    rgb[j*8+:8]=v;
   end
  end
 end
 for(j=0;j<3;j++)rgb[j*8+:8]=adjusted(rgb[j*8+:8],top_dut.brightness_frame,top_dut.contrast_frame);
 if(memory_descriptor[17])begin
  tile=(y>=240?2:0)+(x>=320?1:0);lx=x%320;ly=y%240;
  border=tile<memory_descriptor[14:12] && tile==memory_descriptor[16:15] && (lx<2 || lx>=318 || ly<2 || ly>=238);
  if(border)rgb=24'hffff00;else if(!memory_descriptor[8+tile])rgb=0;
 end
 speed=top_dut.scene_enable && top_dut.adjust_mode==0;
 visible_osd=top_dut.adjust_mode==1 || top_dut.adjust_mode==2 || speed;
 ch=" ";item=3;idx=(x-8)/16;
 if(visible_osd && x>=4 && x<300 && y>=28 && y<52)begin
  rgb={1'b0,rgb[23:17],1'b0,rgb[15:9],1'b0,rgb[7:1]};
  if(x>=8 && x<296 && y>=32 && y<48)begin
   if(speed)begin
    item=top_dut.adjust_selected;
    case(idx)0:ch="S";1:ch="P";2:ch="E";3:ch="E";4:ch="D";5:ch=":";
     7:ch=top_dut.scene_meta_pixel[15:14]==0?"1":top_dut.scene_meta_pixel[15:14]==1?"2":"4";8:ch="X";endcase
   end else begin
    if(idx<5)begin item=0;n=top_dut.brightness_frame;end
    else if(idx>=6 && idx<=10)begin item=1;n=top_dut.contrast_frame;end
    else if(idx>=12 && idx<=17)begin item=2;n=top_dut.volume_frame*10;end
    case(idx)
     0:ch="B";6:ch="C";12:ch="V";1,7,13:ch=":";
     2,8,14:ch="0"+n/100;3,9,15:ch="0"+(n/10)%10;4,10,16:ch="0"+n%10;17:ch="%";
    endcase
   end
   row=(y-32)/2;bitx=((x-8)%16)/2;bits=bitmap(ch);
   if(row<7 && bitx<5 && bits[34-row*5-bitx])rgb=item==top_dut.adjust_selected?24'hffff00:24'hffffff;
  end
 end
 golden=rgb;
 end endfunction
 localparam FINAL_DELAY=18; // ten-clock disaster layer + eight downstream clocks
 reg checking=0;reg [23:0] expected[0:FINAL_DELAY];reg valid_check[0:FINAL_DELAY];reg [12:0] timings[0:FINAL_DELAY];
 integer ex[0:FINAL_DELAY],ey[0:FINAL_DELAY],q;integer checked=0,glyph_checked=0,content_checked=0,preview_checked=0,tmds_checked=0;
 reg [23:0] core_expected;reg core_video;
 function [7:0] untmds(input [9:0] sym);
 reg [7:0] z,v;integer j;begin z=sym[9]?~sym[7:0]:sym[7:0];v[0]=z[0];
 for(j=1;j<8;j++)v[j]=sym[8]?(z[j]^z[j-1]):~(z[j]^z[j-1]);untmds=v;end endfunction
 `define H top_dut.u_media_hdmi_audio_bridge.u_symbol_core
 always @(posedge pix)if(!rst)begin
  for(q=FINAL_DELAY;q>0;q--)begin expected[q]=expected[q-1];valid_check[q]=valid_check[q-1];timings[q]=timings[q-1];ex[q]=ex[q-1];ey[q]=ey[q-1];end
  expected[0]=golden(memory_pixel,vx,top_dut.ring_y);
  valid_check[0]=checking && de && vx>=8 && vx<632 &&
   ((top_dut.ring_y>=28 && top_dut.ring_y<52) || (top_dut.ring_y>=60 && top_dut.ring_y<64));
  timings[0]={hs,vs,de,vx};ex[0]=vx;ey[0]=top_dut.ring_y;
  core_video=(`H.mode==1);core_expected=`H.video_rgb;
  #1;
  if(core_video)begin
   if({untmds(`H.channel2_symbol),untmds(`H.channel1_symbol),untmds(`H.channel0_symbol)}!==core_expected)$fatal(1,"TMDS final RGB mismatch");
   tmds_checked++;
  end
  if(valid_check[FINAL_DELAY])begin
   if({top_dut.final_hs,top_dut.final_vs,top_dut.final_de,top_dut.final_x}!==timings[FINAL_DELAY])$fatal(1,"M5 final pixel timing");
   if(top_dut.final_rgb!==expected[FINAL_DELAY])$fatal(1,"M5 final pixel mismatch xy=%0d,%0d actual=%h expected=%h app=%d mode=%d descriptor=%h",ex[FINAL_DELAY],ey[FINAL_DELAY],top_dut.final_rgb,expected[FINAL_DELAY],app,top_dut.adjust_mode,memory_descriptor);
   checked++;if(ey[FINAL_DELAY]>=32 && ey[FINAL_DELAY]<48)glyph_checked++;if(ey[FINAL_DELAY]>=60)content_checked++;
   if(memory_descriptor[17])preview_checked++;
  end
 end
 task frames(input integer n);repeat(n)begin @(posedge frame);@(negedge frame);end endtask
 task inspect(input integer wanted,input integer page_mode);
 begin checking=0;frames(2);if(app!=wanted || top_dut.adjust_mode!=page_mode || top_dut.pixel_identity!==identity)$fatal(1,"M5 identity/parameter CDC");
 checking=1;frames(1);checking=0;cycles(30);
 $display("M5 pixel window app=%d mode=%d page=%d B/C/V=%d/%d/%d preview=%b count=%d",app,top_dut.adjust_mode,top_dut.audio_image,top_dut.brightness_frame,top_dut.contrast_frame,top_dut.volume_frame,memory_descriptor[17],checked);
 end endtask
 integer i,j,at,b0,d0;reg [7:0] saved_b,saved_c;reg [3:0] saved_v;
 initial begin
 for(i=0;i<4;i++)begin bank_good[i]=0;bank_count[i]=0;bank_id[i]=0;end
 setup();for(i=0;i<4;i++)begin
 at=(8+i)*512;disk[at+28]=32;
 for(j=0;j<4;j++)begin disk[at+54+j*4]=8+i;disk[at+55+j*4]=j/2;disk[at+56+j*4]=j%2;disk[at+57+j*4]=0;end
 end
 cycles(10);rst=0;settled(1);wait(top_dut.sd_card_bmp_m0.cache_valid==15);b0=boots;d0=dirs;
 inspect(1,0);mode=1;cycles(300);next_page();inspect(1,1);short4();prev_page();inspect(1,1);
 mode=2;cycles(300);prev_page();inspect(1,2);saved_b=top_dut.brightness_src;saved_c=top_dut.contrast_src;saved_v=top_dut.volume_src;
 mode=3;cycles(300);wait(top_dut.sd_card_bmp_m0.preview_intent);inspect(1,3);next_page();inspect(1,3);
 short4();page(1);inspect(1,3);mode=0;cycles(300);toggle_app();settled(2);wait(top_dut.sd_card_bmp_m0.cache_valid==15);
 inspect(2,0);k1=0;cycles(1100);k1=1;cycles(300);inspect(2,0);
 mode=1;cycles(300);inspect(2,1);mode=2;cycles(300);inspect(2,2);
 mode=3;cycles(300);wait(top_dut.sd_card_bmp_m0.preview_intent);next_page();inspect(2,3);short4();page(1);inspect(2,3);
 if(top_dut.sd_card_bmp_m0.g_scenario.stage!=1 || top_dut.sd_card_bmp_m0.selected_audio_stage!=1)$fatal(1,"M5 scene preview final identity/audio");
 mode=0;cycles(300);inspect(2,0);toggle_app();settled(1);inspect(1,0);
 if(top_dut.brightness_src!=saved_b || top_dut.contrast_src!=saved_c || top_dut.volume_src!=saved_v || boots!=b0 || dirs!=d0)$fatal(1,"M5 parameters/physical scan changed");
 if(checked<100000 || glyph_checked<10000 || content_checked<10000 || preview_checked<10000 || tmds_checked<100000)$fatal(1,"M5 pixel coverage");
 $display("PASS M5 production final pixels: %0d RGB/timing, %0d glyph-region, %0d clean-content, %0d preview; %0d decoded HDMI TMDS pixels; actual SD BMP/scaler/bank/identity/keys/layers",checked,glyph_checked,content_checked,preview_checked,tmds_checked);$finish;
 end
 initial begin #(64'd6000000000);$fatal(1,"M5 pixels watchdog");end
endmodule
