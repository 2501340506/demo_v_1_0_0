// Actual serial RX + controller + frame mailbox alongside real SDRAM playback.
reg sub_rx_pin=1;
wire [7:0] sub_byte;
wire sub_valid,sub_error;
wire [119:0] sub_config,runtime_text;
wire [3:0] sub_size,runtime_length;
wire sub_enabled,runtime_enable,runtime_changed,sub_frame;
uart_rx_byte #(.CLKS_PER_BIT(868)) sub_receiver(.clk(src_clk),.rst_n(!rst),.rx(sub_rx_pin),
 .data(sub_byte),.valid(sub_valid),.framing_error(sub_error));
subtitle_uart_controller sub_control(.clk(src_clk),.rst(rst),.rx_data(sub_byte),.rx_valid(sub_valid),
 .rx_framing_error(sub_error),.cfg_text(sub_config),.cfg_length(sub_size),.cfg_enable(sub_enabled),
 .cfg_update_valid(),.reply_valid(),.reply_data(),.reply_last(),.reply_ready(1'b1));
osd_pixel_position sub_pos(.clk(pix_clk),.rst(rst),.vs(vs),.de(de),.line_y(),.frame_start(sub_frame),.first_active());
subtitle_frame_commit sub_mailbox(.src_clk(src_clk),.src_rst(rst),.src_text(sub_config),
 .src_length(sub_size),.src_enable(sub_enabled),.dst_clk(pix_clk),.dst_rst(rst),.frame_start(sub_frame),
 .dst_text(runtime_text),.dst_length(runtime_length),.dst_enable(runtime_enable),.text_changed(runtime_changed));
task sub_send(input string cmd);
 integer i,k;
 begin
  for(i=0;i<cmd.len();i=i+1)begin
   @(negedge src_clk);sub_rx_pin=0;repeat(868)@(negedge src_clk);
   for(k=0;k<8;k=k+1)begin sub_rx_pin=(cmd[i]>>k)&1;repeat(868)@(negedge src_clk);end
   sub_rx_pin=1;repeat(868)@(negedge src_clk);
  end
 end
endtask
integer sub_stages=0;
initial begin
 wait(!rst);wait(osd_frames>=4);sub_send("SUB=AB\n");
 wait(runtime_length==2 && runtime_text[15:0]==16'h4241);sub_stages=1;
 wait(osd_frames>=12);sub_send("SUB=OFF\n");wait(!runtime_enable);sub_stages=2;
 wait(osd_frames>=16);sub_send("SUB=CN\n");wait(runtime_length==9);sub_stages=3;
 sub_send("SUB=ON\n");wait(runtime_enable);sub_stages=4;
end
reg [124:0] subtitle_previous;
reg subtitle_frame_sample;
always @(posedge pix_clk)begin
 subtitle_previous={runtime_enable,runtime_length,runtime_text};subtitle_frame_sample=sub_frame;
 #1;if(!rst && !subtitle_frame_sample && subtitle_previous!=={runtime_enable,runtime_length,runtime_text})
  $fatal(1,"system runtime subtitle tore within frame");
end
final begin
 if(sub_stages!=4)$error("system UART stimulus did not finish: %0d",sub_stages);
 $display("UART system observations: %0d serial command stages applied at frame boundaries",sub_stages);
end
