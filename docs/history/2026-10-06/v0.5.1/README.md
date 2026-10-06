# v0.5.1 时序收敛与 Flash 启动回归结项归档

2026-10-06。v0.5.1 基于 v0.5.0 完成 S0–S5：修复基线回归、完成 SDRAM 路径审计、隔离一个 fabric 时序路径、完成约束审查并准备 Flash 候选。用户确认 S5 上板验证通过，并明确不执行 S6 长稳验收；按此决定结项。

## 归档内容

- [活动计划](../../../timing_closure/v0.5.1_时序收敛与Flash回归分阶段计划.md)
- [S2 路径审计](../../../timing_closure/S2_SDRAM路径审计.md)
- [S4 约束审查](../../../timing_closure/S4_约束审查.md)
- [S5 板级验证](../../../../releases/v0.5.1/BOARD_VALIDATION.md)
- [正式版本](../../../../releases/v0.5.1/README.md)
- [结项交接](HANDOFF_completed.md)

## 验收边界

S5 的板级通过按用户整体反馈记录，不补写轮次、时长和设备。S6 长稳验收按用户明确决定跳过。剩余 64 个 SDRAM 硬核边界负端点、板级 I/O 延迟资料缺失及既有 SD 恢复边界继续保留。
