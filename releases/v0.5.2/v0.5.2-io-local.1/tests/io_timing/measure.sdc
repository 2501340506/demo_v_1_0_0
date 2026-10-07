set_max_delay -from [get_clocks hdmi_5x_clk] -to [get_ports {HDMI_CLK_P HDMI_D0_P HDMI_D1_P HDMI_D2_P}] 4 -datapath_only
set_max_delay -from [get_clocks sd_card_clk] -to [get_ports {sd_dclk sd_mosi sd_ncs}] 10 -datapath_only
set_max_delay -from [get_ports sd_miso] -to [get_clocks sd_card_clk] 10 -datapath_only
set_input_delay -clock sd_card_clk -max 0 [get_ports sd_miso]
set_input_delay -clock sd_card_clk -min 0 [get_ports sd_miso]
set_output_delay -clock sd_card_clk -max 0 [get_ports {sd_dclk sd_mosi sd_ncs}]
set_output_delay -clock sd_card_clk -min 0 [get_ports {sd_dclk sd_mosi sd_ncs}]
set_output_delay -clock hdmi_5x_clk -max 0 [get_ports {HDMI_CLK_P HDMI_D0_P HDMI_D1_P HDMI_D2_P}]
set_output_delay -clock hdmi_5x_clk -min 0 [get_ports {HDMI_CLK_P HDMI_D0_P HDMI_D1_P HDMI_D2_P}]
