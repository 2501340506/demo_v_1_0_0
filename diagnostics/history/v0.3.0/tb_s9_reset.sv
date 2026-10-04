`timescale 1ns/1ps
// Actual board top. Only PLL clocks/locks, memory controller and FIFO storage
// are modeled. The real SD/control, PCM, bridge and vendor ODDR remain active.
module tb_s9_reset;
 reg clk=0,rst_n=0;
 always #10 clk=~clk;
 wire [5:0] sel;wire [7:0] seg;
 wire p0,p1,p2,pc,ncs,dclk,mosi;
 tri scl,sda;
 top dut(.clk(clk),.rst_n(rst_n),.key1(1'b1),.key2(1'b1),.key4(1'b1),
 .sw1(1'b0),.sw2(1'b0),.seg_sel(sel),.seg_data(seg),.HDMI_CLK_P(pc),
 .HDMI_D0_P(p0),.HDMI_D1_P(p1),.HDMI_D2_P(p2),.HDMI_DDC_SCL(scl),.HDMI_DDC_SDA(sda),
 .sd_ncs(ncs),.sd_dclk(dclk),.sd_mosi(mosi),.sd_miso(1'b1));
 reset_observer p(.clk(clk),.request(dut.reset_request),.rst(dut.rst_panel));
 reset_observer s(.clk(dut.sd_card_clk),.request(dut.reset_request),.rst(dut.rst_sd));
 reset_observer m(.clk(dut.ext_mem_clk),.request(dut.reset_request),.rst(dut.rst_mem));
 reset_observer v(.clk(dut.video_clk),.request(dut.reset_request),.rst(dut.rst_video));
 reset_observer h(.clk(dut.hdmi_5x_clk),.request(dut.reset_request),.rst(dut.rst_serial));
 reg inject_valid=0;reg [1:0] inject_id=0;
 integer updates=0,samples=0,rounds=0;
 always @(posedge dut.video_clk) begin
  if(dut.rst_video) begin updates=0;samples=0;end
  else begin
   if(dut.audio_update) updates=updates+1;
   if(dut.u_media_hdmi_audio_bridge.pcm_tap_valid) begin
    samples=samples+1;
    if(!dut.audio_enable && (dut.pcm_left!==0 || dut.pcm_right!==0)) $fatal(1,"not silent after restart");
   end
   if(dut.pcm_overflow || dut.hdmi_sequence_error) $fatal(1,"PCM/packet restart failure");
  end
 end
 task released;
  begin
   wait(!dut.rst_panel && !dut.rst_sd && !dut.rst_mem && !dut.rst_video && !dut.rst_serial);
   #1;
   if(dut.audio_enable || dut.display_valid || dut.u_media_commit_cdc.request || dut.frame_write_toggle_mem)
    $fatal(1,"stale image/event after reset");
   repeat(6000) @(negedge dut.video_clk);
   if(samples<8 || updates!=0) $fatal(1,"silence stream or phantom update");
   @(negedge dut.sd_card_clk);inject_id=rounds%4;inject_valid=1;
   do @(posedge dut.sd_card_clk);while(!dut.committed_ready);
   @(negedge dut.sd_card_clk);inject_valid=0;
   repeat(50) @(negedge dut.video_clk);
   if(updates!=1 || !dut.audio_enable || dut.audio_image!==inject_id || !dut.u_pcm_clock.blip_active)
    $fatal(1,"first commit not delivered once after reset");
   repeat(10000) @(negedge dut.video_clk);
   if(scl!==1'bz || sda!==1'bz) $fatal(1,"DDC driven");
   rounds=rounds+1;
  end
 endtask
 initial begin
  force dut.committed_valid=inject_valid;
  force dut.committed_image=inject_id;
  #73.3;rst_n=1;
  // Both lock orders, lock loss with stopped destination clock, and buttons.
  #17;dut.sys_pll_m0.lock_state=1;
  #101;if(!dut.rst_video || !dut.rst_sd) $fatal(1,"released before both PLLs locked");
  dut.video_pll_m0.lock_state=1;released();
  #3;dut.video_pll_m0.lock_state=0;dut.video_pll_m0.running=0;
  #57;if(!dut.rst_video || !dut.rst_serial || !dut.rst_sd) $fatal(1,"loss of lock did not assert reset");
  dut.sys_pll_m0.lock_state=0;dut.video_pll_m0.lock_state=1;
  #83;dut.video_pll_m0.running=1;
  #51;if(!dut.rst_mem) $fatal(1,"video lock alone released memory");
  dut.sys_pll_m0.lock_state=1;released();
  #7;dut.sys_pll_m0.lock_state=0;#67.3;dut.sys_pll_m0.lock_state=1;released();
  #3;rst_n=0;#53.3;rst_n=1;released();
  // Reset while a source commit is waiting to cross to the pixel domain.
  @(negedge dut.sd_card_clk);inject_valid=1;
  @(posedge dut.sd_card_clk);#1;inject_valid=0;rst_n=0;
  #73.3;rst_n=1;released();
  if(rounds!=5) $fatal(1,"reset coverage incomplete");
  $display("PASS S9 actual top: five boot/reset/lock-loss recoveries, per-domain release, silent restart, fresh first cue, DDC high-Z");
  $finish;
 end
 initial begin #10000000;$fatal(1,"reset test timeout");end
endmodule
module reset_observer(input clk,request,rst);
 integer edges=0;
 always @(posedge clk or posedge request) begin
  if(request) edges=0;else if(edges<3) edges=edges+1;
  #0.1;
  if(rst !== (edges<3)) $fatal(1,"reset mismatch edges=%0d rst=%b request=%b at %t",edges,rst,request,$time);
 end
 always @(negedge rst) if(!clk) $fatal(1,"reset released off local rising edge");
endmodule
// PLL models intentionally expose separate lock controls; no real PLL lock
// acquisition duration or analog behavior is claimed by this test.
module sys_pll(input refclk,reset,output reg clk0_out=0,clk1_out=0,
 output clk2_out,output locked);
 reg lock_state=0;
 always #5 clk0_out=~clk0_out;
 always #4 clk1_out=~clk1_out;
 assign clk2_out=~clk1_out;assign locked=lock_state && !reset;
endmodule
module video_pll(input refclk,reset,output reg clk0_out=0,clk1_out=0,output locked);
 reg lock_state=0,running=1;
 always #20 if(running) clk0_out=~clk0_out;
 initial begin #1;forever #4 if(running) clk1_out=~clk1_out;end
 assign locked=lock_state && !reset;
endmodule
module sdram(input Clk,Clk_sft,Rst,output Sdr_init_done,Sdr_init_ref_vld,Sdr_busy,
 input App_wr_en,input [20:0] App_wr_addr,input [3:0] App_wr_dm,input [31:0] App_wr_din,
 input App_rd_en,input [20:0] App_rd_addr,output reg Sdr_rd_en=0,output [31:0] Sdr_rd_dout);
 assign Sdr_init_done=!Rst;assign Sdr_init_ref_vld=0;assign Sdr_busy=0;assign Sdr_rd_dout=0;
 always @(posedge Clk) Sdr_rd_en<=!Rst && App_rd_en;
endmodule
module rfifo_32_32_512(input clkr,clkw,rst,we,re,input [31:0] di,
 output empty_flag,full_flag,output [8:0] wrusedw,rdusedw,output [31:0] dout);
 assign empty_flag=0;assign full_flag=0;assign wrusedw=0;assign rdusedw=0;assign dout=0;
endmodule
module wfifo_32_32_512(input clkr,clkw,rst,we,re,input [31:0] di,
 output empty_flag,full_flag,output [8:0] wrusedw,rdusedw,output [31:0] dout);
 assign empty_flag=1;assign full_flag=0;assign wrusedw=0;assign rdusedw=0;assign dout=0;
endmodule
