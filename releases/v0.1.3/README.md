# v0.1.3 — 2026-10-03

媒体播放控制拆分后的板级验收归档。源码由本地 Git 标签 v0.1.3 定位。

- demo.bit：本次板级验收对应构建，629624 字节，构建时间 2026-10-03 22:00:31（北京时间）。
- demo_phy.ts、demo_pr.timing、demo_phy.area：最终时序及资源报告。
- integration.log：ModelSim 14 项集成回归全部通过。
- control_unit.log：独立控制模块握手、索引、优先级、同拍捕获及轮播测试通过。
- 用户已确认板级功能正常；未记录定量压力测试时长。

TD 6.2.168116 / EG4S20BG256 / top。Setup WNS -6.699 ns，Hold WNS +0.011 ns；时序尚未收敛，按用户要求暂不处理。TD 有 IP、未驱动引脚及局部时钟布线警告，详见 diagnostics/TD_BUILD_2026-10-03.md。

best_result 保留旧发布产物；本版本请使用本目录 demo.bit。归档仅在本地提交和打标签，未推送远端。