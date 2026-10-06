# v0.5.2 开发记录

最新：local.3 实测 `11000F / 00001F / AEBC2F / 22003F`，确认读数据 CRC 不一致。[local.4 当前候选](v0.5.2-s2-local.4/README.md) 增加 CMD59 和命令 CRC7，等待 SRAM 验证。四页诊断保留，尚未确认真实卡修复，S2 仍未通过。以下为先前排查历史。

2026-10-06：双 PLL 恢复 local.1 本地通过，但用户 SRAM 上板发现正常卡先 0 后 F，KEY2 后仍失败。S2 未通过；当前 [local.2 临时诊断候选](v0.5.2-s2-local.2/README.md) 用于读取失败命令及 R1，根因尚未确认。不是正式发布，未上传 GitHub，未烧写 Flash。

[阶段计划](../../docs/v0.5.2_TF卡恢复与单PLL分阶段计划.md) · [当前候选 bit](v0.5.2-s2-local.4/demo.bit) · [local.1 失败记录](v0.5.2-s2-local.1/BOARD_VALIDATION.md)

基线 `v0.5.1`；本地计划标签 `v0.5.2-plan.1`，协议/按键标签 `v0.5.2-s1-local.1`。S1 验证由 `diagnostics/sd_recovery/run_tests.ps1` 复现，日志随 S2 候选保存。

S2 用户确认前不开始单 PLL 集成；单 PLL 输出和 SDRAM 频率仍待讨论。S4 最终验收安排 30 分钟 AUTO、10 次独立冷启动、5 次拔插恢复，当前均未执行或登记为通过。
