# S4 → S6 路径组时序对比

单位ns，完整路径见demo_pr.timing。全局仍未收敛。

| 路径组 | S4 WNS | S6 WNS | S4违例端点 | S6违例端点 |
|---|---:|---:|---:|---:|
| video_clk -> video_clk | 27.772 | 25.367 | 0 | 0 |
| sd_card_clk -> sd_card_clk | 0.203 | -0.387 | 0 | 3 |
| ext_mem_clk -> ext_mem_clk | 0.149 | -0.219 | 0 | 4 |
| audio_mclk -> audio_mclk | 75.021 | — | 0 | — |
| hdmi_5x_clk -> hdmi_5x_clk | 5.326 | 5.124 | 0 | 0 |
| clk -> clk | 13.499 | 14.141 | 0 | 0 |
| sd_card_clk -> video_clk | 5.495 | 6.218 | 0 | 0 |
| ext_mem_clk -> sd_card_clk | 0.725 | 0.587 | 0 | 0 |
| sd_card_clk -> ext_mem_clk | 0.872 | 0.725 | 0 | 0 |
| ext_mem_clk -> video_clk | 4.282 | 4.128 | 0 | 0 |
| sd_card_clk -> clk | 5.886 | 4.890 | 0 | 0 |
| video_clk -> ext_mem_clk | 4.716 | 5.519 | 0 | 0 |
| ext_mem_clk -> sys_pll_m0/pll_inst.clkc[2] | -2.787 | -2.868 | 32 | 32 |
| sys_pll_m0/pll_inst.clkc[2] -> ext_mem_clk | -6.699 | -6.699 | 32 | 32 |

## 退化定位

- 控制域从+0.203变为−0.387，3个违例端点，TNS−0.517。最差为sd_card_bmp_m0/bmp_read_m0/file_len_reg[4]到bmp_read_m0/mux57_syn_275.a[0]；另两处到mux55及state_reg[0]。属于本次布局中的BMP解析路径退化，不能称作原SDRAM接口违例。
- 内存同域从+0.149变为−0.219，4个违例端点，TNS−0.662。最差由write_buf/wr_to_rd_cross_inst/secondary_addr_o_reg[0]到frame_fifo_read_m0/App_rd_en_r控制逻辑；另含rd_addr_b[7]及state_reg[2]。该类原帧缓存路径在S1曾有负裕量，S4通过，本次再次出现。
- 原SDRAM接口读侧−6.699、写侧−2.868，两组各32个违例端点；写侧较S4−2.787退化0.081。
- 新像素域同域无违例；统计含跨域后的video_clk WNS为+4.128。不得将这些结果概括为“时序无回退”。没有新增/放宽时序例外。

## 约束变化与覆盖限制

旧I2S/官方核数据输出失去消费者后，audio_mclk时钟被综合裁剪，但PLL锁定信号仍用于复位。初次构建发现rename_clock及异步组引用空时钟；本轮只移除这两处失效引用，最终没有空时钟组告警。初次报告保存在diagnostics/history/2026-10-04/audio_r2_s6_first_build。

原video_clk与hdmi_5x_clk的exclusive关系本轮沿用，因此本报告不证明两域串行装载路径的完整STA收敛；PHY功能由25/125MHz及厂商ODDR模型验证，后续约束清理阶段仍需处理。STA覆盖率由95.85%变为92.38%，电气输出/完整SDRAM时序不能由RTL仿真代替。

静音常量会裁剪部分PCM数据逻辑，资源和时序不能外推至S7非零样本接入后的构建。
