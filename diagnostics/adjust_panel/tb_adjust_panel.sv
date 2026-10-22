`timescale 1ns/1ps
// v0.27 SW4 adjust panel: key gestures, panel state, panel pixels.
// Keys run with CLK_FREQ_HZ=1000 (one ms tick per clock).
module tb_panel_keys;
 reg clk=0,rst=1,active=0,k1=1,k2=1,k4=1;
 wire dec,inc,res,sel,hold;
 always #5 clk=~clk;
 adjust_panel_keys #(.CLK_FREQ_HZ(1000)) dut(clk,rst,active,k1,k2,k4,dec,inc,res,sel,hold);
 integer n_dec=0,n_inc=0,n_res=0,n_sel=0,n_hold=0;
 always @(posedge clk)begin n_dec+=dec;n_inc+=inc;n_res+=res;n_sel+=sel;n_hold+=hold;end
 task ticks(input integer t);repeat(t)@(negedge clk);endtask
 task expect_counts(input integer d,i,r,s,h,input [127:0] what);
  if(n_dec!=d || n_inc!=i || n_res!=r || n_sel!=s || n_hold!=h)begin
   $display("FAIL %0s dec=%0d inc=%0d res=%0d sel=%0d hold=%0d",what,n_dec,n_inc,n_res,n_sel,n_hold);$finish;
  end
 endtask
 initial begin
  ticks(4);rst=0;ticks(40);
  k2=0;ticks(60);k2=1;ticks(60);
  expect_counts(0,0,0,0,0,"inactive");
  active=1;ticks(10);
  k2=0;ticks(60);k2=1;ticks(60);expect_counts(0,1,0,0,0,"increase");
  k1=0;ticks(60);k1=1;ticks(60);expect_counts(1,1,0,0,0,"decrease");
  k1=0;ticks(30);k2=0;ticks(60);k1=1;k2=1;ticks(80);expect_counts(1,1,1,0,0,"restore");
  k4=0;ticks(100);k4=1;ticks(60);expect_counts(1,1,1,1,0,"select");
  k4=0;ticks(1200);expect_counts(1,1,1,1,1,"hold fires while held");
  k4=1;ticks(60);expect_counts(1,1,1,1,1,"hold release adds no select");
  active=0;ticks(5);k2=0;ticks(60);k2=1;ticks(60);expect_counts(1,1,1,1,1,"released ownership");
  $display("PASS tb_panel_keys");$finish;
 end
endmodule

module tb_panel_state;
 reg clk=0,rst=1,dec=0,inc=0,res=0,sel=0,panel=0,hold=0;reg [1:0] mode=0;
 wire [7:0] b,c;wire [4:0] v;wire [3:0] item;wire [1:0] selected,height,wash;
 wire focus,wave,osd,scroll,fade,sp_up,sp_down,sp_def;
 integer n_up=0,n_down=0,n_def=0;
 always @(posedge clk)begin n_up+=sp_up;n_down+=sp_down;n_def+=sp_def;end
 always #5 clk=~clk;
 media_adjust_control dut(clk,rst,mode,dec,inc,res,sel,b,c,v,selected,panel,hold,
  focus,item,wave,height,wash,osd,scroll,fade,sp_up,sp_down,sp_def);
 localparam DEC=0,INC=1,RES=2,SEL=3,HOLD=4;
 task pulse(input integer w);begin
  @(negedge clk);case(w)DEC:dec=1;INC:inc=1;RES:res=1;SEL:sel=1;default:hold=1;endcase
  @(negedge clk);dec=0;inc=0;res=0;sel=0;hold=0;@(negedge clk);
 end endtask
 task check(input ok,input [255:0] what);if(!ok)begin $display("FAIL %0s",what);$finish;end endtask
 initial begin
  repeat(3)@(negedge clk);rst=0;@(negedge clk);
  check(item==0 && !focus && wave && height==3 && wash==2 && osd && scroll && fade,"defaults");
  // Without SW4 nothing adjusts, whatever SW1/SW2 say (v0.27 removed modes 1/2).
  mode=1;@(negedge clk);@(negedge clk);pulse(INC);check(b==128,"mode1 no longer adjusts");
  pulse(SEL);check(selected==0 && item==0 && !focus,"mode1 select ignored");
  mode=0;@(negedge clk);@(negedge clk);pulse(INC);check(b==128 && v==10,"mode0 ignores adjust");
  panel=1;@(negedge clk);@(negedge clk);
  pulse(DEC);check(item==10,"cursor wraps down");
  pulse(INC);check(item==0,"cursor wraps up");
  pulse(INC);check(item==1 && c==128,"cursor moves without editing");
  pulse(SEL);check(focus,"enter edit");
  pulse(DEC);pulse(DEC);check(c==96,"edit contrast");
  pulse(RES);check(c==128,"restore contrast");
  pulse(SEL);check(!focus,"leave edit");
  pulse(INC);pulse(INC);pulse(SEL);pulse(DEC);check(item==3 && !wave,"wave off");
  pulse(SEL);pulse(INC);pulse(SEL);pulse(DEC);pulse(DEC);pulse(DEC);pulse(DEC);check(height==0,"height floor");
  pulse(SEL);pulse(INC);pulse(SEL);pulse(INC);pulse(INC);check(wash==3,"wash ceiling");
  pulse(SEL);pulse(INC);check(item==6 && n_up==0,"speed item");pulse(SEL);
  pulse(INC);pulse(INC);pulse(DEC);check(n_up==2 && n_down==1,"speed requests");
  pulse(RES);check(n_def==1 && b==128,"speed restore request");
  pulse(SEL);pulse(INC);pulse(SEL);pulse(DEC);check(item==7 && !osd,"osd off");
  pulse(SEL);pulse(INC);pulse(SEL);pulse(DEC);check(!scroll,"scroll off");
  pulse(SEL);pulse(INC);pulse(SEL);pulse(DEC);check(!fade,"fade off");
  pulse(HOLD);check(!osd,"hold away from reset item does nothing");
  pulse(SEL);pulse(INC);check(item==10,"reset item");
  pulse(HOLD);check(b==128 && v==10 && wave && height==3 && wash==2 && osd && scroll && fade && n_def==2,"reset all");
  pulse(INC);pulse(INC);pulse(INC);check(item==2,"volume item");pulse(SEL);
  repeat(15)pulse(INC);check(v==20,"volume ceiling 200%");
  pulse(DEC);check(v==19,"volume down from 200%");pulse(RES);check(v==10,"volume restore 100%");
  pulse(SEL);check(!focus,"leave volume edit");
  pulse(SEL);check(focus,"focus before exit");
  panel=0;@(negedge clk);@(negedge clk);check(!focus,"exit clears focus");
  mode=2;@(negedge clk);@(negedge clk);pulse(INC);check(b==128 && selected==0,"mode2 no longer adjusts");
  $display("PASS tb_panel_state");$finish;
 end
endmodule

// 640x480 raster with short blanking; checks pass-through, slide and colours.
module tb_panel_pixels;
 reg clk=0,rst=1,panel=0;
 always #5 clk=~clk;
 localparam H=700,V=490;
 integer hc=0,vc=0;
 wire de=hc<640 && vc<480,vs=!(vc>=484 && vc<486);
 wire [9:0] x=hc<640?hc:10'd0;
 wire [23:0] rgb_in={x[7:0],8'h55,8'haa};
 wire [23:0] out;
 adjust_panel_overlay dut(.clk(clk),.rst(rst),.vs(vs),.de(de),.pixel_x(x),.rgb_in(rgb_in),
  .panel(panel),.focus(1'b0),.item(4'd2),.brightness(8'd128),.contrast(8'd128),.volume_level(5'd10),
  .wave_on(1'b1),.wave_height(2'd3),.wash_level(2'd2),.osd_on(1'b1),.scroll_on(1'b1),.fade_on(1'b1),
  .bright_bcd(12'h128),.contrast_bcd(12'h128),.volume_bcd(12'h100),.scene_on(1'b0),.scene_speed(2'd0),.rgb_out(out));
 always @(posedge clk)if(!rst)begin
  if(hc==H-1)begin hc<=0;vc<=vc==V-1?0:vc+1;end else hc<=hc+1;
 end
 integer frame=0,changed=0;reg [23:0] grab[0:4];
 always @(posedge clk)if(!rst && hc==0 && vc==0)frame<=frame+1;
 // Pixels are judged in the output timing: the panel lands 2 px right.
 always @(posedge clk)if(!rst && de)begin
  if(out!=rgb_in)changed<=changed+1;
  if(vc==220 && hc==299)grab[0]<=out;   // left frame edge (x 296..297, +2)
  if(vc==221 && hc==360)grab[1]<=out;   // empty panel body
  if(vc==124 && hc==400)grab[2]<=out;   // title band
  if(vc==221 && hc==200)grab[3]<=out;   // left of the panel
  if(vc==156 && hc==440)grab[4]<=out;   // highlighted item row (volume)
 end
 task frames(input integer n);integer f;begin f=frame;wait(frame==f+n);end endtask
 task check(input ok,input [255:0] what);if(!ok)begin $display("FAIL %0s",what);$finish;end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;
  frames(3);check(changed==0,"panel off is pass-through");
  panel=1;frames(10);
  check(grab[3]==({8'd200,8'h55,8'haa}),"outside untouched");
  check(grab[0]==24'h3c82f0,"blue frame");
  check(grab[1]==24'h102030,"dark body");
  check(grab[2]==24'h3c82f0 || grab[2]==24'hffffff,"title band");
  check(grab[4]==24'h1c3c6c || grab[4]==24'hffffff,"item cursor band");
  panel=0;frames(10);changed=0;frames(2);check(changed==0,"slid out to pass-through");
  $display("PASS tb_panel_pixels");$finish;
 end
endmodule

// Preview: dumps the RTL panel over a gradient as 640x480 BMPs, once with
// the cursor on VOLUME and once editing SCENE SPEED (2X).
module tb_panel_frame;
 reg clk=0,rst=1,focus=0;reg [3:0] item=2;
 always #5 clk=~clk;
 localparam H=700,V=490;
 integer hc=0,vc=0;
 wire de=hc<640 && vc<480,vs=!(vc>=484 && vc<486);
 wire [9:0] x=hc<640?hc:10'd0;
 wire [8:0] y=vc;
 wire [23:0] rgb_in={x[9:2],y[8:1],8'h50};
 wire [23:0] out;
 adjust_panel_overlay dut(.clk(clk),.rst(rst),.vs(vs),.de(de),.pixel_x(x),.rgb_in(rgb_in),
  .panel(1'b1),.focus(focus),.item(item),.brightness(8'd160),.contrast(8'd128),.volume_level(5'd20),
  .wave_on(1'b1),.wave_height(2'd2),.wash_level(2'd1),.osd_on(1'b1),.scroll_on(1'b0),.fade_on(1'b1),
  .bright_bcd(12'h160),.contrast_bcd(12'h128),.volume_bcd(12'h200),.scene_on(1'b1),.scene_speed(2'd1),.rgb_out(out));
 always @(posedge clk)if(!rst)begin
  if(hc==H-1)begin hc<=0;vc<=vc==V-1?0:vc+1;end else hc<=hc+1;
 end
 reg [23:0] img[0:640*480-1];
 always @(posedge clk)if(!rst && de)img[vc*640+hc]<=out;
 task put32(input integer f,input integer v);
  begin $fwrite(f,"%c%c%c%c",v[7:0],v[15:8],v[23:16],v[31:24]);end
 endtask
 task dump(input [8*64-1:0] name);
  integer f,r,c;
  begin
   f=$fopen(name,"wb");
   $fwrite(f,"BM");put32(f,54+640*480*3);put32(f,0);put32(f,54);
   put32(f,40);put32(f,640);put32(f,480);$fwrite(f,"%c%c%c%c",8'd1,8'd0,8'd24,8'd0);
   put32(f,0);put32(f,640*480*3);put32(f,2835);put32(f,2835);put32(f,0);put32(f,0);
   for(r=479;r>=0;r=r-1)for(c=0;c<640;c=c+1)
    $fwrite(f,"%c%c%c",img[r*640+c][7:0],img[r*640+c][15:8],img[r*640+c][23:16]);
   $fclose(f);
  end
 endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;
  repeat(11)begin wait(vc==481);wait(vc==0);end
  dump("panel_cursor.bmp");
  focus=1;item=6;
  repeat(2)begin wait(vc==481);wait(vc==0);end
  dump("panel_edit.bmp");
  $display("PASS tb_panel_frame");$finish;
 end
endmodule

// Panel SCENE SPEED against a model of scenario_fsm's speed key: each accepted
// step cycles 0->1->2->0, and the model can refuse steps (scene not running).
module tb_speed_request;
 reg clk=0,rst=1,up=0,down=0,restore=0,accept=1;reg [1:0] speed=0;
 wire step;integer steps=0;
 always #5 clk=~clk;
 scene_speed_request dut(clk,rst,up,down,restore,speed,step);
 always @(posedge clk)if(step)begin steps++;if(accept)speed<=speed==2?2'd0:speed+2'd1;end
 task req(input integer w);begin
  @(negedge clk);if(w==0)up=1;else if(w==1)down=1;else restore=1;
  @(negedge clk);up=0;down=0;restore=0;repeat(120)@(negedge clk);
 end endtask
 task check(input ok,input [255:0] what);if(!ok)begin $display("FAIL %0s speed=%0d steps=%0d",what,speed,steps);$finish;end endtask
 initial begin
  repeat(3)@(negedge clk);rst=0;
  req(0);check(speed==1 && steps==1,"1X up to 2X");
  req(0);check(speed==2 && steps==2,"2X up to 4X");
  req(0);check(speed==2 && steps==2,"4X up saturates");
  req(1);check(speed==1 && steps==4,"4X down to 2X wraps through 1X");
  req(1);check(speed==0 && steps==6,"2X down to 1X");
  req(1);check(speed==0 && steps==6,"1X down saturates");
  req(0);req(0);req(2);check(speed==0,"restore to 1X");
  // FSM keeps changing speed on its own (KEY1 long press) between requests.
  speed=2;@(negedge clk);req(1);check(speed==1,"down follows the FSM's current speed");
  // Refused steps are tried at most three times, then dropped.
  accept=0;steps=0;req(0);check(speed==1 && steps==3,"refused steps give up");
  accept=1;steps=0;repeat(200)@(negedge clk);check(steps==0,"no steps after giving up");
  $display("PASS tb_speed_request");$finish;
 end
endmodule
