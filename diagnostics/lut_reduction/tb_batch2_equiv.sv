`timescale 1ns/1ps
// Old/new video_delay and pcm_media_tone under identical stimulus, all outputs every cycle.
module tb_batch2_equiv;
 reg clk=0, rst=1;
 always #5 clk=~clk;
 integer cycle=0, errors=0, resets=0, nonzero_x=0, tone_samples=0, port_samples=0, fixed_nonzero=0;
 // video_delay
 reg hs=0, vs=0, de=0; reg [9:0] x=0; reg [23:0] data=0;
 wire r_en, r_hs, r_vs, r_de, n_en, n_hs, n_vs, n_de;
 wire [23:0] r_out, n_out; wire [9:0] r_x, n_x;
 video_delay_ref vref(.video_clk(clk),.rst(rst),.read_en(r_en),.read_data(data),.hs(hs),.vs(vs),.de(de),.video_x(x),
  .hs_r(r_hs),.vs_r(r_vs),.de_r(r_de),.vout_data(r_out),.video_x_r(r_x));
 video_delay vnew(.video_clk(clk),.rst(rst),.read_en(n_en),.read_data(data),.hs(hs),.vs(vs),.de(de),.video_x(x),
  .hs_r(n_hs),.vs_r(n_vs),.de_r(n_de),.vout_data(n_out),.video_x_r(n_x));
 // pcm_media_tone: production gain (port 128 vs FIXED_VOLUME 128) and port mode
 reg enable=0, update=0, ready=0; reg [1:0] media=0; reg [7:0] volume=0;
 wire a_v,b_v,c_v,d_v,a_o,b_o,c_o,d_o,a_b,b_b,c_b,d_b;
 wire signed [15:0] a_l,a_r,b_l,b_r,c_l,c_r,d_l,d_r;
 pcm_media_tone_ref #(.CLOCK_HZ(96000)) tref(.clk(clk),.rst_n(!rst),.enable(enable),.media_update(update),.media_id(media),.volume(8'd128),
  .sample_valid(a_v),.sample_ready(ready),.sample_left(a_l),.sample_right(a_r),.overflow(a_o),.blip_active(a_b));
 pcm_media_tone #(.CLOCK_HZ(96000),.FIXED_VOLUME(128)) tnew(.clk(clk),.rst_n(!rst),.enable(enable),.media_update(update),.media_id(media),.volume(volume),
  .sample_valid(b_v),.sample_ready(ready),.sample_left(b_l),.sample_right(b_r),.overflow(b_o),.blip_active(b_b));
 pcm_media_tone_ref #(.CLOCK_HZ(480000),.BLIP_SAMPLES(300),.NOTE_SAMPLES(500)) pref(.clk(clk),.rst_n(!rst),.enable(enable),.media_update(update),.media_id(media),.volume(volume),
  .sample_valid(c_v),.sample_ready(ready),.sample_left(c_l),.sample_right(c_r),.overflow(c_o),.blip_active(c_b));
 pcm_media_tone #(.CLOCK_HZ(480000),.BLIP_SAMPLES(300),.NOTE_SAMPLES(500)) pnew(.clk(clk),.rst_n(!rst),.enable(enable),.media_update(update),.media_id(media),.volume(volume),
  .sample_valid(d_v),.sample_ready(ready),.sample_left(d_l),.sample_right(d_r),.overflow(d_o),.blip_active(d_b));
 task automatic check(input bit ok, input string what);
  if(!ok) begin errors=errors+1; if(errors<10) $display("MISMATCH %s cycle=%0d",what,cycle); end
 endtask
 always @(negedge clk) begin
  check({r_en,r_hs,r_vs,r_de,r_out,r_x}==={n_en,n_hs,n_vs,n_de,n_out,n_x},"video_delay");
  check({a_v,a_o,a_b,a_l,a_r}==={b_v,b_o,b_b,b_l,b_r},"tone fixed 128");
  check({c_v,c_o,c_b,c_l,c_r}==={d_v,d_o,d_b,d_l,d_r},"tone port volume");
  if(r_x!=0) nonzero_x=nonzero_x+1;
  if(a_v && ready) begin tone_samples=tone_samples+1; if(a_l!=0) fixed_nonzero=fixed_nonzero+1; end
  if(c_v && ready) port_samples=port_samples+1;
 end
 always @(posedge clk) begin
  cycle<=cycle+1;
  #1;
  hs=$urandom; vs=($urandom%50==0) ? ~vs : vs; de=$urandom; x=$urandom; data=$urandom;
  enable=($urandom%2000==0) ? ~enable : (cycle<40 ? 1 : enable);
  update=($urandom%3000==0); media=$urandom;
  if($urandom%5000==0) volume=$urandom;
  // Ready: long stretches of free flow, stalls (FIFO full/overflow) and bursts.
  ready = ((cycle/7000)%3==1) ? 0 : ((cycle/7000)%3==2) ? ($urandom%40!=0) : ($urandom%2);
  if(cycle>100 && $urandom%40000==0) begin rst=1; resets=resets+1; end
  else if(cycle==10) rst=0;
  else if(rst && cycle>10 && $urandom%3==0) rst=0;
 end
 initial begin
  wait(cycle==300000);
  if(resets<3 || nonzero_x<1000 || tone_samples<300 || fixed_nonzero<100 || port_samples<1000)
   $display("** Error: insufficient coverage resets=%0d x=%0d fixed=%0d/%0d port=%0d",resets,nonzero_x,tone_samples,fixed_nonzero,port_samples);
  else if(errors) $display("** Error: %0d mismatches",errors);
  else $display("PASS batch2 equivalence cycles=%0d resets=%0d video_nonzero_x=%0d tone_fixed_samples=%0d tone_port_samples=%0d",cycle,resets,nonzero_x,tone_samples,port_samples);
  $finish;
 end
endmodule
