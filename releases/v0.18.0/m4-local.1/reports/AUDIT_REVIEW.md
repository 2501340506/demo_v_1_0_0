# M4 TD14 时序与告警审阅

构建 `publicity_m4_td_attempt14`，对照已获用户总体确认的 M3 local.1 原构建。生产功能开启；约束及原 TD 用户工程未改。111 个工程输入与根构建脚本已同隔离快照逐字节核对，门槛和实际参数见 [MANIFEST](../MANIFEST.md)、本目录 settings 与原始报告。

最终 15966/19600 LUT（81.46%）、10683 寄存器、56 BRAM9k、2 BRAM32k、13 DSP；Setup +0.072 ns、Hold +0.003 ns，STNS/HTNS 均 0，STA 覆盖率 99.98%。无 ERROR，完整 bitgen。正裕量较小，该结果为本地候选构建结论，板测仍待执行。

## 与 M3 的对照

- `check_timing.txt` 的规范化审计汇总与 M3 一致：0 个组合环，无无效约束、无未约束时钟引脚；既有各项诊断未因此消失。自动检查结果保存在 [audit_review.json](audit_review.json)。
- 综合和物理构建告警去除构建目录及行号后的集合，与 M3 均无新增或消失。并非零告警；原始 `syn_1_build.log`、`phy_1_build.log` 保留。
- 两块 BRAM32k 的 dummy pin 人工核为 `g_scene_text$font_ram/ram.dob[9]` 和 `g_scene_text$text_ram/ram.dob[9]`，与 M3 同位置。其他 dummy 模型类仍有 EG_PHY_LSLICE、EG_PHY_MSLICE、EG_PHY_PAD；汇总相同不表示各综合实例名逐项相同。
- 仍有 9 个输入端口无 input delay、16 个输出端口无 output delay；仍报告 `sd_miso` 的一组 abnormal input delay：max 21.000 ns、min 0.000 ns。保留原有约束例外及其报告，不据此宣称全接口时序已覆盖或新增板级安全结论。
- 早期 TD10/11 发现 AUTO 请求依赖 ready，经 cache 目标译码形成组合反馈；已修为 valid 独立于 ready、只在接受时使用 ready。最终构建无 TMR-2507/2509，审计明确 0 组合环。早期失败/中止构建留在诊断目录，不作为候选。

模型与工具限制、各批回归的实际源码覆盖范围见 [VALIDATION](../VALIDATION.md)。正式验收以固定 bit 的真实板测记录为准，不沿用 M3 板测或前序 M6 未完成结论。
