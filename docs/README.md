# BMP 2.11 已上传 GitHub 并合并 main（2026-10-08）

feature/bmp211-decoder、main 和本任务五个阶段标签已成功原子推送。板级版本 v0.6.0-bmp211-s3-board.1。main 合并无冲突，合并文件树与已验收分支一致；源码及 bit 未改变，未重复构建。

仓库：https://github.com/xier1-droid/anlogic-eg4-hdmi-bmp-player/tree/main 。用户未提交的 TD 工程、best_result、S2 工程日志及个人记录保留在本地，未纳入发布。

以下为历史过程，其“待授权/未上传”状态已由上述完成结果更新。
# BMP 2.11 已完成板级验收与本地归档（2026-10-08）

当前本地板级版本：v0.6.0-bmp211-s3-board.1，沿用 S3 local.1 原 bit。用户确认好图、坏图过滤、恢复/AUTO 功能正常；最终独立、稳定性及系统回归全部通过。2.12 不在范围内。GitHub 未上传，等待单独明确授权。

[版本、bit、验证及归档](history/2026-10-08/bmp24_decoder/README.md)。以下为历史过程记录。

# BMP 2.11 S3 本地候选（2026-10-08）

S2 用户上板通过后，S3 已完成生产解码器固定接入与共享头校验，移除包装层旧解析和像素完整性计数。本地 ModelSim 与 TD 通过；等待 S4 上板，尚未结项、未上传 GitHub。
[S3 候选、bit 与验证报告](../releases/v0.6.0-bmp211/s3-local.1/README.md)。正式已验收版仍为 v0.5.4。

以下为历史记录。

# 当前正式版：v0.5.4

[版本及下载](../releases/v0.5.4/README.md) · [验证状态](VALIDATION_STATUS.md) · [完成归档](history/2026-10-07/v0.5.4/README.md)。S5已完成，复用已验收原bit。

以下为历史文档入口。

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

## BMP 2.11 ??? S2 ???


当前 BMP 2.11：[阶段计划](bmp24_decoder_plan.md)，S2 候选待上板，S3 尚未实施。
