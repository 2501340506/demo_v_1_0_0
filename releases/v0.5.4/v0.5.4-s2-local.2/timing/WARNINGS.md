# TD warning comparison

Old IDs: PHY-5079, PHY-7002, SYN-5011, SYN-5013, SYN-5025, SYN-6562, SYN-6577
New IDs: PHY-5079, PHY-7002, SYN-5011, SYN-5013, SYN-5025, SYN-6562, SYN-6577
Added IDs: none

Current warning messages (including existing PLL/SDRAM warnings):
PHY-5079 CRITICAL-WARNING: Marked 1 clock net(s) utilize the local routing resources. Please check log message and the sinks of clock nets.
PHY-7002 CRITICAL-WARNING: Instance U3/sdram location (12, 12) is not honored. Cell's initial location is not legal at the beginning of ECO placement, and will be moved during placement. Please verify user location constraints through the adc file.
PHY-7002 CRITICAL-WARNING: Instance U3/sdram location (164, 288) is not honored. Cell's initial location is not legal at the beginning of ECO placement, and will be moved during placement. Please verify user location constraints through the adc file.
SYN-5011 WARNING: Undriven pin: model "top" / inst "U3/u2_ram/u2_wrrd/Sdr_rd_dout_reg[0]" in ../../../user_source/hdl_source/include/sdr_wrrd.enc.v(0) / pin "clk"
SYN-5011 WARNING: Undriven pin: model "top" / inst "U3/u2_ram/u2_wrrd/Sdr_rd_dout_reg[1]" in ../../../user_source/hdl_source/include/sdr_wrrd.enc.v(0) / pin "clk"
SYN-5011 WARNING: Undriven pin: model "top" / inst "U3/u2_ram/u2_wrrd/Sdr_rd_dout_reg[2]" in ../../../user_source/hdl_source/include/sdr_wrrd.enc.v(0) / pin "clk"
SYN-5011 WARNING: Undriven pin: model "top" / inst "U3/u2_ram/u2_wrrd/Sdr_rd_dout_reg[3]" in ../../../user_source/hdl_source/include/sdr_wrrd.enc.v(0) / pin "clk"
SYN-5011 WARNING: Undriven pin: model "top" / inst "U3/u2_ram/u2_wrrd/Sdr_rd_dout_reg[4]" in ../../../user_source/hdl_source/include/sdr_wrrd.enc.v(0) / pin "clk"
SYN-5011 WARNING: Undriven pin: model "top" / inst "U3/u2_ram/u2_wrrd/Sdr_rd_dout_reg[5]" in ../../../user_source/hdl_source/include/sdr_wrrd.enc.v(0) / pin "clk"
SYN-5011 WARNING: Undriven pin: model "top" / inst "U3/u2_ram/u2_wrrd/Sdr_rd_dout_reg[6]" in ../../../user_source/hdl_source/include/sdr_wrrd.enc.v(0) / pin "clk"
SYN-5011 WARNING: Undriven pin: model "top" / inst "U3/u2_ram/u2_wrrd/Sdr_rd_dout_reg[7]" in ../../../user_source/hdl_source/include/sdr_wrrd.enc.v(0) / pin "clk"
SYN-5011 WARNING: Undriven pin: model "top" / inst "U3/u2_ram/u2_wrrd/Sdr_rd_dout_reg[8]" in ../../../user_source/hdl_source/include/sdr_wrrd.enc.v(0) / pin "clk"
SYN-5011 WARNING: Undriven pin: model "top" / inst "U3/u2_ram/u2_wrrd/Sdr_rd_dout_reg[9]" in ../../../user_source/hdl_source/include/sdr_wrrd.enc.v(0) / pin "clk"
SYN-5011 WARNING: Undriven pin: model "top" / inst "frame_read_write_m0/read_buf/ram_inst/ramread0_syn_4" in ../../../user_source/hdl_source/IP/afifo_32_16_256.v(822) / pin "bea[0]"
SYN-5011 WARNING: Undriven pin: model "top" / inst "frame_read_write_m0/read_buf/ram_inst/ramread0_syn_4" in ../../../user_source/hdl_source/IP/afifo_32_16_256.v(822) / pin "beb[0]"
SYN-5013 WARNING: Undriven net: model "top" / net "U3/u2_ram/u2_wrrd/Sdr_init_ref_ba[0]" in ../../../user_source/hdl_source/include/sdr_wrrd.enc.v(0)
SYN-5013 WARNING: Undriven net: model "top" / net "U3/u2_ram/u2_wrrd/Sdr_init_ref_ba[1]" in ../../../user_source/hdl_source/include/sdr_wrrd.enc.v(0)
SYN-5013 WARNING: Undriven net: model "top" / net "sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/block_write_data[0]" in ../../../user_source/hdl_source/SD/sd_card_cmd.v(24)
SYN-5013 WARNING: Undriven net: model "top" / net "sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/block_write_data[1]" in ../../../user_source/hdl_source/SD/sd_card_cmd.v(24)
SYN-5013 WARNING: Undriven net: model "top" / net "sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/block_write_data[2]" in ../../../user_source/hdl_source/SD/sd_card_cmd.v(24)
SYN-5013 WARNING: Undriven net: model "top" / net "sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/block_write_data[3]" in ../../../user_source/hdl_source/SD/sd_card_cmd.v(24)
SYN-5013 WARNING: Undriven net: model "top" / net "sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/block_write_data[4]" in ../../../user_source/hdl_source/SD/sd_card_cmd.v(24)
SYN-5013 WARNING: Undriven net: model "top" / net "sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/block_write_data[5]" in ../../../user_source/hdl_source/SD/sd_card_cmd.v(24)
SYN-5013 WARNING: Undriven net: model "top" / net "sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/block_write_data[6]" in ../../../user_source/hdl_source/SD/sd_card_cmd.v(24)
SYN-5013 WARNING: Undriven net: model "top" / net "sd_card_bmp_m0/sd_card_top_m0/sd_card_cmd_m0/block_write_data[7]" in ../../../user_source/hdl_source/SD/sd_card_cmd.v(24)
SYN-5025 WARNING: Using 0 for all undriven pins and nets
SYN-6562 WARNING: The init value of "frame_read_write_m0/read_buf/ram_inst/ramread0_syn_4(../../../user_source/hdl_source/IP/afifo_32_16_256.v(822))" will be ignored since gate eram_init is set to off
SYN-6562 WARNING: The init value of "frame_read_write_m0/write_buf/ram_inst/ramread0_syn_4(../../../user_source/hdl_source/IP/afifo_16_32_256.v(822))" will be ignored since gate eram_init is set to off
SYN-6577 WARNING: The clock signal "U3/u2_ram/SDRAM_CLK" is added with the synthetic instruction (keep/mark_debug/dont_touch/max_fanout), which may create additional logic on this net
