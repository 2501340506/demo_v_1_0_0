# TD35 实际约束、网表与告警审阅

审阅对象：`disaster_s2_td_attempt35`，Tang Dynasty v6.2.168116，EG4S20BG256，实际 routed slow/fast corner 报告。审阅者 Codex，2026-10-18。本地通过、板测待验收。

最终 Setup +0.047ns、Hold +0.030ns，STNS/HTNS 均 0；17525 LUT、11760 寄存器、57 BRAM9k、2 BRAM32k、14 DSP。综合及物理日志无 ERROR，bitgen 完成。资源与时序以 final_timing.rpt 和 demo_phy.area 为准；不以脚本退出码或生成 bit 单独判定通过。

## 约束覆盖及边界

STA coverage 为 99.97%（S1 为99.98%）。check_timing 无无时钟、无效约束、组合环、无路径约束或 PLL 频率不匹配。dummy/dangling 汇总包含 EG_PHY_BRAM32K、EG_PHY_LSLICE、EG_PHY_MSLICE、EG_PHY_PAD 四个模型组，不能解释成只有四个独立引脚。

未设置 input delay 的10个输入为 HDMI_DDC_SCL/SDA、key1/key2/key4、rst_n、sw1/sw2/sw3、uart_rx；相比S1的9个，仅新增异步拨码 SW3。未设置 output delay 的17个输出为 DDC两线、seg_data[7:0]、seg_sel[5:0]、uart_tx，与S1一致。这些是当前异步控制、未用/低速接口的覆盖边界，不宣称全部 IO 已获外部时序验证。

原 SPI 输入 sd_miso 的 max21ns/min0ns 被工具标为一项 abnormal input delay；SPI MCP、sd_dclk 5ns 与 HDMI 3.5ns datapath-only 边界保持S1配置。本次SDC差异只有SW3端口至首级寄存器的 false path，没有放宽内部时钟或路径。exceptions.timing 中所报告的 MCP/SMD 路径裕量全部为正，最小 +0.380ns；这只描述该报告的实际覆盖。

## SW3 同步链

exceptions.log 确认 SW3_PORT_COUNT=1、SW3_INPUT_REGISTER_COUNT=1、UART_LOG_COUNT=0。实际物理网表的 sw3_syn_4 为 C6 输入 PAD FF，ipad=sw3、ipclk=sd_card_bmp_m0/clk，diq 连接 switch_filter/sync0[0]，复位来自 u_reset_sd/release_pipe[2]。只豁免异步端口到此首级，未豁免后级。

sw3_sync.timing 的首级至 sync1 为100MHz SD时钟域受约束路径，Setup +7.848ns、Hold +1.056ns。打包后的物理端点名为 u_audio_ring/rgb_in[12]_syn_8.mi[0]，但路径明确给出实际网 switch_filter/sync1[0]，是物理重命名，不能按实例名字误判为音频路径。

## 告警差异与接受依据

- 新增 HDL-5007：LFN模块 for(integer...) 的语言模式告警；TD成功综合该逻辑。5070目录项/180名称命中及19个目录镜像用例覆盖顺序、校验和、跨簇与错误处理。
- hash ROM 的 mux268 改名 mux157 后出现未用 BRAM B口地址告警，属于原有告警族。物理映射拆为 mux157_syn_2 和 mux157_syn_21；使用端口地址/时钟已连接，后一块只使用A口。不是有效图像地址悬空。
- 图层延迟环 BRAM 的未用 bea/beb 及初始化被 eram_init=off 忽略告警。物理网表使用固定宽度PDPW RAM映射；RTL通过 fill_count/primed 屏蔽未填充输出，不依赖RAM初始值。100306次逐拍等价及303次异步复位通过，最终显示回归已重跑。
- 新增 OPT-5011（旧器件固定槽隐藏）及 OPT-5502（器件不支持 pre-route hold fixing）是本次更强物理优化选项的工具告警；接受依据为最终 routed setup/hold 和两项 TNS 均达门槛，不声称 pre-route hold 修复已执行。
- 继承 PHY-5079：唯一使用局部布线资源的时钟为 ext_mem_clk_sft / U3/u2_ram/SDRAM_CLK，CTS摘要 Clock/Fanout=0/1、LocalWireNum=1。继承 PHY-7002：U3/sdram 初始位置(12,12)/(164,288)未被保留，工具完成合法化。两者仍需随候选做实际 SDRAM/整机板测，不能写成零 critical warning。
- 既有加密SDRAM模型的未用/未驱动端口告警保留；完整 warning delta 在 audit_review.json，原始综合及物理日志同时交付。

不新增板测结论，不宣称零告警或100%覆盖。正式板测使用 releases 中固定 bit，失败构建留 diagnostics/output。生产RTL有两处新增行尾空白，为保持与已通过构建逐字节一致不作样式重写，不影响上述验证。
