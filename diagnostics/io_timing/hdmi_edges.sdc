# Measurement-only companion. Replaces the production datapath-only limit
# with loose absolute checks to expose BOTH slow/max and fast/min pad paths.
# Never used for synthesis, placement, or candidate acceptance limits.
set_output_delay -clock hdmi_5x_clk -max 0 [get_ports {HDMI_CLK_P HDMI_D0_P HDMI_D1_P HDMI_D2_P}]
set_output_delay -clock hdmi_5x_clk -min 0 [get_ports {HDMI_CLK_P HDMI_D0_P HDMI_D1_P HDMI_D2_P}]
set_max_delay -from [get_clocks hdmi_5x_clk] -to [get_ports {HDMI_CLK_P HDMI_D0_P HDMI_D1_P HDMI_D2_P}] 20
set_min_delay -from [get_clocks hdmi_5x_clk] -to [get_ports {HDMI_CLK_P HDMI_D0_P HDMI_D1_P HDMI_D2_P}] 0
