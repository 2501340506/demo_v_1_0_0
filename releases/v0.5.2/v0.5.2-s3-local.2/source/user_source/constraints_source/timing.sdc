# S3: one PLL, five generated clocks; no audio PLL / I2S clock domain.
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]
# Explicit ratios avoid TD derive_clocks rounding the C2 phase to 173 degrees.
create_generated_clock -name sd_card_clk -source [get_ports {clk}] -multiply_by 2 [get_pins {sys_pll_m0/pll_inst.clkc[0]}]
create_generated_clock -name ext_mem_clk -source [get_ports {clk}] -divide_by 1.25 [get_pins {sys_pll_m0/pll_inst.clkc[1]}]
create_generated_clock -name ext_mem_clk_sft -source [get_ports {clk}] -divide_by 1.25 -phase 172.8 [get_pins {sys_pll_m0/pll_inst.clkc[2]}]
create_generated_clock -name video_clk -source [get_ports {clk}] -divide_by 2 [get_pins {sys_pll_m0/pll_inst.clkc[3]}]
create_generated_clock -name hdmi_5x_clk -source [get_ports {clk}] -multiply_by 2.5 [get_pins {sys_pll_m0/pll_inst.clkc[4]}]

# Pixel and serial clocks run concurrently from the same PLL.
# Remove the legacy exclusive group so the serializer crossings are analyzed.
# Reset release is synchronized in each local domain; no new timing exceptions.
# Board I/O delay constraints remain unspecified as in the accepted baseline.
