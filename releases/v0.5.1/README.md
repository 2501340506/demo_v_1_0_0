# v0.5.1 — 时序收敛与 Flash 启动回归

当前状态：v0.5.1 已完成。S0–S4 本地完成，S5 获用户整体上板确认；按用户决定跳过 S6 长稳验收，已完成归档、正式标签和 GitHub 上传。

## 范围

本版本基于 v0.5.0，逐阶段审计 SDRAM 接口和内存内部负时序路径，同时保持 Flash 固化、上电自启、PLL 复位和 SDRAM 就绪门控行为不变。

## 当前证据

- 基线报告：`docs/timing_closure/BASELINE_v0.5.1.md`
- 活动计划：`docs/timing_closure/v0.5.1_时序收敛与Flash回归分阶段计划.md`
- v0.5.0 固定产物和 Flash 验收：`../v0.5.0/README.md`
- S5 板级步骤：[BOARD_VALIDATION.md](BOARD_VALIDATION.md)
- 当前候选：[demo.bit](demo.bit)

用户板级确认前不建立正式标签、不合并主分支、不上传 GitHub。

用户已确认 S5 通过并明确跳过 S6；本版本不补造长稳轮次、时长或设备数据。
