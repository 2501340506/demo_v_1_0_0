# 安路 EG4 HDMI 图片播放器

当前正式版本：**[v0.5.1 — 时序审计与 Flash 回归](releases/v0.5.1/README.md)**，S5 已获整体上板确认，S6 长稳按用户决定跳过。

开发中的 **[v0.5.2 S2](releases/v0.5.2/README.md)**：local.1 上板出现正常卡先 0 后 F；local.2 实测 `11000F` 已定位到 CMD17 成功后的读阶段。[local.3](releases/v0.5.2/v0.5.2-s2-local.3/README.md) 采集读错误与 CRC，尚未确认根因或修复。单 PLL 输出及 SDRAM 频率待定，尚未集成；候选未上传 GitHub。

[下载正式版 bit](releases/v0.5.1/demo.bit) · [v0.5.2 候选与验收](releases/v0.5.2/v0.5.2-s2-local.1/BOARD_VALIDATION.md) · [固化指南](docs/flash_boot/S3_FLASH_GUIDE.md) · [v0.5.1 归档](docs/history/2026-10-06/v0.5.1/README.md)。

目录入口：[统一文档](docs/README.md) · [版本产物规则](releases/README.md) · [构建与诊断归档](diagnostics/README.md)。

基于Anlogic EG4S20BG256，从TF卡读取BMP，经SDRAM双缓冲输出640×480 HDMI视频与48kHz双声道图片琶音。实际显示提交后提示一次，音量128；两颗PLL、五个时钟域分别同步释放复位。

上一正式版本：[v0.5.0](releases/v0.5.0/README.md)。历史HDMI升级已结项，相关资料见[历史索引](docs/ARCHIVE_INDEX.md)。

## 使用方式

| SW2 SW1 | 模式位 | KEY1 | KEY2 |
|---|---|---|---|
| 00 | 0 图片 | 上一张 | 下一张 |
| 01 | 1 亮度预留 | 不产生新请求 | 不产生新请求 |
| 10 | 2 对比度预留 | 不产生新请求 | 不产生新请求 |
| 11 | 3 缩放预留 | 不产生新请求 | 不产生新请求 |

KEY4单击切换MAN/AUTO。复位默认MAN，扫描完成且图片多于一张时允许切换AUTO。三个按键20ms消抖，长按不连发；图片首尾循环。

v0.5.2 开发候选中 KEY2 改为短按松手翻图；任何模式长按 2 秒重初始化及重扫，松手不翻图。恢复保留旧图，新首图完整提交后提示一次并回 MAN；初始化/扫描为 0/2、无图 E、通信失败 F，失败可再次长按。此行为尚待上板确认，正式 v0.5.1 不含此恢复功能。

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

当前正式下载：[v0.5.0固定bit](releases/v0.5.0/demo.bit) · [版本说明](releases/v0.5.0/README.md)。沿用已固化候选，无需重新下载。

使用Tang Dynasty 6.2打开`TD_project/demo.al`，器件EG4S20BG256、顶层top，依次综合、布局布线、生成bitstream。命令行入口为`diagnostics/run_td_build.ps1`；复现已验收布局参数见[源清单](releases/v0.5.0/source_inventory.md)，GUI默认策略不同。运行目录`TD_project/demo_Runs/phy_1/demo.bit`会被新构建覆盖，上板使用版本目录中的固定文件。

[交接记录](HANDOFF.md) · [验证状态](docs/VALIDATION_STATUS.md) · [诊断入口](diagnostics/README.md) · [历史索引](docs/ARCHIVE_INDEX.md)。

## 验证状态与范围

v0.5.0已由用户整体上板确认，仿真与TD证据沿用S2候选。资源3926 LUT、2902寄存器、4 BRAM、4 DSP、2 PLL；Setup −6.565ns、Hold +0.003ns，64个SDRAM接口及3个旧内存内部负端点仍在，全局未收敛。

500ms无进展超时覆盖扫描、读头、写应答和像素等待；SD初始化、源解析结束后的最终内存写完成/显示确认、免复位热插拔恢复仍不在该范围。用户曾报告的SD初始化/复位问题仍按历史边界保留；不宣称Flash启动改造已解决SD协议恢复。

本版不包含OSD、亮度/对比度调节或缩放。预留参数B初值0、范围−128..127；C初值128、范围0..256、至少9位，作为后续需求记录。
