# S6 → S7 路径组时序对比

单位ns；约束与S6相同。

| 路径组 | S6 WNS | S7 WNS | S6违例端点 | S7违例端点 |
|---|---:|---:|---:|---:|
| sd_card_clk -> sd_card_clk | -0.387 | 0.189 | 3 | 0 |
| ext_mem_clk -> ext_mem_clk | -0.219 | 0.178 | 4 | 0 |
| video_clk -> video_clk | 25.367 | 26.444 | 0 | 0 |
| hdmi_5x_clk -> hdmi_5x_clk | 5.124 | 3.361 | 0 | 0 |
| clk -> clk | 14.141 | 11.968 | 0 | 0 |
| sd_card_clk -> video_clk | 6.218 | 5.284 | 0 | 0 |
| ext_mem_clk -> sd_card_clk | 0.587 | 0.849 | 0 | 0 |
| sd_card_clk -> ext_mem_clk | 0.725 | 0.707 | 0 | 0 |
| ext_mem_clk -> video_clk | 4.128 | 4.730 | 0 | 0 |
| sd_card_clk -> clk | 4.890 | 4.956 | 0 | 0 |
| video_clk -> ext_mem_clk | 5.519 | 5.448 | 0 | 0 |
| ext_mem_clk -> sys_pll_m0/pll_inst.clkc[2] | -2.868 | -2.969 | 32 | 32 |
| sys_pll_m0/pll_inst.clkc[2] -> ext_mem_clk | -6.699 | -6.699 | 32 | 32 |

新音频/视频像素域同域+26.444ns，计入跨域的video_clk汇总+4.730ns，没有新增负裕量路径组。S6控制域BMP解析3个违例及内存同域帧缓存4个违例在本轮布局中消失；这是此次构建结果，不代表修改过相应RTL。

剩余64个违例端点均在SDRAM接口：读侧U3/sdram.dq[0]→U3/sdram_syn_1.bpad为−6.699ns；写侧最差U3/u2_ram/u1_init_ref/ad_reg[1]→U3/sdram.dq[31]为−2.969ns，比S6的−2.868ns退化0.101ns。全局TNS−295.004ns，不能称为时序收敛或所有路径改善。

HDMI 5x同域+3.361ns，比S6+5.124ns减小但仍为正。原video_clk/hdmi_5x_clk exclusive关系继续沿用，故装载跨域的完整STA覆盖仍未解决，功能由厂商ODDR模型验证，不能代替电气验收。STA覆盖率92.37%，原IP/SDRAM位置及局部时钟布线警告仍在。
