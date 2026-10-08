# 最新状态：FAT32 S3 本地完成，待上板（2026-10-08）

原项目目录 feature/fat32-filesystem 已接入 FAT32 目录扫描、BMP 头预检和按簇链读取，支持缺图与碎片文件。核心 42 场景、包装器 42 素材加 5 模式及最终 16 个验证入口通过。TD attempt7 Setup +0.104 ns / Hold +0.014 ns，固定候选 v0.7.0-s3-local.1。尚未上板验收或合并 main。
[S3 验证与板测入口](docs/fat32_s3_validation.md)。以下为历史记录，旧状态不代表当前状态。

# FAT32 v0.7.0：S1 本地通过，待上板（2026-10-08）

当前 feature/fat32-filesystem 完成 S0/S1。新增扇区适配并接入旧 BMP 路径，完成接口/恢复回归及 TD 时序收敛；FAT32 核心尚未接入。固定候选 v0.7.0-s1-local.1：Setup +0.132 ns，Hold +0.035 ns；用户确认上板后才进入 S2。

[固定 bit 与说明](releases/v0.7.0/s1-local.1/README.md) · [上板步骤](releases/v0.7.0/s1-local.1/BOARD_VALIDATION.md) · [计划](docs/fat32_filesystem_plan.md) · [交接](HANDOFF.md)。本任务尚未建立 board 标签或推送 GitHub；上一版已验收成果保持有效。

以下为历史记录。
# BMP 2.11 已上传 GitHub 并合并 main（2026-10-08）

feature/bmp211-decoder、main 和本任务五个阶段标签已成功原子推送。板级版本 v0.6.0-bmp211-s3-board.1。main 合并无冲突，合并文件树与已验收分支一致；源码及 bit 未改变，未重复构建。

仓库：https://github.com/xier1-droid/anlogic-eg4-hdmi-bmp-player/tree/main 。用户未提交的 TD 工程、best_result、S2 工程日志及个人记录保留在本地，未纳入发布。

## 目录地图

| 路径 | 用途 | 版本控制约定 |
|---|---|---|
| `TD_project/` | Tang Dynasty 工程入口；使用 `demo.al` 打开工程 | 工程入口纳入版本控制，综合、布局布线和本机状态文件不纳入 |
| `user_source/` | 正式 RTL、约束和 IP 源码 | 纳入版本控制，是当前生产源码入口 |
| `diagnostics/` | testbench、诊断脚本、固定测试素材及运行入口 | 可复用内容纳入版本控制；`output/`、`local_tools/` 仅保存在本地 |
| `releases/` | 各版本 bit、版本说明、必要源码快照和正式验证证据 | 已发布内容作为固定交付物保留，不放入新生成的工具日志 |
| `docs/` | 当前设计文档、验证状态和历史归档 | 纳入版本控制；已完成任务归档到 `docs/history/` |
| `work/` | 本地 ModelSim 工作库 | 不纳入版本控制 |

日常开发从 `TD_project/demo.al`、`user_source/` 和 `diagnostics/README.md` 开始；上板使用 `releases/` 中的固定 bit，不使用会被后续构建覆盖的运行目录产物。

以下为历史过程，其“待授权/未上传”状态已由上述完成结果更新。
# BMP 2.11 已完成板级验收与本地归档（2026-10-08）

当前本地板级版本：v0.6.0-bmp211-s3-board.1，沿用 S3 local.1 原 bit。用户确认好图、坏图过滤、恢复/AUTO 功能正常；最终独立、稳定性及系统回归全部通过。2.12 不在范围内。GitHub 未上传，等待单独明确授权。

[版本、bit、验证及归档](docs/history/2026-10-08/bmp24_decoder/README.md)。以下为历史过程记录。

# BMP 2.11 S3 本地候选（2026-10-08）

S2 用户上板通过后，S3 已完成生产解码器固定接入与共享头校验，移除包装层旧解析和像素完整性计数。本地 ModelSim 与 TD 通过；等待 S4 上板，尚未结项、未上传 GitHub。
[S3 候选、bit 与验证报告](releases/v0.6.0-bmp211/s3-local.1/README.md)。正式已验收版仍为 v0.5.4。

以下为历史记录。

# 当前正式版本：v0.5.4 UART可观测性

[下载正式bit](releases/v0.5.4/demo.bit) · [版本说明](releases/v0.5.4/README.md) · [验收与归档](docs/history/2026-10-07/v0.5.4/README.md)。复用已验收S3 local.2原bit，启动行保持BOOT v0.5.4-s3-local.2，无需重复板测。

以下为项目使用说明及历史版本背景；其中旧“当前版本/下载”以本页顶部入口为准。

# 安路 EG4 HDMI 图片播放器

当前工作区已补 SPI/HDMI I/O 时序预算，SD 数据传输改为 16.667 MHz；新候选 [v0.5.2-io-local.1](releases/v0.5.2/v0.5.2-io-local.1/README.md) 本地及用户上板功能验证通过，用户明确免除后续 Flash、冷启动、拔插次数及长稳专项，本次验收通过，C0 保持 100 MHz。[预算与未覆盖项审查](docs/timing_closure/IO_TIMING.md)。下方正式下载和板级结果仍对应已验收 s4-board.2。

当前正式版本：**[v0.5.2 — 单 PLL、40 MHz SDRAM 与 TF 恢复](releases/v0.5.2/README.md)**。

刷新修复：[v0.5.2-s3-board.2](releases/v0.5.2/v0.5.2-s3-board.2/README.md)，本地回归、TD、S3 SRAM 和同一 bit 的 S4 Flash/长稳均通过。

2026-10-07 [补测记录](releases/v0.5.2/evidence-2026-10-07/README.md)：完整帧行为仿真通过；旧产物实际 SDRAM 控制器刷新间隔专项未通过；现已通过 1100 周期调度修复，并完成端到端数据链路和新候选板测。已发布 bit 和用户板级验收记录保留。

[下载正式 bit](releases/v0.5.2/v0.5.2-s4-board.2/demo.bit) · [S4 Flash 与长稳验收](releases/v0.5.2/v0.5.2-s4-board.2/README.md) · [阶段归档](docs/history/2026-10-07/v0.5.2/README.md)。

目录入口：[统一文档](docs/README.md) · [版本产物规则](releases/README.md) · [构建与诊断归档](diagnostics/README.md)。

基于Anlogic EG4S20BG256，从TF卡读取BMP，经SDRAM双缓冲输出640×480 HDMI视频与48kHz双声道图片琶音。实际显示提交后提示一次，音量128；一颗PLL、五个时钟域分别同步释放复位。

上一正式版本：[v0.5.1](releases/v0.5.1/README.md)。历史HDMI升级已结项，相关资料见[历史索引](docs/ARCHIVE_INDEX.md)。

## 使用方式

| SW2 SW1 | 模式位 | KEY1 | KEY2 |
|---|---|---|---|
| 00 | 0 图片 | 上一张 | 下一张 |
| 01 | 1 亮度预留 | 不产生新请求 | 不产生新请求 |
| 10 | 2 对比度预留 | 不产生新请求 | 不产生新请求 |
| 11 | 3 缩放预留 | 不产生新请求 | 不产生新请求 |

KEY4单击切换MAN/AUTO。复位默认MAN，扫描完成且图片多于一张时允许切换AUTO。三个按键20ms消抖，长按不连发；图片首尾循环。

v0.5.2 中 KEY2 改为短按松手翻图；任何模式长按 2 秒重初始化及重扫，松手不翻图。恢复保留旧图，新首图完整提交后提示一次并回 MAN；初始化/扫描为 0/2、无图 E、通信失败 F，失败可再次长按。此行为已获 S3 上板确认。

AUTO在四模式下保持，加载完成且空闲约3秒后再翻图，实际间隔包括加载时间。模式变化重新计时，S1修复模式变化恰逢AUTO到期时同拍误发翻图请求；已有手动挂起请求继续处理。图片编号位小数点表示AUTO。

加载期间每个方向最多挂起一次，同向请求合并；下一张优先于上一张，再优先于自动轮播。模式切换不清除已有挂起请求；切回MAN不取消已开始的加载和挂起的手动请求。图片编号在显示交接确认后更新。

## 硬件与图片

| 信号 | FPGA引脚 | 说明 |
|---|---|---|
| KEY1 | A2 | 按下为0 |
| KEY2 | B2 | 按下为0 |
| KEY4 | C1 | 按下为0 |
| SW1 | C8 | 拨上为1 |
| SW2 | C7 | 拨上为1 |

图片须为640×480、24位、未压缩BMP。程序按扇区顺序扫描前131072个扇区，最多查找4张图片，不依赖FAT文件名；上电自动加载首图。模式位显示0/1/2/3，不代表亮度、对比度或缩放已经实现。

## 下载与构建

当前正式下载：[v0.5.2 固定 bit](releases/v0.5.2/v0.5.2-s4-board.2/demo.bit)，沿用 S4 已验收产物。

使用Tang Dynasty 6.2打开`TD_project/demo.al`，器件EG4S20BG256、顶层top，依次综合、布局布线、生成bitstream。命令行入口为`diagnostics/run_td_build.ps1`；复现已验收布局参数见[源清单](releases/v0.5.2/v0.5.2-s3-local.2/sources.txt)，GUI默认策略不同。运行目录`TD_project/demo_Runs/phy_1/demo.bit`会被新构建覆盖，上板使用版本目录中的固定文件。

[交接记录](HANDOFF.md) · [验证状态](docs/VALIDATION_STATUS.md) · [诊断入口](diagnostics/README.md) · [历史索引](docs/ARCHIVE_INDEX.md)。

## 验证状态与范围

S4 已确认 Flash 写入校验、10 次独立冷启动、5 次拔插恢复和 30 分钟 AUTO 通过。单 PLL 为 100/40/40/25/125 MHz，C2 相位 172.8°（12 ns），面板保持外部 50 MHz。

TD 报告 Setup +0.128 ns、Hold +0.012 ns，覆盖率 99.89%；外部 I/O 延时及功能模型的验证限制见[验证边界](releases/v0.5.2/README.md)。

本版不包含OSD、亮度/对比度调节或缩放。预留参数B初值0、范围−128..127；C初值128、范围0..256、至少9位，作为后续需求记录。

## 2026-10-08 BMP ??? S2 ????

