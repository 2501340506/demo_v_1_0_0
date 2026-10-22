`timescale 1ns/1ps
// v0.25 S1 batch 1: mode_key_control on the shared 1 ms prescaler against the
// frozen v0.24.0 module (per-counter clock timing).
// F=1000 (one clock per ms): every output must match the reference on every
// clock. F=20000 (20 clocks per ms): random gestures (taps, window-length
// presses, KEY1/KEY4 1 s holds, KEY2 rescan holds, KEY1+KEY2 restore, contact
// bounce, mode/scene/busy changes and enable drops) keep >=10 ms from the
// 20/100/1000/2000 ms thresholds, so only the tick phase may differ: every
// output edge must occur in both, in order, within one tick (+2 clocks).
module tb_keys_tick;
 parameter integer SEED=25;
 parameter integer GESTURES=300;
 parameter integer F=20000;
 parameter integer PUB=1,SCENE=1,PREVIEW=1;
 localparam integer MS=F/1000;
 localparam integer TOL=MS>1?MS+2:0;
 localparam integer N=14;
 reg clk=0,rst=1;
 always #5 clk=~clk;
 reg key1=1,key2=1,key4=1,enable=1,scene_active=0,scene_allowed=1,busy=0;reg [1:0] mode=0;
 wire [N-1:0] o_ref,o_dut;
 mode_key_control_v024 #(.CLK_FREQ_HZ(F),.PREVIEW_ENABLE(PREVIEW),.SCENE_ENABLE(SCENE),.PUBLICITY_ENABLE(PUB)) ref_(
  .clk(clk),.rst(rst),.enable(enable),.key1(key1),.key2(key2),.key4(key4),.mode(mode),
  .scene_active(scene_active),.scene_allowed(scene_allowed),.application_busy(busy),
  .next_event(o_ref[0]),.rescan_event(o_ref[1]),.previous_event(o_ref[2]),.auto_toggle_event(o_ref[3]),
  .adjust_decrease(o_ref[4]),.adjust_increase(o_ref[5]),.adjust_restore(o_ref[6]),.adjust_select(o_ref[7]),
  .manual_activity(o_ref[8]),.scene_mode(o_ref[9]),.scene_next(o_ref[10]),.scene_warn(o_ref[11]),
  .scene_speed(o_ref[12]),.application_toggle(o_ref[13]));
 mode_key_control #(.CLK_FREQ_HZ(F),.PREVIEW_ENABLE(PREVIEW),.SCENE_ENABLE(SCENE),.PUBLICITY_ENABLE(PUB)) dut(
  .clk(clk),.rst(rst),.enable(enable),.key1(key1),.key2(key2),.key4(key4),.mode(mode),
  .scene_active(scene_active),.scene_allowed(scene_allowed),.application_busy(busy),
  .next_event(o_dut[0]),.rescan_event(o_dut[1]),.previous_event(o_dut[2]),.auto_toggle_event(o_dut[3]),
  .adjust_decrease(o_dut[4]),.adjust_increase(o_dut[5]),.adjust_restore(o_dut[6]),.adjust_select(o_dut[7]),
  .manual_activity(o_dut[8]),.scene_mode(o_dut[9]),.scene_next(o_dut[10]),.scene_warn(o_dut[11]),
  .scene_speed(o_dut[12]),.application_toggle(o_dut[13]));
 longint unsigned cyc=0;
 longint unsigned tr[0:N-1][$],td[0:N-1][$];
 reg [N-1:0] pr=0,pd=0;
 integer counts[0:N-1];
 always @(posedge clk)if(!rst)begin
  cyc<=cyc+1;
  for(int i=0;i<N;i++)begin
   if(o_ref[i]!==pr[i])tr[i].push_back(cyc);
   if(o_dut[i]!==pd[i])td[i].push_back(cyc);
  end
  pr<=o_ref;pd<=o_dut;
  if(^o_dut===1'bx)$fatal(1,"X on outputs at %0d",cyc);
 end
 always @(negedge clk)if(!rst)begin
  if(TOL==0 && o_dut!==o_ref)$fatal(1,"outputs %h, reference %h at %0d",o_dut,o_ref,cyc);
  for(int i=0;i<N;i++)begin
   while(tr[i].size()>0 && td[i].size()>0)begin
    automatic longint unsigned a=tr[i].pop_front(),b=td[i].pop_front();
    if(b+TOL<a || b>a+TOL)$fatal(1,"output %0d edge at %0d, reference %0d",i,b,a);
    counts[i]++;
   end
   if(tr[i].size()>0 && cyc>tr[i][0]+TOL)$fatal(1,"output %0d: reference edge at %0d missing",i,tr[i][0]);
   if(td[i].size()>0 && cyc>td[i][0]+TOL)$fatal(1,"output %0d: extra edge at %0d",i,td[i][0]);
  end
 end
 task wait_ms(input integer n);repeat(n*MS)@(posedge clk);endtask
 // Bounce: up to 5 short level flips (each <1 ms apart, total <6 ms).
 task bounce_to(inout reg k,input reg level);
  integer n;
  begin
   n=$urandom%6;
   repeat(n)begin k=~level;repeat(1+$urandom%MS)@(posedge clk);k=level;repeat(1+$urandom%MS)@(posedge clk);end
   k=level;
  end
 endtask
 function integer hold_ms();
  integer pick;
  begin
   pick=$urandom%6;
   case(pick)0:hold_ms=35;1:hold_ms=60;2:hold_ms=150;3:hold_ms=400;4:hold_ms=1200;default:hold_ms=2300;endcase
   hold_ms=hold_ms+$urandom%11;
  end
 endfunction
 integer g,kind,h,off;
 initial begin
  for(int i=0;i<N;i++)counts[i]=0;
  void'($urandom(SEED));
  repeat(MS*3+7)@(posedge clk);rst=0;
  wait_ms(30);
  for(g=0;g<GESTURES;g++)begin
   // Changes between gestures, with all keys released. Mode 0 is favoured
   // so the scene/application gestures are well covered.
   if($urandom%4==0)mode=($urandom%2)?0:$urandom%4;
   enable=($urandom%10)!=0;
   if($urandom%3==0)scene_active=$urandom%2;
   scene_allowed=($urandom%8)!=0;
   busy=($urandom%12)==0;
   wait_ms(30+$urandom%40);
   kind=$urandom%5;h=hold_ms();
   case(kind)
    0:begin bounce_to(key1,0);wait_ms(h);bounce_to(key1,1);end
    1:begin bounce_to(key2,0);wait_ms(h);bounce_to(key2,1);end
    2:begin bounce_to(key4,0);wait_ms(h);bounce_to(key4,1);end
    3:begin // KEY1 then KEY2 inside the 100 ms window
      off=30+$urandom%40;bounce_to(key1,0);wait_ms(off);bounce_to(key2,0);wait_ms(h);
      bounce_to(key1,1);wait_ms(30);bounce_to(key2,1);end
    default:begin // mode change while a key is held
      bounce_to(key2,0);wait_ms(h);mode=$urandom%4;wait_ms(40);bounce_to(key2,1);end
   endcase
  end
  wait_ms(200);
  for(int i=0;i<N;i++)if(tr[i].size()||td[i].size())$fatal(1,"output %0d unmatched edges",i);
  if(counts[0]==0 || counts[1]==0 || counts[3]==0 || counts[4]==0 || counts[5]==0 || counts[6]==0 || counts[7]==0)
   $fatal(1,"coverage: next %0d rescan %0d auto %0d dec %0d inc %0d restore %0d select %0d",
    counts[0],counts[1],counts[3],counts[4],counts[5],counts[6],counts[7]);
  // Scene-only mode leaves on any mode change, so its random gestures reach
  // fewer stage keys; there only one of next/warn/speed is required per seed.
  if(SCENE && (counts[9]==0 || (PUB ? (counts[10]==0 || counts[11]==0 || counts[12]==0) : counts[10]+counts[11]+counts[12]==0)))
   $fatal(1,"scene coverage: mode %0d next %0d warn %0d speed %0d",counts[9],counts[10],counts[11],counts[12]);
  if(PUB && counts[13]==0)$fatal(1,"application toggle never fired");
  $display("PASS keys tick F=%0d PUB=%0d SCENE=%0d: %0d gestures, edges next %0d rescan %0d prev %0d auto %0d dec %0d inc %0d restore %0d select %0d activity %0d scene %0d snext %0d warn %0d speed %0d app %0d",
   F,PUB,SCENE,GESTURES,counts[0],counts[1],counts[2],counts[3],counts[4],counts[5],counts[6],counts[7],counts[8],counts[9],counts[10],counts[11],counts[12],counts[13]);
  $finish;
 end
endmodule
