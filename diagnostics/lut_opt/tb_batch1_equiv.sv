`timescale 1ns/1ps
// S1 batch1: v0.15.0 and new brightness_contrast_adjust / pcm_media_tone side by side.
// Adjust: exhaustive red {value,brightness,contrast} sweep, then random with resets; every output every cycle.
// Tone: control outputs every cycle, samples whenever valid (consumers latch only on valid).
module tb_batch1_equiv;
 reg clk=0, rst=1;
 always #5 clk=~clk;
 integer cycle=0, errors=0, resets=0, sweep=0, samples=0, nonzero=0;
 localparam integer SWEEP=1<<24, RANDOM=400000;
 // brightness_contrast_adjust
 reg [23:0] rgb=0; reg [7:0] bright=0, contr=0; reg [47:0] side=0;
 wire [23:0] a_rgb, b_rgb; wire [47:0] a_side, b_side;
 brightness_contrast_adjust_v015 #(.SIDE_WIDTH(48)) aref(.clk(clk),.rst(rst),.rgb_in(rgb),.brightness(bright),.contrast(contr),
  .side_in(side),.rgb_out(a_rgb),.side_out(a_side));
 brightness_contrast_adjust #(.SIDE_WIDTH(48)) anew(.clk(clk),.rst(rst),.rgb_in(rgb),.brightness(bright),.contrast(contr),
  .side_in(side),.rgb_out(b_rgb),.side_out(b_side));
 // pcm_media_tone: production gain 128, other fixed gains, port volume
 reg enable=0, update=0, ready=0; reg [1:0] media=0; reg [7:0] volume=0;
 localparam integer NT=5;
 wire [NT-1:0] rv, ro, rb, nv, no, nb;
 wire signed [15:0] rl[0:NT-1], rr[0:NT-1], nl[0:NT-1], nr[0:NT-1];
 `define TONE_PAIR(K,FIX,VOL) \
  pcm_media_tone_v015 #(.CLOCK_HZ(96000),.BLIP_SAMPLES(300),.NOTE_SAMPLES(500)) tr``K(.clk(clk),.rst_n(!rst),.enable(enable),.media_update(update),.media_id(media),.volume(VOL), \
   .sample_valid(rv[K]),.sample_ready(ready),.sample_left(rl[K]),.sample_right(rr[K]),.overflow(ro[K]),.blip_active(rb[K])); \
  pcm_media_tone #(.CLOCK_HZ(96000),.BLIP_SAMPLES(300),.NOTE_SAMPLES(500),.FIXED_VOLUME(FIX)) tn``K(.clk(clk),.rst_n(!rst),.enable(enable),.media_update(update),.media_id(media),.volume(volume), \
   .sample_valid(nv[K]),.sample_ready(ready),.sample_left(nl[K]),.sample_right(nr[K]),.overflow(no[K]),.blip_active(nb[K]));
 `TONE_PAIR(0,128,8'd128)
 `TONE_PAIR(1,255,8'd255)
 `TONE_PAIR(2,77,8'd77)
 `TONE_PAIR(3,0,8'd0)
 `TONE_PAIR(4,-1,volume)
 task automatic check(input bit ok, input string what);
  if(!ok) begin errors=errors+1; if(errors<10) $display("MISMATCH %s cycle=%0d",what,cycle); end
 endtask
 integer k;
 always @(negedge clk) begin
  check({a_rgb,a_side}==={b_rgb,b_side},"adjust");
  for(k=0;k<NT;k=k+1) begin
   check({rv[k],ro[k],rb[k]}==={nv[k],no[k],nb[k]},$sformatf("tone%0d control",k));
   if(rv[k]) check({rl[k],rr[k]}==={nl[k],nr[k]},$sformatf("tone%0d sample",k));
  end
  if(rv[0] && ready) begin samples=samples+1; if(rl[0]!=0) nonzero=nonzero+1; end
 end
 always @(posedge clk) begin
  cycle<=cycle+1;
  #1;
  if(cycle>=10 && sweep<SWEEP) begin
   rgb={sweep[23:16],$urandom_range(255,0),$urandom_range(255,0)}; bright=sweep[15:8]; contr=sweep[7:0]; sweep=sweep+1;
  end else begin
   rgb=$urandom; bright=($urandom%4==0) ? {8{$urandom%2}} : $urandom; contr=($urandom%4==0) ? {8{$urandom%2}} : $urandom;
  end
  side={$urandom,$urandom};
  enable=($urandom%2000==0) ? ~enable : (cycle<40 ? 1 : enable);
  update=($urandom%3000==0); media=$urandom;
  if($urandom%5000==0) volume=$urandom;
  ready = ((cycle/7000)%3==1) ? 0 : ((cycle/7000)%3==2) ? ($urandom%40!=0) : ($urandom%2);
  if(cycle==10) rst=0;
  else if(sweep>=SWEEP && $urandom%40000==0) begin rst=1; resets=resets+1; end
  else if(rst && cycle>10 && $urandom%3==0) rst=0;
 end
 initial begin
  wait(cycle==SWEEP+RANDOM+20);
  if(resets<3 || samples<10000 || nonzero<5000)
   $display("** Error: insufficient coverage resets=%0d samples=%0d nonzero=%0d",resets,samples,nonzero);
  else if(errors) $display("** Error: %0d mismatches",errors);
  else $display("PASS batch1 equivalence cycles=%0d sweep=%0d resets=%0d tone_samples=%0d nonzero=%0d",cycle,sweep,resets,samples,nonzero);
  $finish;
 end
endmodule
