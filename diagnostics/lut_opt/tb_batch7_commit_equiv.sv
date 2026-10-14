`timescale 1ns/1ps
// S2 batch7: v0.15.0 vs new subtitle_frame_commit. Both resets come from one request with
// independent release skew (production reset_sync); every output every dst cycle.
module tb_batch7_commit_equiv;
 reg sclk=0, dclk=0; always #5 sclk=~sclk; always #20 dclk=~dclk;
 reg reset_request=1; reg src_rst=1, dst_rst=1;
 always @(posedge sclk or posedge reset_request) if(reset_request) src_rst<=1; else if($urandom%4==0) src_rst<=0;
 always @(posedge dclk or posedge reset_request) if(reset_request) dst_rst<=1; else if($urandom%4==0) dst_rst<=0;
 reg [119:0] text=0; reg [3:0] length=0; reg enable=1; reg frame_start=0;
 wire [119:0] rt,nt; wire [3:0] rl,nl; wire re,ne,rc,nc;
 subtitle_frame_commit_v015 ref_c(.src_clk(sclk),.src_rst(src_rst),.src_text(text),.src_length(length),.src_enable(enable),
  .dst_clk(dclk),.dst_rst(dst_rst),.frame_start(frame_start),.dst_text(rt),.dst_length(rl),.dst_enable(re),.text_changed(rc));
 subtitle_frame_commit new_c(.src_clk(sclk),.src_rst(src_rst),.src_text(text),.src_length(length),.src_enable(enable),
  .dst_clk(dclk),.dst_rst(dst_rst),.frame_start(frame_start),.dst_text(nt),.dst_length(nl),.dst_enable(ne),.text_changed(nc));
 integer cycle=0, errors=0, changes=0, applies_same=0, resets=0;
 always @(negedge dclk) begin
  if({rt,rl,re,rc}!=={nt,nl,ne,nc}) begin errors=errors+1; if(errors<10) $display("MISMATCH cycle=%0d",cycle); end
  if(rc) changes=changes+1;
  if(ref_c.apply_now && !rc) applies_same=applies_same+1;   // enable-only updates
 end
 reg [119:0] texts[0:3]; initial begin texts[0]=120'h0000002041475046208c8b8b8a8389; texts[1]=120'h48454c4c4f; texts[2]=0; texts[3]=120'h414243; end
 always @(posedge sclk) begin
  #1;
  case($urandom%2000)
   0: text=texts[$urandom%4]; 1: text={$urandom,$urandom,$urandom,$urandom}; 2: length=$urandom; 3: enable=~enable;
   4: begin text=texts[0]; length=12; end default: ;
  endcase
 end
 always @(posedge dclk) begin
  cycle<=cycle+1;
  #1; frame_start=($urandom%300==0);
  if(cycle==3) reset_request=0;
  if(cycle>100 && $urandom%200000==0) begin reset_request=1; resets=resets+1; end
  else if(reset_request && cycle>3) reset_request=0;
 end
 initial begin
  wait(cycle==3000000);
  if(changes<500 || applies_same<100 || resets<3) $display("** Error: insufficient coverage changes=%0d same=%0d resets=%0d",changes,applies_same,resets);
  else if(errors) $display("** Error: %0d mismatches",errors);
  else $display("PASS batch7 subtitle commit equivalence cycles=%0d changes=%0d enable_only=%0d resets=%0d",cycle,changes,applies_same,resets);
  $finish;
 end
endmodule
