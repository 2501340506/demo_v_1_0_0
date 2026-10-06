# v0.5.2 开发记录

2026-10-06：双 PLL 下恢复功能已完成本地实现，候选 [v0.5.2-s2-local.1](v0.5.2-s2-local.1/README.md) 待用户 SRAM 上板验收。不是正式发布，未上传 GitHub，未烧写 Flash。

[阶段计划](../../docs/v0.5.2_TF卡恢复与单PLL分阶段计划.md) · [固定 bit](v0.5.2-s2-local.1/demo.bit) · [板级表](v0.5.2-s2-local.1/BOARD_VALIDATION.md)

基线 `v0.5.1`；本地计划标签 `v0.5.2-plan.1`，协议/按键标签 `v0.5.2-s1-local.1`。S1 验证由 `diagnostics/sd_recovery/run_tests.ps1` 复现，日志随 S2 候选保存。

S2 用户确认前不开始单 PLL 集成；单 PLL 输出和 SDRAM 频率仍待讨论。S4 最终验收安排 30 分钟 AUTO、10 次独立冷启动、5 次拔插恢复，当前均未执行或登记为通过。
