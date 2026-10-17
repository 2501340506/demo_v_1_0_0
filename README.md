# 当前开发阶段：v0.18.0 宣传模式 M6，等待内容听审与整机实测

用户确认“M5无误”，已记录并推送 `v0.18.0-m5-board.1`。M6在原目录 `feature/science-publicity-mode` 制作四页科普内容、四段本机普通话合成讲解（合计约175秒）及两套双模式整卡；[内容、四段试听及整卡](tools/publicity/geohazard_release/README.md)。旧M1测试音保留，G:\原卡未改。新素材已反读并逐字节复现，最终RTL回归49份仿真/52份编译模型日志核验通过，实际范围见[本版验证](releases/v0.18.0/m6-local.1/VALIDATION.md)。

M6不改RTL/工程，复用[M5已确认原bit](releases/v0.18.0/m6-local.1/demo.bit)及TD27报告，111个工程输入、根构建脚本和bit逐字节核对相同，未重新TD。候选 `v0.18.0-m6-local.1` 的[交付入口](releases/v0.18.0/m6-local.1/README.md)与[完整操作、板测及计时口径](docs/宣传模式M6整机验收.md)已准备；四页专业内容审阅、四段完整听审、≥40分钟连续运行、冷启动、双向切换、换卡复位数据仍待用户填[真实结果](releases/v0.18.0/m6-local.1/BOARD_RESULT.md)。软件校验与M5总体反馈均不代替本次验收。

开发回退 `v0.18.0-m5-board.1` 及其原bit，正式回退 `v0.16.0`。本期验收完成且用户明确确认发布后，才复用验收bit发布 `v0.18.0`、归档、合并main并回填实测数据。当前未发布、未合并，不补前序结论。最新状态见[交接](HANDOFF.md)。

## 历史交付：v0.18.0 宣传模式 M5 local.1

原目录分支 `feature/science-publicity-mode`，输入M4 local.1（eb7deb3）/board.1（e548d72）。用户已确认“M4功能正常”，复用M4原bit记录总体确认。M5完成参数页与B/C/V优先级、应用身份保持、非00 AUTO门控及当前资源预览；修正情景11焦点路由，选中经原情景事务同步图片、阶段和音频，同页重播、退出预警。

183份仿真及69份编译/模型日志核验通过；TD `publicity_m5_td_attempt27`：16022 LUT（81.74%）、10686寄存器、56 BRAM9k、2 BRAM32k、13 DSP；Setup +0.006ns/Hold +0.030ns，TNS0，STA覆盖率99.97%，无ERROR、完整bitgen。固定[候选与bit](releases/v0.18.0/m5-local.1/README.md)，标签`v0.18.0-m5-local.1`。完整生产top核对实际BMP/scaler写像素、最终RGB/时序/TMDS和逐样本PCM/HDMI音频，模型及采样窗口边界见[验证](diagnostics/publicity_mode/M5_VALIDATION.md)。

按[完整操作与板测](docs/宣传模式操作与板测.md)上板并填写[真实结果](releases/v0.18.0/m5-local.1/BOARD_RESULT.md)；M5板测待确认、无board标签，M6未执行。开发回退为已获总体确认的[M4固定bit](releases/v0.18.0/m4-local.1/demo.bit)，正式回退v0.16.0。M1四VOI仍是2/6/8/10秒无人声测试音，正式配音与专业内容审阅留M6；前序v0.17.0/M6未确认项不补结论。 计划与接口见[阶段计划](docs/专业科普宣传模式分阶段修改计划.md)、[接口清单](docs/宣传模式接口清单.md)、[交接](HANDOFF.md)。

## 前序候选：v0.17.0 M6 local.1 本地通过，待板测

M6 制作示意村、山洪村双卡，落实黑色放大文字、居中红色缩放预警及警报音。拨码 `00` 下 KEY4 短按恢复 AUTO、长按一秒进入/退出场景；场景 KEY1 短按预警、长按一秒切换 1X/2X/4X；KEY2 下一阶段、长按两秒重扫。场景 AUTO 等动画终态显示后才切阶段，进入场景继承原 AUTO，退出后 AUTO 关闭。

已固定 [M6 候选与双卡](releases/v0.17.0/m6-local.1/README.md)，标签 `v0.17.0-m6-local.1`。118 份仿真、36 份编译日志、19 项 PC 测试通过；TD 15083 LUT（76.95%），Setup +0.101ns/Hold +0.019ns，无 ERROR、完整 bitgen。见 [M6 计划](docs/M6_IMPLEMENTATION.md)、[整机板测清单](releases/v0.17.0/m6-local.1/BOARD_VALIDATION.md) 和 [交接](HANDOFF.md)。历史 [M5 候选](releases/v0.17.0/m5-local.1/README.md) 保留。

M4 已获用户总体反馈“暂无大问题”，board.1 及 M4 分支/local/board 标签已推送。M5/M6 板测、M1/M3 单独板测、M2 目视及旁白关键词同步仍待确认。正式版和整机回退仍为 v0.16.0；M6 须完成 ≥40 分钟连续运行及真实计时，经用户确认再发布、归档与合并 main。TD GUI 请重新加载磁盘工程后再保存。

# 当前正式版：v0.16.0

功能与 v0.15.0 相同，LUT 优化后 15402→14190 LUT、DSP 15→13，为后续功能留出余量。S1、S2 板测均获用户确认，S2 Flash 冷启动运行 40 分钟正常。复用 s2-local.1 原 bit。

[下载与使用](releases/v0.16.0/README.md) · [最终验证](releases/v0.16.0/FINAL_VALIDATION.md) · [历史归档](docs/history/2026-10-14/lut-optimization/README.md)。回退 v0.15.0。

## 历史记录

# 当前正式版：v0.15.0

亮度、对比度与总音量调节完成：SW2/SW1=01/10 调画面参数，KEY4 切换总音量，参数条显示 B/C/V。S2 功能及 S3 Flash 持续运行 20 分钟、完全断电冷启动均获用户确认。复用 s2-local.1 原 bit。

[下载与使用](releases/v0.15.0/README.md) · [最终验证](releases/v0.15.0/FINAL_VALIDATION.md) · [历史归档](docs/history/2026-10-13/brightness-contrast-volume/README.md)。回退 v0.14.0。

## 历史记录

# 当前正式版：v0.14.0

图片等比缩放与四宫格缩略图已完成，S3 功能及 S4 持续运行 20 分钟、Flash、完全断电冷启动均已获用户确认。复用 local.3 原 bit。

[下载与使用](releases/v0.14.0/README.md) · [最终验证](releases/v0.14.0/FINAL_VALIDATION.md) · [历史归档](docs/history/2026-10-13/image-scaling-thumbnails/README.md)。回退 v0.13.0。大图首次加载仍顺序读取完整文件。

## 历史记录

# 当前开发阶段：v0.14.0 S3 功能板测通过

S3 local.3 已获用户确认功能均正常，记录 board.3。固定候选及板测结果见 [S3 说明](releases/v0.14.0/s3-local.3/README.md) 和 [板测记录](releases/v0.14.0/s3-local.3/BOARD_RESULT.md)。目前分析大图首次加载耗时；S4 持续播放、Flash 和完全断电冷启动尚待验收，正式版仍为 v0.13.0。

[候选 bit 与说明](releases/v0.14.0/s2-local.1/README.md) · [测试图片及参考图](releases/v0.14.0/s2-local.1/board_samples.zip) · [板测步骤](releases/v0.14.0/s2-local.1/BOARD_VALIDATION.md) · [阶段计划](docs/图片缩放与缩略图分阶段修改计划.md) · [交接](HANDOFF.md)。

# 当前正式版：v0.13.0

彩色圆形音频可视化已完成S2功能和S3持续播放20分钟、Flash及完全断电冷启动验收。正式版复用已验收local.2原bit，未重建。

[正式下载与说明](releases/v0.13.0/README.md) · [最终验证](releases/v0.13.0/FINAL_VALIDATION.md) · [彩色预览](releases/v0.13.0/s2-local.2/preview/music.gif) · [归档](docs/history/2026-10-12/circular-audio-visualizer/README.md)。回退releases/v0.12.0/demo.bit。

## 历史记录

# 当前阶段：v0.13.0 S3（S2彩色柱条已通过板测）

用户确认彩色候选local.2功能全部通过，记录v0.13.0-s2-board.2。S3继续使用同一bit，待20分钟持续播放、Flash烧录和完全断电冷启动结果；本次未改源码或重新构建，正式版仍为v0.12.0。

[S3验收说明](releases/v0.13.0/S3_VALIDATION.md) · [S2板测记录](releases/v0.13.0/s2-local.2/BOARD_RESULT.md) · [已验收bit](releases/v0.13.0/s2-local.2/demo.bit) · [交接](HANDOFF.md)。

## 历史交付：v0.13.0 S2 local.2（彩色柱条）

柱条已改为沿圆周六色渐变，随真实声音跳动。颜色/像素/OSD/音乐专项及完整TD通过（Setup +0.010ns、Hold +0.036ns），尚未上板确认。[新候选下载](releases/v0.13.0/s2-local.2/README.md) · [彩色动态预览](releases/v0.13.0/s2-local.2/preview/music.gif) · [交接](HANDOFF.md)。

## 历史白色候选：v0.13.0 S2 local.1

新增右下圆形音量波形环：96根白色圆头柱随实际HDMI音频跳动，黑环中间透出原图片。音频/像素/OSD专项、21项回归、582帧系统仿真及完整TD通过，Setup +0.101ns、Hold +0.004ns。尚未上板确认，正式版仍为v0.12.0。

[候选下载与上板说明](releases/v0.13.0/s2-local.1/README.md) · [音乐仿真预览](releases/v0.13.0/s2-local.1/preview/music.gif) · [验证记录](releases/v0.13.0/s2-local.1/VALIDATION.md) · [阶段计划](docs/圆形音频可视化分阶段计划.md) · [交接](HANDOFF.md)。开发分支feature/circular-audio-visualizer，等待S2板测后进入S3。

# 当前正式版：v0.12.0

TF 卡 PCM 循环背景音乐和 SD 初始化超时恢复已验收：功能正常、连续运行 20 分钟、Flash 烧录及完全断电冷启动通过。正式版复用 S3 local.2 原 bit，未重建。

[正式版与下载](releases/v0.12.0/README.md) · [最终验证](releases/v0.12.0/FINAL_VALIDATION.md) · [历史归档](docs/history/2026-10-11/pcm-background-audio/README.md)。将固定格式的 BGM.PCM 放入 FAT32 根目录即可自动循环播放；无音乐时保留原琶音及提示音。

## 历史记录

# v0.12.0 S3 功能通过，进入 S4

用户已确认 local.2 功能通过，记录 `v0.12.0-s3-board.2`；随后确认运行 20 分钟、功能正常。S4 复用同一候选，待确认 Flash 与完全断电冷启动；见 [S4 最终验收](releases/v0.12.0/S4_VALIDATION.md)。本轮未改生产源码或重新构建，尚未正式发布。

S1 共享扇区服务已由用户确认上板通过，local/board 标签及分支已推送。S2 完成 BGM.PCM 扫描、碎片文件循环、跨域缓冲、音源切换和转换工具的独立验证；46 个 RTL 日志、四个模块独立综合和实际音频转换通过。

S3 已接入生产 top：FAT32 根目录 BGM.PCM 自动循环播放，固定 48kHz/16bit/单声道；切图不重启音乐，无音乐时回退原琶音。582 帧系统仿真及 472,955 个 PCM 样本比较通过，TD Setup +0.100ns / Hold +0.004ns。

[修复候选与说明](releases/v0.12.0/s3-local.2/README.md) · [板测结果](releases/v0.12.0/s3-local.2/BOARD_RESULT.md) · [S3 验证](diagnostics/pcm_audio/S3_VALIDATION.md) · [交接](HANDOFF.md)。local.2 为 KEY3 初始化超时新增最多三次完整恢复重试，功能板测已通过；最终验收待反馈，尚未正式发布。

# 当前正式版：v0.11.0（2026-10-11）

图片转场已完成：手动双向淡出淡入，AUTO 黑底从左到右揭示。S1/S2 功能确认通过，S3 实际运行 20 分钟、相关操作通过。正式 bit 复用已验收 S2 原文件，未重新构建；保留当前中文字幕、时间及音频。

[正式版与下载](releases/v0.11.0/README.md) · [最终验证](releases/v0.11.0/FINAL_VALIDATION.md) · [历史归档](docs/history/2026-10-11/image-transitions/README.md)。Flash/完全断电冷启动未单独确认，按实际反馈保留边界。

## 历史记录

# v0.11.0 S2 上板通过，进入 S3（2026-10-11）

用户确认 S2“功能均正常，进入下一阶段”，记录 v0.11.0-s2-board.1。S3 复用 S2 已验收原 bit，源码和工程不变；本轮逐字节核对 bit 一致，不重复构建。

[S2 板测记录](releases/v0.11.0/s2-local.1/BOARD_RESULT.md) · [S3 最终验收步骤](releases/v0.11.0/S3_VALIDATION.md)。下一步反馈实际持续运行时长及 Flash/完全断电冷启动结果；尚未正式发布 v0.11.0，正式版仍为 v0.10.0。

## 历史记录

# v0.11.0 S2 local.1 待上板（2026-10-11）

S1 已由用户确认功能正常，board.1 已记录并推送。S2 新增 AUTO 黑底从左到右揭示，手动保持淡出淡入，保留当前中文字幕、时间和音频。

专项、21 项回归、完整系统仿真及 TD 全部通过：582 显示帧、2 次 AUTO 揭示、15 次手动淡变、22 次提交/提示音；Setup +0.106 ns / Hold +0.021 ns。S2 尚未板测，正式版仍为 v0.10.0。

[固定候选](releases/v0.11.0/s2-local.1/README.md) · [上板步骤](releases/v0.11.0/s2-local.1/BOARD_VALIDATION.md)。S2 确认后进入 S3 最终验收。

## 历史记录

# v0.11.0 S1 local.1 待上板（2026-10-11）

手动双向切图及 AUTO 淡出/淡入已完成本地验证，保留当前中文字幕、时间与音频。完整系统 582 帧、17 次转场、22 次提交/提示音通过；TD Setup +0.117 ns / Hold +0.011 ns。正式版仍为 v0.10.0。

[固定候选](releases/v0.11.0/s1-local.1/README.md) · [上板步骤](releases/v0.11.0/s1-local.1/BOARD_VALIDATION.md)。S1 用户确认前不进入 S2，不建立 board 标签。

## 历史记录

# 当前正式版：v0.10.0（2026-10-10）

固定中文、UART 在线字幕和右上角 MM:SS 已完成。用户确认 S3 运行 20 分钟、功能均正常；正式 bit 直接复用已验收候选，不重新构建。

[正式版与下载](releases/v0.10.0/README.md) · [最终验证](releases/v0.10.0/FINAL_VALIDATION.md) · [归档](docs/history/2026-10-10/v0.10.0/README.md)。以下为历史阶段状态。

## 历史记录

# 当前开发：v0.10.0 S3 时间显示待板测（2026-10-10）

S2 用户确认功能均正常，已记录 board.1。S3 新增右上角白色 MM:SS，每 60 视频帧加一秒，复位清零；保持在线字幕、状态条、底条及音频。专项、真实 SDRAM 联合仿真、21 项回归和 TD 通过；Setup +0.102 ns / Hold +0.019 ns。使用 [S3 固定候选](releases/v0.10.0/s3-local.1/README.md) 与 [上板步骤](releases/v0.10.0/s3-local.1/BOARD_VALIDATION.md)。S3 尚未板测，正式版仍为 v0.9.1。

## 历史记录

# 当前开发：v0.10.0 S2 UART 字幕待板测（2026-10-10）

S1 已确认功能正常。S2 已完成 UART 在线字幕、帧边界提交和日志仲裁，RX F12 / TX D12，115200 8N1。专项、真实 SDRAM 联合仿真、21 项回归和完整 TD 通过；Setup +0.105 ns / Hold +0.067 ns。使用 [S2 固定候选](releases/v0.10.0/s2-local.1/README.md) 及 [串口上板步骤](releases/v0.10.0/s2-local.1/BOARD_VALIDATION.md)。S2 尚未板测，S3 时间显示尚未实施；正式版及总回退仍为 v0.9.1。

## 历史记录

# 当前正式版：v0.9.1（2026-10-10）

OSD 优化已完成 S3 和 S4 验收。用户确认 S4 通过、实际运行 20 分钟功能正常；按该明确结论结项，未记为 30 分钟。正式 bit 复用已验收候选，不重新构建。

[正式版与下载](releases/v0.9.1/README.md) · [最终验收](releases/v0.9.1/S4_VALIDATION.md) · [归档](docs/history/2026-10-10/osd-optimize/README.md)。以下开发阶段状态为历史。

## 历史记录

# 当前开发：v0.9.1 OSD 优化（2026-10-10）

基线 v0.9.0 已合并 main。本轮在 feature/osd-optimize 统一 OSD 坐标/帧事件、参数化滚动并修正底条将原图黄/红/白色误认成文字的问题。视频 RGB888 和时序延迟不变。当前验证进度见 [HANDOFF](HANDOFF.md)，实现合同见 [优化计划](docs/OSD优化实施计划.md)。下方旧版“待上板”等描述属于历史，不代表当前版本状态。

本地专项、系统、回归和 TD 已通过；用户已确认 [v0.9.1-s3-local.1](releases/v0.9.1/s3-local.1/README.md) 功能正常，记录 s3-board.1。现进入 [S4 Flash、冷启动和持续运行验收](releases/v0.9.1/S4_VALIDATION.md)，继续使用同一 bit。

# 最新状态：v0.9.0 S2 local.1 待上板（2026-10-10）

S1 已通过用户验收，分支与 S1 local/board 标签已推送。S2 滚动字幕已完成专项、真实 SDRAM 联合测试、21 项回归及 TD，待用户板测；S3 半透明底条尚未实施。详细证据及固定候选见项目根目录 releases/v0.9.0/s2-local.1/README.md，上板使用该目录 demo.bit。Setup +0.113 ns、Hold +0.030 ns。以下为历史阶段记录。
# 当前正式版：v0.8.0 四 bank 帧缓存

v0.8.0 已发布并合并 main；[正式说明与已验收 bit](releases/v0.8.0/README.md)。

当前开发：v0.9.0 OSD，S1 状态条已完成本地仿真、回归及 TD，等待用户上板。[固定候选](releases/v0.9.0/s1-local.1/README.md) · [上板步骤](releases/v0.9.0/s1-local.1/BOARD_VALIDATION.md)。见 [分阶段计划](docs/OSD字幕叠加分阶段修改计划.md) 和 [当前交接](HANDOFF.md)。滚动字幕和半透明底条分别在 S2/S3，需上一阶段板测通过。

以下为历史版本说明。
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
