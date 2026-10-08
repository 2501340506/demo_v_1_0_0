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

[???????](releases/v0.6.0-bmp211/s2-local.1/README.md)?? decoder ?????ModelSim ? TD ??????????????S3 ???/???????????????? v0.5.4 ????
