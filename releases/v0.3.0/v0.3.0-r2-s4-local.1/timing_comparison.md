# S1 → S4 路径组时序对比

单位ns；完整路径见demo_pr.timing，约束未修改。

| 路径组 | S1 WNS | S4 WNS | S1违例端点 | S4违例端点 |
|---|---:|---:|---:|---:|
| video_clk -> video_clk | 28.695 | 27.772 | 0 | 0 |
| sd_card_clk -> sd_card_clk | -0.044 | 0.203 | 1 | 0 |
| ext_mem_clk -> ext_mem_clk | -0.326 | 0.149 | 5 | 0 |
| audio_mclk -> audio_mclk | 74.343 | 75.021 | 0 | 0 |
| hdmi_5x_clk -> hdmi_5x_clk | 4.827 | 5.326 | 0 | 0 |
| clk -> clk | 14.138 | 13.499 | 0 | 0 |
| sd_card_clk -> video_clk | 5.198 | 5.495 | 0 | 0 |
| ext_mem_clk -> sd_card_clk | 0.587 | 0.725 | 0 | 0 |
| sd_card_clk -> ext_mem_clk | 0.714 | 0.872 | 0 | 0 |
| ext_mem_clk -> video_clk | 4.388 | 4.282 | 0 | 0 |
| sd_card_clk -> clk | 5.833 | 5.886 | 0 | 0 |
| video_clk -> ext_mem_clk | 5.655 | 4.716 | 0 | 0 |
| ext_mem_clk -> sys_pll_m0/pll_inst.clkc[2] | -2.811 | -2.787 | 32 | 32 |
| sys_pll_m0/pll_inst.clkc[2] -> ext_mem_clk | -6.699 | -6.699 | 32 | 32 |

本轮负裕量仅在两组SDRAM接口路径：写侧最差为U3/u2_ram/u2_wrrd/app_wr_addr_3d_reg[7]到U3/sdram.dq[31]，−2.787ns；读侧U3/sdram.dq[0]到U3/sdram_syn_1.bpad，−6.699ns。S1控制域BMP状态到load_sector使能的违例及内存域内部5个违例端点在本轮布局中不再出现；这是本次构建结果，不代表已修复底层SDRAM时序。视频域及跨域裕量有变化但保持为正。
