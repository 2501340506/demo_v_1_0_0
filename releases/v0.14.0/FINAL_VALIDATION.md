# v0.14.0 最终验证（2026-10-13）

- 正式 demo.bit 复用 s3-local.3，661052 字节；与候选文件及 local.3 标签内 bit 逐字节一致。
- 本轮核对 97 个工程输入，与 miso_eqn_attempt1 构建输入统一 CRLF/LF 后内容一致；生产源码及 TD 工程相对 local.3 标签无变化，未重新构建或重复仿真。
- S3 用户确认功能均正常；S4 用户针对持续运行、Flash 和完全断电冷启动三项回复“已完成；持续运行  20 分钟”，记录整体验收通过。
- local.3 完整 TD Routed Setup +0.096ns、Hold +0.076ns，失败端点为 0；时序审计、MISO 门级透传、SD 协议及扇区验证见 s3-local.3 的报告和记录。
- 缩放、真实 SDRAM 四宫格、音乐及故障恢复联合仿真沿用 s3-local.2 证据；local.3 只修复 MISO LUT 的 EQN 参数，未重复执行未改模块测试。
- local.1/local.2 曾板测失败，保留历史，正式交付使用 local.3。大图仍读取完整文件，四图首次缓存日志约 14.96 秒；没有宣称新增读卡性能优化。
- 回退 releases/v0.13.0/demo.bit。未跟踪用户素材、既有 worktree 与 best_result 保留。
