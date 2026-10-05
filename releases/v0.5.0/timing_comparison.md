# S2与已验收S1时序对比

最终构建flash_boot_s2_local4；hfn_opt_effort high、opt_timing ultra、post_place_opt high。SDC/ADC不变。

| 指标 | S1 | S2 |
|---|---:|---:|
| Setup WNS / TNS(ns) | −6.565 / −250.840 | −6.565 / −251.158 |
| Hold WNS(ns) | +0.004 | +0.003 |
| LUT / 寄存器 | 3951 / 2900 | 3926 / 2902 |
| BRAM / DSP / PLL | 4 / 4 / 2 | 4 / 4 / 2 |

| 路径组 | S1 Setup(ns) | S2 Setup(ns) | S2负端点 |
|---|---:|---:|---:|
| sd_card_clk -> sd_card_clk | +0.147 | +0.170 | 0 |
| video_clk -> video_clk | +25.546 | +26.731 | 0 |
| ext_mem_clk -> ext_mem_clk | +0.266 | -0.084 | 3 |
| hdmi_5x_clk -> hdmi_5x_clk | +3.003 | +1.815 | 0 |
| clk -> clk | +13.150 | +11.967 | 0 |
| video_clk -> hdmi_5x_clk | +6.222 | +5.900 | 0 |
| sd_card_clk -> video_clk | +7.041 | +6.128 | 0 |
| ext_mem_clk -> sd_card_clk | +0.587 | +0.725 | 0 |
| sd_card_clk -> ext_mem_clk | +0.725 | +0.710 | 0 |
| ext_mem_clk -> video_clk | +6.033 | +5.543 | 0 |
| sd_card_clk -> clk | +5.948 | +5.395 | 0 |
| video_clk -> ext_mem_clk | +6.590 | +6.501 | 0 |
| video_clk -> sd_card_clk | +8.835 | +8.784 | 0 |
| ext_mem_clk -> sys_pll_m0/pll_inst.clkc[2] | -1.439 | -1.439 | 32 |
| sys_pll_m0/pll_inst.clkc[2] -> ext_mem_clk | -6.565 | -6.565 | 32 |

S2新增就绪同步和扫描启动控制未出现在负端点；内存→SD组包含新增同步输入且为正。保留原64个SDRAM接口负端点，另外原frame_fifo_read同域路径本轮退化为3个负端点（最差−0.084ns），总67个，未全局收敛。该旧路径未改RTL；按本版本时序审查范围如实保留，不扩大整改、不放宽约束。

首次沿用S1参数时SD有3个−0.071ns负端点；opt_timing high仍有SD/内存负端点；ultra消除SD违例，post_place_opt high未进一步改善内存。报告保存在diagnostics/flash_boot/evidence/s2_build1至s2_build3，最终构建原始报告随本候选保存。

TD仍有历史重复CompileOrder、SDRAM硬实例位置调整和局部布线时钟警告类型。板级IO delay未完整定义，ModelSim及上板成功不能证明全局时序收敛。
