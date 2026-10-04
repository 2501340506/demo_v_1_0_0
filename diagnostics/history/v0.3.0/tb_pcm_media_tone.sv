`timescale 1ns/1ps
module tb_pcm_media_tone;
 reg clk=0,rst_n=0,enable=0,update=0,ready=1;
 reg [1:0] id=0;
 always #5 clk=~clk;
 wire valid,overflow,blip;
 wire signed [15:0] l,r;
 pcm_media_tone #(.CLOCK_HZ(96000)) dut(.clk(clk),.rst_n(rst_n),.enable(enable),
 .media_update(update),.media_id(id),.volume(8'd128),.sample_valid(valid),
 .sample_ready(ready),.sample_left(l),.sample_right(r),.overflow(overflow),.blip_active(blip));
 integer cue=0,note=0,count=0,phase=0,current=0,pushed=0,popped=0,events=0;
 integer queue[0:400000];
 integer incs[0:23];
 integer value,inc,oldphase;
 real sine;
 reg stalled=0; reg signed [15:0] held;
 always @(posedge clk) if(rst_n) begin
  if(stalled && (!valid || l!==held)) $fatal(1,"FIFO changed during backpressure");
  stalled=valid && !ready; held=l;
  if(valid && ready) begin
   if(popped>=pushed || ($signed(l)-queue[popped]>1 || queue[popped]-$signed(l)>1) || l!==r)
    $fatal(1,"PCM waveform/stereo mismatch sample %0d got %0d expected %0d",popped,l,queue[popped]);
   popped=popped+1;
  end
  if(dut.sample_tick) begin
   sine=12000.0*$sin(6.283185307179586*((phase>>16)&15)/16.0);
   value=$rtoi(sine+(sine>=0 ? 0.5 : -0.5));
   if(dut.sample_push) begin queue[pushed]=enable ? (value>>>1) : 0; pushed=pushed+1;end
   if(enable) begin
    inc=cue>0 ? 32768 : incs[current*6+note];
    phase=(phase+inc)%1048576;
    if(cue>0) cue=cue-1;
    else if(count==11999) begin count=0;note=(note+1)%6;end
    else count=count+1;
   end
  end
  if(enable && update) begin current=id;cue=4800;note=0;count=0;events=events+1;end
  #1;
  if(dut.phase!==phase[19:0] || dut.note_index!==note[2:0] || dut.blip_countdown!=cue)
   $fatal(1,"phase continuity/cue duration/note timing mismatch");
 end
 task commit(input [1:0] picture);
  begin @(negedge clk);enable=1;id=picture;update=1;@(negedge clk);update=0;end
 endtask
 integer i;
 initial begin
  incs[0]=11426;incs[1]=14396;incs[2]=17127;incs[3]=22860;incs[4]=17127;incs[5]=14396;
  incs[6]=9634;incs[7]=11426;incs[8]=14396;incs[9]=19269;incs[10]=14396;incs[11]=11426;
  incs[12]=11426;incs[13]=12833;incs[14]=14396;incs[15]=17127;incs[16]=19269;incs[17]=22860;
  incs[18]=11426;incs[19]=8566;incs[20]=14396;incs[21]=11426;incs[22]=8566;incs[23]=14396;
  repeat(4) @(negedge clk);rst_n=1;
  repeat(200) @(negedge clk);
  for(i=0;i<4;i=i+1) begin
   commit(i[1:0]);repeat(153620) @(negedge clk);
  end
  // Same ID is a new commit, even though the bus value does not change.
  commit(3);repeat(20) @(negedge clk);
  ready=0;repeat(40) @(negedge clk);ready=1;
  repeat(40) @(negedge clk);
  if(!overflow || events!=5) $fatal(1,"overflow/event exercise missing");
  $display("PASS S8 four full melodies, 4800 cue samples, 12000 samples/note, silence, fixed volume, phase and stalled FIFO (%0d samples)",popped);
  $finish;
 end
 initial begin #10000000;$fatal(1,"timeout");end
endmodule
