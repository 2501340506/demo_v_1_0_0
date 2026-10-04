# 安路 EG4 HDMI 图片播放器

已验收版本：**[v0.2.0](https://github.com/xier1-droid/anlogic-eg4-hdmi-bmp-player/tree/v0.2.0)**，2026-10-04。当前开发分支：`feature/hdmi-audio-v0.3.0`，不自动合并main。

当前开发沿R2计划推进：S0/S1为已验收基线，S3独立EDID取消；S2和S5模块验证完成，S4、S6、S7、S8均已上板通过并推送。S9旧链路清理和分域复位已完成仿真及TD构建，等待上板后发布v0.3.0。[完整阶段计划](docx/HDMI音频分阶段修改计划.md)。

基于 Anlogic EG4S20BG256，从TF卡读取BMP图片，使用SDRAM双缓冲输出640×480 HDMI视频和48kHz双声道图片琶音。实际显示提交后触发一次提示音，音量固定128。S9候选移除旧音频PLL/I2S/AXIS及官方加密HDMI依赖，保留系统/视频两颗PLL，五个时钟域各自同步释放复位；最近已验收节点为S8。

当前候选：[S9固定产物与验证结果](releases/v0.3.0-r2-s9-local.1/README.md) · [S9上板验证文档](releases/v0.3.0-r2-s9-local.1/BOARD_VALIDATION.md)。完成至少5轮上电/复位、图片操作及10分钟音视频验证后反馈。全局时序仍未收敛，详细路径对比已随候选保存。

## 使用方式

| SW2 SW1 | 模式位 | KEY1 | KEY2 |
|---|---|---|---|
| 00 | 0 图片 | 上一张 | 下一张 |
| 01 | 1 亮度预留 | 不产生新请求 | 不产生新请求 |
| 10 | 2 对比度预留 | 不产生新请求 | 不产生新请求 |
| 11 | 3 缩放预留 | 不产生新请求 | 不产生新请求 |

KEY4单击切换MAN/AUTO。复位默认MAN，扫描完成且图片多于一张时允许切换AUTO。三个按键20ms消抖，长按不连发；图片首尾循环。

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

- [S7待上板正弦音候选](releases/v0.3.0-r2-s7-local.1/demo.bit)
- [S6已验收静音恢复产物](releases/v0.3.0-r2-s6-local.1/demo.bit)
- [S4已验收恢复产物](releases/v0.3.0-r2-s4-local.1/demo.bit)
- [S1恢复用固定bitstream](releases/v0.3.0-s1-local.1/demo.bit)
- [中文版本说明及构建报告](releases/v0.2.0/README.md)
- [交接记录](HANDOFF.md)、[归档索引](docs/ARCHIVE_INDEX.md)、[合并审核说明](docs/V0_2_0_MERGE_REVIEW.md)

使用Tang Dynasty 6.2打开 `TD_project/demo.al`，选择器件EG4S20BG256、顶层 `top`，依次综合、布局布线、生成bitstream。运行产物 `TD_project/demo_Runs/phy_1/demo.bit` 会被后续构建覆盖，当前恢复使用 `releases/v0.3.0-s1-local.1/demo.bit`，不使用旧 `best_result` 产物。

## 验证状态与范围

S8已获用户整体上板确认；当前S9通过完整ModelSim回归与TD构建，包括顶层五组复位/失锁恢复、图片控制/面板/异步缓冲、PCM、封装及真实视频/ODDR。PLL为2个，STA覆盖99.86%，像素→串行跨域已纳入分析且为正；Setup WNS −6.565ns，剩余64个SDRAM接口违例，全局未收敛。S9上板和正式v0.3.0发布待完成。详见[验证状态](docs/VALIDATION_STATUS.md)。

本版不包含OSD、B/C调节和图像处理、缩放。B初值0、范围−128..127；C初值128、范围0..256、至少9位，仅记录为后续需求。

S5独立封装及双PCM源接口已完成，详见[模块交付与仿真证据](releases/v0.3.0-r2-s5-local.1/README.md)。S5无新bit或上板要求；S6已接入新核心，预期正常图片及静音，详见[上板验证文档](releases/v0.3.0-r2-s6-local.1/BOARD_VALIDATION.md)。

S6已获用户上板确认；S7仿真及TD构建完成，等待双声道和连续10分钟验证。全局时序未收敛，详见[S7交付](releases/v0.3.0-r2-s7-local.1/README.md)与[上板文档](releases/v0.3.0-r2-s7-local.1/BOARD_VALIDATION.md)。
