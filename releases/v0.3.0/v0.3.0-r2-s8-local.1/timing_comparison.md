# S7 → S8 路径组时序对比

单位 ns，约束未修改。

| 路径组 | S7 WNS | S8 WNS | S7违例端点 | S8违例端点 |
|---|---:|---:|---:|---:|
| sd_card_clk -> sd_card_clk | 0.189 | -0.550 | 0 | 3 |
| video_clk -> video_clk | 26.444 | 26.747 | 0 | 0 |
| ext_mem_clk -> ext_mem_clk | 0.178 | 0.122 | 0 | 0 |
| hdmi_5x_clk -> hdmi_5x_clk | 3.361 | 5.263 | 0 | 0 |
| clk -> clk | 11.968 | 12.853 | 0 | 0 |
| sd_card_clk -> video_clk | 5.284 | 5.692 | 0 | 0 |
| ext_mem_clk -> sd_card_clk | 0.849 | 0.725 | 0 | 0 |
| sd_card_clk -> ext_mem_clk | 0.707 | 0.834 | 0 | 0 |
| ext_mem_clk -> video_clk | 4.730 | 4.626 | 0 | 0 |
| sd_card_clk -> clk | 4.956 | 4.778 | 0 | 0 |
| video_clk -> ext_mem_clk | 5.448 | 5.503 | 0 | 0 |
| video_clk -> sd_card_clk | 未报告 | 7.334 | 未报告 | 0 |
| ext_mem_clk -> sys_pll_m0/pll_inst.clkc[2] | -2.969 | -2.787 | 32 | 32 |
| sys_pll_m0/pll_inst.clkc[2] -> ext_mem_clk | -6.699 | -6.699 | 32 | 32 |

全局 Setup WNS −6.699 ns、TNS −294.850 ns；Hold +0.025 ns、TNS 0。STA覆盖92.39%。像素同域+26.747 ns，包含跨域的像素汇总+4.626 ns。新增 video_clk → sd_card_clk 应答路径组 +7.334 ns。音频、提交CDC所在路径组没有新增负裕量。

与S7相比，控制域增加3个负裕量端点：原有 bmp_read/file_len_reg[3] 到 state_reg[4]、scan_done_reg、state_reg[0]，分别 −0.550、−0.548、−0.510 ns。该RTL未改，属于本次布局后的旧解析路径退化；不能称为“没有新增违例”。S6也曾有此类路径违例，S7为正。本阶段不扩大到BMP解析结构重构，保留此风险供板级回归和后续时序整改。

其余64个端点仍是SDRAM接口：读侧 −6.699 ns，写侧 −2.787 ns（S7 −2.969 ns）。共67个违例端点，全局未收敛。内存同域+0.122 ns，串行同域+5.263 ns。未增加时序例外掩盖路径；原video_clk/hdmi_5x_clk exclusive约束仍限制完整跨域STA，ODDR功能仿真不能替代电气及时序验收。
