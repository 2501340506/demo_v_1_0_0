`timescale 1ns/1ps
// v0.24 board-failure triage: production sd_card_bmp at 100 MHz with the real
// sd_card_top SPI driver (nothing forced). A pin-level SPI card answers the
// init sequence and serves selector fixture sectors with CRC16, so boot runs
// SD init, the FAT32 scan and header preflight exactly as on the board.
module sd_fixture_card(input cs,sclk,mosi,output reg miso=1);
 reg [7:0] rx=0,packet[0:5],response[0:1023];
 integer bit_count=0,packet_count=0,rp=0,wp=0,k,slot;
 integer commands=0,reads=0,unknown_reads=0,cmd59=0,attempts=0;
 reg idle=1,app=0,crc_enabled=0;
 reg [15:0] crc;
 reg [7:0] value;
 reg [31:0] lba;
 task push(input [7:0] b);begin response[wp]=b;wp=wp+1;end endtask
 function [15:0] crc16(input [15:0] c,input [7:0] d);
  integer i;reg [15:0] r;
  begin r=c^{d,8'h00};for(i=0;i<8;i=i+1)r=r[15]?{r[14:0],1'b0}^16'h1021:{r[14:0],1'b0};crc16=r;end
 endfunction
 always @(posedge cs)begin bit_count=0;packet_count=0;rp=0;wp=0;miso=1;end
 always @(negedge sclk)begin
  if(!cs && rp<wp)miso=response[rp][7-bit_count];else miso=1;
 end
 always @(posedge sclk)if(!cs)begin
  rx={rx[6:0],mosi};
  if(bit_count==7)begin
   bit_count=0;
   if(rp<wp)rp=rp+1;
   if(packet_count!=0 || rx[7:6]==2'b01)begin
    packet[packet_count]=rx;
    if(packet_count==5)begin
     packet_count=0;commands=commands+1;rp=0;wp=0;
     push(8'hff);
     case(packet[0]&63)
      0:begin idle=1;app=0;attempts=0;crc_enabled=0;push(1);end
      8:begin push(idle?1:0);push(0);push(0);push(1);push(8'haa);end
      55:begin app=1;push(idle?1:0);end
      41:begin app=0;attempts=attempts+1;if(attempts>=2)idle=0;push(idle?1:0);end
      16:push(0);
      59:begin cmd59=cmd59+1;crc_enabled=1;push(0);end
      17:begin
       lba={packet[1],packet[2],packet[3],packet[4]};reads=reads+1;
       slot=tb_sd_pin_boot.sector_slot.exists(lba)?tb_sd_pin_boot.sector_slot[lba]:-1;
       if(slot<0)unknown_reads=unknown_reads+1;
       push(0);push(8'hff);push(8'hfe);crc=0;
       for(k=0;k<512;k=k+1)begin
        value=slot<0?8'h00:tb_sd_pin_boot.disk[slot*512+k];push(value);crc=crc16(crc,value);
       end
       push(crc[15:8]);push(crc[7:0]);
      end
      default:push(8'h04);
     endcase
    end else packet_count=packet_count+1;
   end
  end else bit_count=bit_count+1;
 end
endmodule

module tb_sd_pin_boot;
 parameter integer CASE_ID=0;
 parameter integer RUN_NS=60000000;
 reg clk=0,pix=0,rst=1;always #5 clk=~clk;always #20 pix=~pix;
 reg [31:0] meta[0:2],lbas[0:32767];reg [7:0] disk[0:16777215];
 integer sector_slot[int unsigned];
 wire sd_ncs,sd_dclk,sd_mosi,sd_miso;
 sd_fixture_card card(.cs(sd_ncs),.sclk(sd_dclk),.mosi(sd_mosi),.miso(sd_miso));
 reg write_ack=0;wire write_req;
 always @(posedge clk)write_ack<=write_req;
 wire [3:0] state_code;wire [63:0] sd_debug;wire [7:0] osd_error;wire application_error;
 sd_card_bmp #(.MENU_ENABLE(1),.CLK_FREQ_HZ(100_000_000),.SCAN_START_SECTOR(32'd0),.SCAN_MAX_SECTOR(32'd131071),
  .SCAN_TARGET_COUNT(3'd4),.SCALE_ENABLE(1),.PREVIEW_ENABLE(1),.AUDIO_ENABLE(1),.USE_FRAME_RESULT(1),
  .TRANSITION_ENABLE(1),.SCENE_ENABLE(1),.PUBLICITY_ENABLE(1)) dut(
  .clk(clk),.rst(rst),.sdram_ready(1'b1),.key1(1'b1),.key2(1'b1),.key4(1'b1),.mode(2'd0),.sw3(1'b0),
  .menu_display_off(1'b1),.bgm_ready(1'b1),.scenario_muted(1'b1),
  .bmp_width(16'd640),.bmp_height(16'd480),.committed_ready(1'b1),.write_cancel_ack(1'b0),
  .frame_error_toggle(1'b0),.frame_memory_error(3'd0),.reader_error(3'd0),.reader_underflow(1'b0),
  .write_finish_toggle(1'b0),.display_commit_ack(1'b0),.preview_ack(1'b0),
  .transition_pix_clk(pix),.transition_pix_rst(rst),.transition_frame_start(1'b0),.transition_commit_done(1'b0),
  .write_req(write_req),.write_req_ack(write_ack),.write_ready(1'b1),
  .state_code(state_code),.sd_debug(sd_debug),.osd_error_code(osd_error),.application_error(application_error),
  .SD_nCS(sd_ncs),.SD_DCLK(sd_dclk),.SD_MOSI(sd_mosi),.SD_MISO(sd_miso));
 reg init_seen=0,scan_seen=0;integer q;string prefix;
 always @(posedge clk)if(!rst)begin
  if(dut.sd_init_done && !init_seen)begin init_seen=1;$display("SD init done t=%0t commands=%0d cmd59=%0d",$time,card.commands,card.cmd59);end
  if(dut.sd_init_failed && !init_seen)begin init_seen=1;$display("SD init FAILED t=%0t commands=%0d",$time,card.commands);end
  if(dut.scan_result_valid && !scan_seen)begin
   scan_seen=1;
   $display("SCAN RESULT t=%0t success=%0d images=%0d reads=%0d unknown=%0d fat_error=%h bmp_error=%0d",
    $time,dut.scan_success,dut.img_found_count,card.reads,card.unknown_reads,dut.bmp_read_m0.fat_error,dut.bmp_read_m0.bmp_error);
  end
 end
 initial begin
  prefix=$sformatf("selector%0d_",CASE_ID);
  $readmemh({prefix,"meta.hex"},meta,0,2);$readmemh({prefix,"lba.hex"},lbas,0,meta[0]-1);
  $readmemh({prefix,"bytes.hex"},disk,0,meta[0]*512-1);
  for(q=0;q<meta[0];q++)sector_slot[lbas[q]]=q;
  repeat(10)@(posedge clk);rst=0;
  #(RUN_NS);
  $display("FINAL t=%0t init_done=%0d init_failed=%0d scan_seen=%0d success=%0d state_code=%h osd=%h app_error=%0d reads=%0d unknown=%0d sd_debug=%h",
   $time,dut.sd_init_done,dut.sd_init_failed,scan_seen,dut.scan_success,state_code,osd_error,application_error,card.reads,card.unknown_reads,sd_debug);
  if(scan_seen && dut.scan_success && card.reads>0)$display("PASS sd pin boot");else $display("FAIL sd pin boot");
  $finish;
 end
endmodule
