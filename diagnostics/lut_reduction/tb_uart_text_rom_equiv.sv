`timescale 1ns/1ps
// Old/new uart_event_logger: random events/fields/replies; uart_tx and
// reply_ready compared every cycle. Event names and banner are now ROM data.
module tb_uart_text_rom_equiv;
 reg clk=0, rst=1;
 reg [15:0] events=0; reg [1:0] image=0; reg [31:0] sector=0; reg [2:0] err=0; reg [3:0] phase=0; reg autoe=0;
 reg [63:0] dbg=0; reg rvalid=0, rlast=0; reg [7:0] rdata=0;
 wire r_tx, n_tx, r_ready, n_ready;
 always #5 clk=~clk;
 uart_event_logger_ref #(.CLK_FREQ_HZ(2000000),.BAUD_RATE(500000),.REPLY_ENABLE(1)) rref(.clk(clk),.rst(rst),.events(events),
  .image_index(image),.sector(sector),.error_code(err),.phase(phase),.auto_enabled(autoe),.sd_debug(dbg),.uart_tx(r_tx),
  .reply_valid(rvalid),.reply_data(rdata),.reply_last(rlast),.reply_ready(r_ready));
 uart_event_logger #(.CLK_FREQ_HZ(2000000),.BAUD_RATE(500000),.REPLY_ENABLE(1)) rnew(.clk(clk),.rst(rst),.events(events),
  .image_index(image),.sector(sector),.error_code(err),.phase(phase),.auto_enabled(autoe),.sd_debug(dbg),.uart_tx(n_tx),
  .reply_valid(rvalid),.reply_data(rdata),.reply_last(rlast),.reply_ready(n_ready));
 integer cycle=0, errors=0, records=0, boots=0, cache_names=0, drops=0, replies=0, resets=0, reply_left=0;
 integer kinds[0:15];
 initial for(int i=0;i<16;i++) kinds[i]=0;
 always @(negedge clk) begin
  if({r_tx,r_ready}!=={n_tx,n_ready}) begin errors++; if(errors<10) $display("MISMATCH cycle=%0d tx=%b/%b ready=%b/%b",cycle,r_tx,n_tx,r_ready,n_ready); end
 end
 // Coverage from the reference serializer state.
 always @(posedge clk) if(!rst) begin
  if(rref.waiting && rref.done && rref.boot && rref.char_index==23) boots++;
  if(rref.start && !rref.boot && rref.char_index==0) begin
   records++; kinds[rref.kind]++;
   if(rref.kind==11 && (rref.snapshot[68:65]==4'hc || rref.snapshot[68:65]==4'hd)) cache_names++;
   if(rref.remaining==16'h8000 && rref.kind==15) drops++;
  end
  if(rvalid && r_ready) replies++;
 end
 always @(posedge clk) begin
  cycle<=cycle+1; #1;
  events=0;
  if(!rst && $urandom%((cycle/60000)%2 ? 40 : 20000)==0) begin
   events = 16'b1 << ($urandom%16);
   if($urandom%5==0) events = events | (16'b1 << ($urandom%16));
   image=$urandom; sector={$urandom}; err=$urandom; autoe=$urandom; dbg={$urandom,$urandom};
   phase = ($urandom%3==0) ? (($urandom%2) ? 4'hc : 4'hd) : $urandom;
   if($urandom%4==0) events = 16'b1 << 11;
  end
  // Reply bursts of 1..8 bytes, held until accepted.
  if(rvalid && r_ready) begin
   reply_left--; rdata=$urandom; rlast=(reply_left==1); if(reply_left==0) rvalid=0;
  end
  if(!rvalid && !rst && $urandom%200==0) begin reply_left=1+$urandom%8; rvalid=1; rdata=$urandom; rlast=(reply_left==1); end
  if(cycle>100 && $urandom%500000==0) begin rst=1; resets++; rvalid=0; end
  else if(cycle==10 || (rst && $urandom%4==0)) rst=0;
 end
 initial begin
  wait(cycle==2500000);
  begin
   automatic int missing=0; for(int i=0;i<16;i++) if(kinds[i]==0) missing++;
   if(records<500 || boots<3 || cache_names<20 || drops<5 || replies<100 || missing!=0)
    $display("** Error: insufficient coverage records=%0d boots=%0d cache=%0d drops=%0d replies=%0d missing_kinds=%0d",records,boots,cache_names,drops,replies,missing);
   else if(errors) $display("** Error: %0d mismatches",errors);
   else $display("PASS uart text ROM equivalence cycles=%0d records=%0d boots=%0d cache_names=%0d drops=%0d reply_bytes=%0d resets=%0d all 16 kinds",cycle,records,boots,cache_names,drops,replies,resets);
  end
  $finish;
 end
endmodule
