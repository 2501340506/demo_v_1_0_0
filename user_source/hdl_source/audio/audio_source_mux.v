module audio_source_mux(
 input wire wav_valid,output wire wav_ready,input wire signed [15:0] wav_left,wav_right,input wire wav_active,
 input wire arp_valid,output wire arp_ready,input wire signed [15:0] arp_left,arp_right,
 input wire out_ready,output wire out_valid,output wire signed [15:0] out_left,out_right);
 wire use_wav=wav_active;
 assign out_valid=use_wav?wav_valid:arp_valid; assign out_left=use_wav?wav_left:arp_left; assign out_right=use_wav?wav_right:arp_right;
 assign wav_ready=use_wav?out_ready:out_ready; assign arp_ready=use_wav?1'b0:out_ready;
endmodule
