// Hold source selection through a stalled sample and its acceptance edge.
module audio_source_mux(
 input wire clk,rst_n,
 input wire wav_valid,output wire wav_ready,input wire signed [15:0] wav_left,wav_right,input wire wav_active,
 input wire arp_valid,output wire arp_ready,input wire signed [15:0] arp_left,arp_right,
 input wire out_ready,output wire out_valid,output wire signed [15:0] out_left,out_right);
 reg held,held_select;
 wire use_wav=held?held_select:wav_active;
 assign out_valid=rst_n && (use_wav?wav_valid:arp_valid);
 assign out_left=use_wav?wav_left:arp_left;assign out_right=use_wav?wav_right:arp_right;
 assign wav_ready=rst_n && use_wav && out_ready;
 // The free-running tone producer must be drained when not selected.
 assign arp_ready=rst_n && (use_wav || out_ready);
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin held<=0;held_select<=0;end
  else if(held)begin if(out_valid && out_ready)held<=0;end
  else if(out_valid && !out_ready)begin held<=1;held_select<=use_wav;end
 end
endmodule
