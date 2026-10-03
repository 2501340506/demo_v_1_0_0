# 当前交接记录

更新日期：2026-10-04

## 当前状态

项目当前固定基线为 **v0.1.8**。四阶段已完成仿真、TD 构建和用户板级功能验收；后续 RTL、仿真、TD 与时序优化工作暂停。

- 分支：`demo010-0_1_1`
- 标签：`v0.1.8`，不改写
- `main`：未合并
- 上板文件：`releases/v0.1.8/demo.bit`
- 归档入口：[docs/ARCHIVE_INDEX.md](docs/ARCHIVE_INDEX.md)

## 证据边界

控制回归和缓冲交接行为模型均已通过。`baseline_*.log` 仅用于旧控制器问题对照，不是当前版本失败结果。板级结论来自用户验收；Setup WNS -6.699 ns、Hold WNS +0.003 ns，时序尚未收敛。行为模型不覆盖厂商 IP 内部时序、真实亚稳态和完整电气行为。

## 当前工作区

以下文件按用户要求保留原状，不纳入文档整理：

- `TD_project/demo.al`
- `TD_project/demo_Runs/best_result/demo.bit`
- `TD_project/demo_Runs/best_result/demo_phy.ts`

本次仅更新交接文档，未运行 RTL/ModelSim/TD，未移动发布目录或改写标签。

## 后续入口

恢复工作时，以 `releases/v0.1.8/`、`diagnostics/README.md` 和 `docs/ARCHIVE_INDEX.md` 为入口，另行提出修改计划。上一版交接记录见 [HANDOFF_2026-10-04.md](docs/history/2026-10-04/HANDOFF_2026-10-04.md)，本次归档副本见 [HANDOFF_2026-10-04_02.md](docs/history/2026-10-04/HANDOFF_2026-10-04_02.md)。
