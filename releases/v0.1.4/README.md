# v0.1.4 — 显示策略拆分验收归档

2026-10-03 用户确认板级功能验收正常。源码由本地标签 v0.1.4 定位。

- demo.bit：TD 6.2.168116 / EG4S20BG256 / top，构建时间 2026-10-03 22:37:35（北京时间），629624 字节。
- demo_phy.ts、demo_pr.timing、demo_phy.area：最终时序及资源报告。
- tb_*.log：显示、图片请求、播放控制及双键路由四份通过日志。
- 完整验收说明：../../diagnostics/DISPLAY_CONTROL_ACCEPTANCE.md。

Setup WNS -6.699 ns，Hold WNS +0.011 ns，时序未收敛；按用户要求暂不处理。TD 仍有 IP 和局部时钟等警告。板级验收来自用户反馈，未记录定量压力测试时长。

v0.1.3 与 best_result 保留。本次建立本地提交与标签，尚未推送远端。