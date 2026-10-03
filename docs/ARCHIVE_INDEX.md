# 项目归档索引

最后整理：2026-10-04。当前最终基线：**v0.1.8**。

## 当前发布

- 分支：`demo010-0_1_1`
- 标签：`v0.1.8`
- 固定 bitstream：[releases/v0.1.8/demo.bit](../releases/v0.1.8/demo.bit)
- 发布说明：[releases/v0.1.8/README.md](../releases/v0.1.8/README.md)
- 源码提交：`8eb1d484f4ffd9c1a758669f8a4bd84e822dcdad`

## 版本演进

| 版本 | 主题 | 板级状态 |
| --- | --- | --- |
| v0.1.0 | 按键稳定性与加载失败处理基线 | 已验收 |
| v0.1.3 | 媒体播放控制拆分 | 已验收 |
| v0.1.4 | 显示策略拆分 | 已验收 |
| v0.1.5 | 按键事件衔接修复 | 已验收 |
| v0.1.6 | 稳定沿长按计时与手动优先 | 已验收 |
| v0.1.7 | 轮播小数点提示 | 已验收 |
| v0.1.8 | 读侧提交确认与缓冲所有权 | 已验收，当前基线 |

v0.1.1、v0.1.2 为早期过程归档，保留原目录和标签。

## 证据位置

- 阶段验收说明：`diagnostics/STAGE1_KEY_ACCEPTANCE.md` 至 `STAGE4_BUFFER_HANDOFF.md`
- 当前测试入口：`diagnostics/README.md`
- 四阶段计划：`docs/COURSE_REVIEW_IMPROVEMENT_PLAN.md`
- 历史经验：`docs/KEY_CONTROL_LESSONS.md`
- 日期历史资料：`docs/history/2026-10-03/`
- 版本产物：`releases/v0.1.0/` 至 `releases/v0.1.8/`

## 证据边界

板级结论来自用户验收；ModelSim 只证明测试模型覆盖的 RTL 行为；TD 报告显示功能构建完成但 Setup 时序仍未收敛。旧版本 baseline 日志用于复现问题，不属于当前版本失败结果。后续修改暂停。

## 未纳入本次整理

以下未提交 TD 文件保留原状，不属于 v0.1.8 归档内容：

- `TD_project/demo.al`
- `TD_project/demo_Runs/best_result/demo.bit`
- `TD_project/demo_Runs/best_result/demo_phy.ts`
