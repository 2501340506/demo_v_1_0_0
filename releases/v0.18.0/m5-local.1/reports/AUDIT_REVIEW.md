# M5 时序与告警审阅

构建 `publicity_m5_td_attempt27`，对照 M4 local.1 原构建；原生产功能开启、约束不改。111工程输入及根构建脚本与隔离快照逐字节核对，实际参数见本目录settings及[清单](../MANIFEST.md)。

最终16022/19600 LUT（81.74%）、10686寄存器、56 BRAM9k、2 BRAM32k、13 DSP；Setup +0.006ns/Hold +0.030ns，STNS/HTNS均0，STA覆盖率99.97%；无ERROR、完整bitgen。Setup裕量仅6ps，余量较小；以上为本次本地构建结果，板测仍待执行。

- 原始check_timing审计逐项审阅：0组合环、0无效约束、0无时钟驱动，14项汇总与M4相同；详见[规范化对照](audit_review.json)和[原始审计](check_timing.txt)。
- 综合及物理告警去除目录、行号后集合与M4均无新增或消失；并非零告警。
- 既有综合USR-6001/8012/8159仍报告`uart_rx_syn_4`未匹配、对应false-path失败；最终check_timing的0无效约束不代表此前这条命令已生效。本轮不改约束。
- 物理阶段仍有PHY-7002（U3/sdram初始位置在ECO布局时不合法、被移动）及PHY-5079（1条时钟使用局部布线）。原始日志保留，未作为已消除的问题。
- STA覆盖率为99.97%，M4为99.98%；本轮不宣称全路径覆盖。
- 两块BRAM32k的dummy输出仍为`g_scene_text$font_ram/ram.dob[9]`及`g_scene_text$text_ram/ram.dob[9]`。其他dummy类别为EG_PHY_LSLICE、EG_PHY_MSLICE、EG_PHY_PAD；汇总相同不表示综合实例名全部相同。
- 仍有9输入无input delay、16输出无output delay，及sd_miso异常输入延时一组（max21.000ns/min0.000ns）。保留既有IO约束例外，不称全接口时序覆盖。
- 失败TD尝试保留diagnostics/output，包含时序未达标及PHY-8103内部错误的运行；正裕量但有ERROR的输出同样拒绝交付。候选无TMR-2507/2509组合环切断。

生产最终像素/PCM及仿真模型边界见[验证](../VALIDATION.md)。M4总体反馈及前序M6未确认项不转移为M5板测结论。
