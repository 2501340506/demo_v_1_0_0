# S8 → S9 时序与资源对比

单位ns。本轮移除video_clk/hdmi_5x_clk互斥约束，对并行运行的相关时钟做实际STA；没有增加例外。

| 路径组 | S8 WNS | S9 WNS | S8违例端点 | S9违例端点 |
|---|---:|---:|---:|---:|
| sd_card_clk -> sd_card_clk | -0.550 | 0.149 | 3 | 0 |
| video_clk -> video_clk | 26.747 | 26.751 | 0 | 0 |
| ext_mem_clk -> ext_mem_clk | 0.122 | 0.173 | 0 | 0 |
| hdmi_5x_clk -> hdmi_5x_clk | 5.263 | 3.432 | 0 | 0 |
| clk -> clk | 12.853 | 13.474 | 0 | 0 |
| video_clk -> hdmi_5x_clk | 旧约束排除 | 6.376 | 未分析 | 0 |
| sd_card_clk -> video_clk | 5.692 | 7.543 | 0 | 0 |
| ext_mem_clk -> sd_card_clk | 0.725 | 0.735 | 0 | 0 |
| sd_card_clk -> ext_mem_clk | 0.834 | 0.688 | 0 | 0 |
| ext_mem_clk -> video_clk | 4.626 | 4.869 | 0 | 0 |
| sd_card_clk -> clk | 4.778 | 6.688 | 0 | 0 |
| video_clk -> ext_mem_clk | 5.503 | 6.872 | 0 | 0 |
| video_clk -> sd_card_clk | 7.334 | 8.992 | 0 | 0 |
| ext_mem_clk -> sys_pll_m0/pll_inst.clkc[2] | -2.787 | -2.920 | 32 | 32 |
| sys_pll_m0/pll_inst.clkc[2] -> ext_mem_clk | -6.699 | -6.565 | 32 | 32 |

全局Setup WNS −6.565ns/TNS −294.439ns，Hold +0.004ns/TNS 0；S8为−6.699ns/−294.850ns，Hold +0.025ns。本轮仍未时序收敛。像素同域+26.751ns、串行同域+3.432ns、像素→串行+6.376ns；新增复位、音频、显示相关路径没有负裕量路径组。

S8原BMP解析的3个负端点本轮消失，SD控制同域+0.149ns、内存同域+0.173ns。剩余64个端点均为SDRAM接口：读侧−6.565ns（S8−6.699ns），写侧−2.920ns（S8−2.787ns，退化0.133ns）。没有修改BMP解析或SDRAM结构，不能称所有路径均改善。

STA覆盖率92.39%→99.86%，本轮不再沿用像素/串行exclusive限制。但板级输入/输出delay仍未完整定义，且SDRAM接口存在负裕量；覆盖率不代表全工程电气验收通过。板测通过也不抹除这些限制。

| 资源 | S8 | S9 | 变化 |
|---|---:|---:|---:|
| LUT | 3366 | 3301 | −65 |
| 寄存器 | 2576 | 2590 | +14 |
| BRAM | 4 | 4 | 0 |
| DSP | 1 | 1 | 0 |
| PLL | 3 | 2 | −1 |

旧I2S/AXIS无消费者，S8综合已裁剪大部分逻辑；因此不能把本轮源清单删除量等同资源节省量。新增同步复位和串行寄存器复位增加少量寄存器。
