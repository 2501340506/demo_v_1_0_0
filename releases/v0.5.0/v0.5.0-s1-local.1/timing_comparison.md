# S1最终构建与v0.4.0对比

TD6.2.168116，flash_boot_s1_local5。ADC/SDC不变，物理布局hfn_opt_effort=high。

| 指标 | v0.4.0 | S1候选 |
|---|---:|---:|
| 全局Setup WNS / TNS (ns) | −6.565 / −294.297 | −6.565 / −250.840 |
| 全局Hold WNS (ns) | +0.004 | +0.004 |
| LUT / 寄存器 | 3944 / 2890 | 3951 / 2900 |
| BRAM / DSP / PLL | 4 / 4 / 2 | 4 / 4 / 2 |

| 路径组 | 原Setup(ns) | 当前Setup(ns) | 当前负端点 |
|---|---:|---:|---:|
| sd_card_clk -> sd_card_clk | +0.133 | +0.147 | 0 |
| video_clk -> video_clk | +25.556 | +25.546 | 0 |
| ext_mem_clk -> ext_mem_clk | +0.021 | +0.266 | 0 |
| hdmi_5x_clk -> hdmi_5x_clk | +3.201 | +3.003 | 0 |
| clk -> clk | +13.156 | +13.150 | 0 |
| video_clk -> hdmi_5x_clk | +6.265 | +6.222 | 0 |
| sd_card_clk -> video_clk | +6.719 | +7.041 | 0 |
| ext_mem_clk -> sd_card_clk | +0.587 | +0.587 | 0 |
| sd_card_clk -> ext_mem_clk | +0.714 | +0.725 | 0 |
| ext_mem_clk -> video_clk | +5.738 | +6.033 | 0 |
| sd_card_clk -> clk | +4.258 | +5.948 | 0 |
| video_clk -> ext_mem_clk | +6.108 | +6.590 | 0 |
| video_clk -> sd_card_clk | +9.144 | +8.835 | 0 |
| ext_mem_clk -> sys_pll_m0/pll_inst.clkc[2] | -2.920 | -1.439 | 32 |
| sys_pll_m0/pll_inst.clkc[2] -> ext_mem_clk | -6.565 | -6.565 | 32 |

首次默认布局出现2个SD复位recovery负端点，−0.273ns，扇出690。最终高扇出布局优化消除这2个端点，内部同域及已列跨域均为正。原SDRAM读/写接口仍各32个负端点，共64个；全局未收敛。没有更改SDC、放宽不确定性或新增false_path。

同样保留既有编译顺序重复、硬SDRAM位置调整和一条时钟采用局部布线等TD警告类型；本次不宣称TD零警告。RTL属性尝试均已撤回，诊断过程见diagnostics/flash_boot/evidence。板级IO delay仍未完整定义。
