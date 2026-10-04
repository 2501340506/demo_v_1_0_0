# 目录整理与旧本地运行结果

2026-10-05整理，软件功能不变。原docx统一合并到docs，参考原件由用户自行备份，已完成测试脚本迁至版本归档。

- [local_results.zip](local_results.zip)：299个旧日志、报告、生成源码及bit等原始输出，保留原modelsim目录名。压缩包已校验可读，并逐条与原文件比对一致。
- [inventory.json](inventory.json)：文件迁移映射、归档数量及缓存统计。
- 851个其余ModelSim/TD缓存文件未纳入压缩包；可由仿真/构建重建。原目录曾暂存于根目录_cleanup，现已由用户手动删除。

ZIP包括早期失败/取消实验记录，不能将其中任意日志当作当前版本验收。正式证据以[releases](../../../releases/v0.3.0/README.md)为准。工具日志里的旧路径按原样保留，不清洗历史证据。

## 整理后的路径

`docx/*` → `docs/*`；旧`diagnostics/run_*.ps1`（除TD构建）、`tb_*.sv`、`check_*.py` → `diagnostics/history/v0.3.0/`；SD复现例外归入`diagnostics/history/sd_recovery/`。未来输出在`diagnostics/output`，不再散落诊断根目录。

## 迁移验证

迁移后8个仿真入口均重新执行通过：控制、模式面板、异步缓冲、独立PCM、HDMI基础/封装、视频对齐、最终媒体/PHY/CDC、S9顶层复位。脚本使用新目录，结果在diagnostics/output。testbench和Python参考逻辑保持不变。

生产RTL、TD工程、正式时序/资源报告均无Git差异，正式v0.3.0 bit与已发布Git版本逐字节一致。未运行TD重新构建；本轮只验证目录迁移没有破坏既有入口，不扩大SD恢复问题范围。
