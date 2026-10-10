`timescale 1ns/1ps
// Real top, SD player and parser. PLL/FIFO/SDRAM models reused from S1.
// Only initialization completion levels are controlled; scan logic is real.
module tb_startup;
 reg clk=0, rst_n=0, mem_ready=0, card_ready=0;
 always #10 clk=~clk;
 wire [5:0] sel; wire [7:0] seg;
 wire pc,p0,p1,p2,ncs,dclk,mosi;
 tri scl,sda;
 top dut(.clk(clk),.rst_n(rst_n),.key1(1'b1),.key2(1'b1),.key4(1'b1),
  .sw1(1'b0),.sw2(1'b0),.seg_sel(sel),.seg_data(seg),.HDMI_CLK_P(pc),
  .HDMI_D0_P(p0),.HDMI_D1_P(p1),.HDMI_D2_P(p2),.HDMI_DDC_SCL(scl),.HDMI_DDC_SDA(sda),
  .sd_ncs(ncs),.sd_dclk(dclk),.sd_mosi(mosi),.sd_miso(1'b1)
`ifndef PRE_UART_TOP
  ,.uart_tx(),.uart_rx(1'b1)
`endif
  );
 integer scans=0, scenarios=0;
 wire scan_kicked=(dut.sd_card_bmp_m0.scan_state==3 || dut.sd_card_bmp_m0.scan_state==4);
 reg sampled_ready=0, expected_ready=0;
 always @(posedge dut.sd_card_clk or posedge dut.rst_sd) begin
  if(dut.rst_sd) begin sampled_ready<=0;expected_ready<=0;end
  else begin sampled_ready<=mem_ready;expected_ready<=sampled_ready;end
 end
 always @(negedge dut.sd_card_clk) begin
  if(dut.rst_sd) scans=0;
  else begin
   if(dut.sdram_ready_sync[1] !== expected_ready) $fatal(1,"readiness is not delayed by two SD edges");
   if(dut.sd_card_bmp_m0.scan_start_pulse) begin
    scans=scans+1;
    if(!expected_ready || !card_ready) $fatal(1,"scan before both initialization completions");
   end
   if(!expected_ready && (scan_kicked || dut.sd_card_write_req ||
      dut.sd_card_write_en || dut.display_valid || dut.committed_valid || dut.audio_enable))
    $fatal(1,"business activity before memory readiness");
   if(scans>1) $fatal(1,"duplicate startup scan");
  end
 end
 task boot;
  begin
   rst_n=0;mem_ready=0;card_ready=0;
   #91.3;rst_n=1;
   wait(!dut.rst_sd && !dut.rst_mem);
   repeat(5) @(negedge dut.sd_card_clk);
  end
 endtask
 task idle_check;
  begin
   repeat(15) @(negedge dut.sd_card_clk);
   if(scans!=0 || scan_kicked) $fatal(1,"scan occurred while waiting");
   if(dut.sd_card_bmp_m0.rst) $fatal(1,"memory readiness reset SD initialization");
  end
 endtask
 task started_once;
  begin
   repeat(25) @(negedge dut.sd_card_clk);
   if(scans!=1 || !scan_kicked) $fatal(1,"missing startup scan");
   repeat(50) @(negedge dut.sd_card_clk);
   if(scans!=1) $fatal(1,"startup scan repeated");
   scenarios=scenarios+1;
  end
 endtask
 initial begin
  force dut.Sdr_init_done=mem_ready;
  force dut.sd_card_bmp_m0.sd_init_done=card_ready;
  // Negative control bypasses only the new gate, retaining the real CDC.
  if($test$plusargs("BYPASS_READY")) force dut.sd_card_bmp_m0.sdram_ready=1'b1;
  // Memory completion follows memory clock; SD completion follows SD clock.
  boot();card_ready=1;idle_check();
  @(negedge dut.ext_mem_clk);mem_ready=1;started_once();
  boot();@(negedge dut.ext_mem_clk);mem_ready=1;idle_check();
  card_ready=1;started_once();
  boot();@(negedge dut.ext_mem_clk);mem_ready=1;#0.7;card_ready=1;started_once();
  // Reset while TF is ready but memory has not completed initialization.
  boot();card_ready=1;idle_check();
  boot();idle_check();card_ready=1;
  @(negedge dut.ext_mem_clk);mem_ready=1;started_once();
  if(scenarios!=4) $fatal(1,"startup coverage incomplete");
  $display("PASS FLASH S2: TF-first, memory-first, near-simultaneous, reset while waiting; two-edge CDC and exactly one scan");
  $finish;
 end
 initial begin #200000;$fatal(1,"startup timeout");end
endmodule
