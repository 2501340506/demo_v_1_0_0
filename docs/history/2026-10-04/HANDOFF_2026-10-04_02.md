# 当前交接记录

更新日期：2026-10-04

## 当前状态

项目以 **v0.1.8** 作为最终功能基线，四阶段均已完成 ModelSim 验证、TD 构建和用户板级功能验收。后续 RTL、仿真和 TD 功能修改暂停。

- 开发分支：`demo010-0_1_1`
- 发布标签：`v0.1.8`（保持原标签不变）
- `main`：未合并
- 固定上板文件：`releases/v0.1.8/demo.bit`
- 发布说明：[releases/v0.1.8/README.md](releases/v0.1.8/README.md)
- 归档索引：[docs/ARCHIVE_INDEX.md](docs/ARCHIVE_INDEX.md)

## 验收与限制

六个控制仿真顶层、图片控制回归和三组异步缓冲交接模型均已通过。板级结论来自用户验收；`baseline_*.log` 是旧控制器反证材料，不属于当前版本失败结果。

当前构建时序仍为 Setup WNS -6.699 ns、Hold WNS +0.003 ns。时序优化按约定暂缓；行为模型不能替代厂商 IP 内部时序、真实亚稳态和完整电气行为验证。

## 当前工作区边界

以下 3 个未提交 TD 文件按用户要求保留原状，不纳入文档归档提交：

- `TD_project/demo.al`
- `TD_project/demo_Runs/best_result/demo.bit`
- `TD_project/demo_Runs/best_result/demo_phy.ts`

本次归档未重新运行 RTL/ModelSim/TD，不删除历史版本、不改写发布标签。阶段报告、计划和旧交接记录见 [docs/history/2026-10-04/](docs/history/2026-10-04/)。

## 后续入口

恢复工作时，先从 v0.1.8 归档和 [diagnostics/README.md](diagnostics/README.md) 核对证据，再单独提出功能或时序变更计划。当前保持归档状态。

## 历史交接记录

本文件之前的完整交接内容已归档至 [HANDOFF_2026-10-04.md](docs/history/2026-10-04/HANDOFF_2026-10-04.md)。
