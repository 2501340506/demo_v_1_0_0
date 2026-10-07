> 当前故障：S3 local.1首图花屏，回退S2 local.2恢复正常。S3不予验收、不上传，正在定位；下方仿真/TD通过仅是本地证据。

# 当前开发入口：v0.5.4 S3

[阶段计划](v0.5.4_UART与快速启动分阶段计划.md) · [接口约定](S3_SCAN_RESUME.md) · [S3候选](../releases/v0.5.4/v0.5.4-s3-local.1/README.md) · [验证状态](VALIDATION_STATUS.md)。S2已验收上传；S3本地通过但板测首图花屏；S4未实施。

# 文档入口

当前正式版：[v0.5.2](../releases/v0.5.2/README.md) · [验证状态](VALIDATION_STATUS.md) · [v0.5.2 归档](history/2026-10-07/v0.5.2/README.md)。S4 已通过，当前修复产物沿用 S3 local.2，由 S4 board.2 固定。

已结项：[v0.5.0 Flash固化与上电自启计划](Flash固化与上电自启分阶段修改计划.md) · [课程对照](FLASH_BOOT_SOURCES.md)。[正式版本](../releases/v0.5.0/README.md) · [结项归档](history/2026-10-05/Flash固化与上电自启/README.md)。

系统稳定性计划已结项：[完成计划](系统稳定性分阶段修改计划.md) · [历史归档](history/2026-10-05/系统稳定性增强/README.md) · [v0.4.0正式版本](../releases/v0.4.0/README.md)。

原`docx`为笔误，内容已统一合并到本目录；按日期保存的历史记录合并保留，无覆盖。

| 内容 | 入口 |
|---|---|
| 当前产品及下载 | [项目README](../README.md) · [v0.5.1正式版本](../releases/v0.5.1/README.md) · [v0.5.2当前发布](../releases/v0.5.2/README.md) |
| 验证结论和边界 | [VALIDATION_STATUS.md](VALIDATION_STATUS.md) |
| v0.5.2 历史证据补测 | [完整帧通过与刷新失败证据](../releases/v0.5.2/evidence-2026-10-07/README.md) |
| 已完成阶段计划 | [HDMI音频分阶段修改计划](HDMI音频分阶段修改计划.md) |
| 历史归档 | [ARCHIVE_INDEX.md](ARCHIVE_INDEX.md) · [history](history) |
| 课程来源和改写说明 | [HDMI_AUDIO_SOURCES.md](HDMI_AUDIO_SOURCES.md) |
| SD恢复历史分析 | [旧版SD恢复分析](diagnostics/s9_sd_recovery/analysis.md)（历史暂缓范围已由 v0.5.2 新任务接续） |
| 构建/历史测试复现 | [diagnostics入口](../diagnostics/README.md) |

`history`保存历次说明和验收快照；`diagnostics`只保存问题分析及证据。下载文件仍在`releases`，不在文档目录重复保存bit。

## 本次目录整理

原`docx`内容逐文件并入`docs`，相关链接已更新。v0.2.0合并审查移至对应历史日期。已完成版本的测试进入`diagnostics/history/v0.3.0`，构建入口仍为`diagnostics/run_td_build.ps1`，新运行输出统一到`diagnostics/output`。

旧诊断日志、报告及原始输出保存为[local_results.zip](../diagnostics/history/2026-10-05/local_results.zip)，附[归档说明](../diagnostics/history/2026-10-05/README.md)。既有发布bit和生产RTL未改。

## 清理完成

用户已手动删除根目录`_cleanup`，并已确认目录不存在。原reference、合并后空的docx目录树和旧诊断缓存清理完成；需要保留的资料已归档。

S4已由用户整体确认通过，v0.5.0发布；[最终验收记录](flash_boot/s4/BOARD_VALIDATION.md) · [固化指南](flash_boot/S3_FLASH_GUIDE.md)。
