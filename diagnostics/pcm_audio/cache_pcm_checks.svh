// Production 4096-sample ring, 100/25 MHz, continuous file sample comparison.
function [7:0] pcm_byte(input integer offset);
 reg [15:0] value;
 begin value=(offset/2)*62-20000;pcm_byte=offset%2 ? value[15:8]:value[7:0];end
endfunction
integer pcm_received=0,pcm_total=0,pcm_sessions=0;
reg pcm_was_active=0;
reg signed [15:0] pcm_expected;
wire mixed_valid;
wire mixed_ready=1;
wire signed [15:0] mixed_left,mixed_right;
wire fallback_ready;
audio_source_mux audio_mux(.clk(pix_clk),.rst_n(!rst),
 .wav_valid(bgm_valid),.wav_ready(bgm_ready),.wav_active(bgm_active),.wav_left(bgm_left),.wav_right(bgm_right),
 .arp_valid(tone.sample_valid),.arp_ready(fallback_ready),.arp_left(tone.sample_left),.arp_right(tone.sample_right),
 .out_ready(mixed_ready),.out_valid(mixed_valid),.out_left(mixed_left),.out_right(mixed_right));
always @(posedge pix_clk)begin
 if(rst || !bgm_active)begin pcm_received=0;pcm_was_active=0;end
 else begin
  if(!pcm_was_active)begin pcm_sessions++;pcm_was_active=1;end
  if(bgm_valid && bgm_ready)begin
   pcm_expected=((pcm_received%601)*62-20000)/2;
   if(bgm_left!==pcm_expected || bgm_right!==pcm_expected || mixed_left!==pcm_expected || mixed_right!==pcm_expected)
    $fatal(1,"production PCM #%0d got %0d expected %0d",pcm_received,bgm_left,pcm_expected);
   pcm_received++;pcm_total++;
  end
  if(app.g_audio.u_player.underflow_count || app.g_audio.u_player.output_overrun)
   $fatal(1,"production PCM underrun/overrun");
 end
end
always @(posedge src_clk)if(!rst && app.sd_local_rst && (app.a_busy || bgm_active))
 $fatal(1,"global rescan reset before audio drain");
final begin
 if(pcm_total<10000 || pcm_sessions<2)$error("insufficient PCM integration coverage");
 $display("PCM system observations: %0d exact samples, %0d sessions; no underrun/overrun",pcm_total,pcm_sessions);
end
