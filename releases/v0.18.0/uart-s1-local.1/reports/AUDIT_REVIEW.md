# UART S1 最终 TD 审阅

审阅对象 `uart_reduction_td_attempt05`，生产输入基线 `075ab05`；对照 M5 local.1 的 TD27 报告（M6 local.1 复用该 bit）。本轮完整综合、布局布线及 bitgen 均完成，无 ERROR。最终物理结果 14092 LUT、9530 寄存器、46 BRAM9k、2 BRAM32k、13 DSP。Setup +0.040ns、Hold +0.019ns，STNS/HTNS 均为 0，STA 覆盖率 99.97%。时序裕量仍小，不能把本地 STA 结论替代实板验证。

## 实际约束

已对照 [check_timing.txt](check_timing.txt)、[exceptions.timing](exceptions.timing) 和 [audit_review.json](audit_review.json)：无时钟约束的时钟脚 0、无效约束 0、组合环 0、无路径约束 0、被遮蔽/忽略的异常约束 0。仅移除已关闭 UART 的三条 TX 延时与一条 RX false-path；其余时钟、IO 预算与内部路径要求未改。

| 实际异常约束 | 路径数 | 遮蔽/忽略 |
|---|---:|---:|
| SD MISO setup MCP 3 / hold MCP 2 | 各 1 | 0 |
| SD MOSI/NCS setup MCP 3 / hold MCP 3 | 各 2 | 0 |
| SD SCLK max-delay 5ns | 1 | 0 |
| HDMI max-delay 3.5ns | 8 | 0 |
| UART TX max-delay | 不存在 | 不适用 |

常量 TX 不再把 10ns 延时错误扩展到内部路径；最终面积报告无 logger/RX/字幕控制及提交实例，异常审计的 `UART_LOG_COUNT=0`。独立探针使用最终 SDC，在已开启 UART 的基线数据库恢复 TX 约束时仅覆盖原有 1 条路径；关闭数据库中该约束不存在。恢复 UART 参数时必须同步恢复对应 SDC 命令，核对 RX 输入 PAD FF 的实际目标并重新构建。

## 保留的 IO 与工具模型限制

- 9 个无 input-delay 端口：DDC SCL/SDA、key1/key2/key4、rst_n、sw1/sw2、uart_rx。17 个无 output-delay 端口：DDC SCL/SDA、8 位 seg_data、6 位 seg_sel 和 uart_tx。相对基线增加的 1 个为恒高 TX；本候选不再有串口输出数据时序。其余为既有面板/异步接口例外，不宣称全 IO 已约束。
- SD MISO 的 max 21ns / min 0ns 仍被报告为 1 条 abnormal input-delay，保留既有 MCP 处理，未在本任务重新定义外部器件预算。
- DummyNode 仍有 4 类：BRAM32K、LSLICE、MSLICE、PAD。其中 FONT/TEXT 两个 BRAM32K 的 dob[9] 保留既有模型诊断；详细实例以原始检查报告为准。
- 物理告警 `PHY-7002`（SDRAM 初始位置在 ECO 中移动）及 `PHY-5079`（ext_mem_clk_sft 到 U3/u2_ram/SDRAM_CLK 的 1 条本地布线）仍存在；与基线相比无新增物理告警种类或消息。真实 SDRAM、电视接口及连续运行仍待本候选上板确认。

## 综合告警差异

[差异 JSON](audit_review.json)按消息内容对比，归一化构建目录与行号，没有屏蔽告警类别。唯一新打印的消息是 `Sdr_rd_dout_reg[9]` 的 `SYN-5011` 未驱动 clk。基线先打印 RX rx_meta 时钟及 SDR 位 0–8，随后 `Similar messages will be suppressed`；本轮移除 RX 后打印 SDR 位 0–9，再达到同一打印上限。这符合既有 SDR 诊断的展示位次变化，不视为 SDR 告警已解决；SDR 加密源未修改。

随模块裁掉而消失的消息为 logger 的 text_rom 未驱动、RAM bea/beb 未驱动及初始化忽略、RX rx_meta 时钟；最终同时消除了旧 RX false-path 的 `USR-6001/8012/8159` 匹配失败。其余既有 HDL 参数和 SDR 综合诊断保留，不能称零告警。

attempt01–04 均未交付：前两轮常量 TX 约束错误扩大且 Tcl if 不能保护 SDC 命令；第三轮时序失败；第四轮时序通过但旧 RX false-path 无效。最终候选只采用 attempt05，失败证据留在 diagnostics/output。
