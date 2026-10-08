# 最新状态：FAT32 S1 上板通过（2026-10-08）

用户确认 v0.7.0-s1-local.1 相关功能正常，串口记录正常切图及错误停机后的重扫恢复；建立 v0.7.0-s1-board.1，复用原 bit。S2 尚未实施。开发已迁回原项目目录的 feature/fat32-filesystem 分支，后续遵循更新后的《执行规则.md》。本阶段 GitHub 同步状态见 HANDOFF.md。

以下为历史记录，旧的“待上板”和“独立 worktree 开发”描述不再代表当前状态。
# 当前状态：FAT32 S1 本地通过，待上板（2026-10-08）

v0.7.0-s1-local.1 已完成扇区适配、旧 BMP 链路接入及必要的 UART 时序分级。最终九个验证入口（含八项系统回归）通过；TD Setup +0.132 ns / Hold +0.035 ns。尚未进行本候选板测，S2/S3 FAT32 核心未接入。

[验证与限制](fat32_validation.md) · [固定候选](../releases/v0.7.0/s1-local.1/README.md)。以下为历史记录，既有已验收版本仍可回退。
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

# 当前验证：v0.5.4已验收结项

正式产物复用S3 local.2用户已确认通过的原bit，无RTL/约束变化、无重新构建。生产源码及既有验证脚本与v0.5.4-s3-board.2一致；bit629624字节，逐字节一致。S4按用户决定跳过，S5完成归档。

TD既有结果Setup +0.121ns/Hold +0.014ns、覆盖99.92%；专项与相关回归通过，用户整体板测通过。保留原PLL/SDRAM警告和历史失败事实，不追加或补造验收范围。

[最终验收摘要](history/2026-10-07/v0.5.4/FINAL_VALIDATION.md) · [用户板测](history/2026-10-07/v0.5.4/S3_board_validation.md) · [正式版本](../releases/v0.5.4/README.md)

## 2026-10-08 BMP ??? S2 ????


BMP 2.11 S2：本地 ModelSim/TD 通过，等待上板；尚未完成 S3 解析与结果抽离。见 [阶段计划](bmp24_decoder_plan.md)。
