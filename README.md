# 当前版本：v0.31.0 首启讲解等待显示器亮屏正式版

首次上电进入宣传模式时，讲解等 HDMI 输出满 240 帧（约 4 s）再开始，显示器亮屏后能听到第一句；首图仍约 0.94 s 出现，翻页和切换不受影响。17777 LUT（90.70%），Setup +0.252 / Hold +0.011 ns。卡不用换，**烧 Flash**。

[正式 bit 及说明](releases/v0.31.0/README.md) · [归档](docs/history/2026-10-24/boot-narration-v0.31/README.md)

# v0.30.0 开机加速正式版

FPGA 上电从 Flash 读位流的时钟由 TD 默认 2.5 MHz 改为 16 MHz（计算约 2.2 s → 0.34 s），RTL 和布局布线与 v0.29.0 相同。实测复位释放到第一帧输出 941 ms；开机慢主要是显示器识别 HDMI 信号，换更大更好的显示器反而更慢。卡不用换，**必须烧 Flash**。

[正式 bit 及说明](releases/v0.30.0/README.md) · [计划](docs/开机加速v0.30分阶段计划.md) · [归档](docs/history/2026-10-24/fast-boot-v0.30/README.md)

# v0.29.0 场景底图与泥石流特效正式版

本版有三处改动：地震灾后页的房屋改为倒塌损坏，并加了灰尘；泥石流四页的掩膜重新对齐，泥流冲过小桥、流出画面，桥下整片被覆盖；泥石流特效由半透明泥色改为浑浊泥浆夹带石块，不再和山洪相似。LUT 从 17571 增至 17623（89.91%）。**要换卡上 `情景模式/` 里 debris_village 和 quake_village 的 10 个 BMP。**

[正式 bit 及说明](releases/v0.29.0/README.md) · [计划](docs/场景底图与泥石流特效v0.29分阶段计划.md) · [归档](docs/history/2026-10-24/scene-art-debris-v0.29/README.md)

# v0.28.0 宣讲模式科普内容重构正式版

宣讲模式 4 页重做，一页讲一种灾害，和情景四卡对应：滑坡、泥石流、山洪、地震。每页用真实案例开场，画面是漫画插画，上面直接标出征兆、往哪跑、别怎么跑，最后是口诀；配音改用 MiniMax。字库从 276 字扩到 292 字。17543→17571 LUT（89.65%）。**要换卡上 `宣讲模式/` 的 9 个文件，并且和 bit 一起换。**

[正式 bit 及说明](releases/v0.28.0/README.md) · [计划](docs/宣传模式科普内容重构v0.28分阶段计划.md) · [内容包](tools/publicity/geohazard_v28/README.md) · [归档](docs/history/2026-10-23/publicity-content-v0.28/README.md)

# v0.27.0 SW4 独立调节面板正式版

在 v0.26（宣讲底部白色对称波形）上新增拨码开关 SW4（C5）：任何模式下拨上，右侧滑出中文调节面板，调亮度、对比度、音量（到 200%）、波形显示/高度/渐变、场景播放速度、状态栏/字幕/淡入开关和全部重置。SW1/SW2 的 01、10 当作 00；修复宣讲第 1 页字幕残留。逻辑资源 16730→17543 LUT（85.4%→89.5%）。卡不用换。

[正式 bit 及说明](releases/v0.27.0/README.md) · [计划](docs/独立调节面板v0.27分阶段计划.md) · [归档](docs/history/2026-10-23/adjust-panel-v0.27/README.md)

# v0.26.0 宣讲底部白色对称波形

宣讲模式底部的紫色竖条改为白色、中线对称、cos² 包络的波形，下面加蓝色渐变。板测通过后直接合入 main，未单独出正式版。

[候选说明](releases/v0.26.0/s1-local.1/README.md) · [计划](docs/对称音频波形v0.26分阶段计划.md)

# v0.25.0 A 项目功能移植正式版

在 v0.24.0 上加入参考项目 A 的功能：四张灾害卡的真人旁白和分阶段文字、旁白播完才自动换阶段、点选标注工具和制卡教程、照 A 版式的场景 OSD（右上角面板和进度条、左下图例、整段旁白字幕）。逻辑资源 16926→16796 LUT（86.4%→85.7%）。需要配新卡 s5-card.2（旧卡仍兼容）。

[正式 bit 及说明](releases/v0.25.0/README.md) · [计划](docs/A项目功能移植v0.25分阶段计划.md) · [OSD 渲染预览](diagnostics/lut_opt25/osd_preview/README.md) · [标注工具说明](docs/场景标注工具使用说明.md) · [滑坡卡教程](docs/滑坡卡制作教程.md) · [归档](docs/history/2026-10-22/a-port-v0.25/README.md)

# v0.24.0 LUT 资源裁减正式版

功能与 v0.23 相同，逻辑资源 18183→16926 LUT（92.8%→86.4%）、寄存器 12119→10081、DSP 13→12，并修复 SD 初始化/扫描两处由组合译码驱动异步复位引起的布局相关启动故障。沿用当前 SD 卡。

[正式 bit 及说明](releases/v0.24.0/README.md) · [计划](docs/LUT资源裁减v0.24分阶段修改计划.md) · [板测与根因](docs/LUT资源裁减v0.24-S3板测反馈.md) · [归档](docs/history/2026-10-21/lut-reduction-v0.24/README.md)

## 历史开发状态

# 当前开发阶段：四宫格与开机加速本地通过

SW3四宫格只加载四张256×192缩略图，旧卡回退PIC1；确认检查四阶段图头，完整PIC1显示后进入，其余后台加载。开机优先完整宣传首图，随后准备字幕、字库、声音和后续图片，首次直接出图。

[固定bit及使用](releases/v0.23.0/s2-local.1/README.md) · [验证](releases/v0.23.0/s2-local.1/VALIDATION.md) · [计时与资源](docs/四宫格与开机加速计时及资源说明.md) · [本地归档](docs/history/2026-10-19/thumbnail-fast-start/README.md)。88份有效仿真日志、8项资源测试及完整TD通过：Setup +0.046ns / Hold +0.085ns，STNS/HTNS=0。新资源包已生成，本轮未写卡。实板速度与视觉/听审待测；1s/1.5s/2s为目标，无board标签、未正式发布或合main。

## 历史开发状态

# 当前开发阶段：宣传黑色宋体字幕本地通过

字幕改为黑色宋体、16增至21像素（约+31%）、取消底框，保留完整讲解滚动和最大波形上方9行间距，仅宣传显示。已更新TF卡宣讲目录的TEXT.BIN，读回逐字节一致，其余49应用媒体文件逐字节未变。需配套烧录新bit并更新TEXT，重插卡/KEY3复位。

[固定固件及使用](releases/v0.22.0/s1-local.1/README.md) · [验证](releases/v0.22.0/s1-local.1/VALIDATION.md) · [计划](docs/宣传黑色宋体字幕计划.md) · [S1归档](docs/history/2026-10-19/publicity-black-song-font/README.md)。9项本轮仿真及完整TD通过，Setup +0.023ns / Hold +0.004ns，STNS/HTNS=0。实板待反馈，未正式发布或合main。

## 历史开发状态

# 当前开发阶段：宣讲全文滚动字幕已补卡，固件本地通过

原目录分支 `feature/publicity-narration-subtitles`。新增四页599字完整语音字幕，显示于最大波形上方；仅宣讲显示，随播放滚动，换页/重播从头。G:\宣讲模式\TEXT.BIN 已写入并读回一致，其余49媒体逐字节未变。**需烧录新固件后重插卡/KEY3复位才生效**。

[固定固件与使用](releases/v0.21.0/s1-local.1/README.md) · [验证](releases/v0.21.0/s1-local.1/VALIDATION.md) · [计划](docs/宣讲完整语音字幕计划.md) · [S1归档](docs/history/2026-10-19/publicity-narration-subtitles/README.md)。25项仿真通过；完整TD Setup +0.055ns/Hold +0.024ns、TNS0。实板待反馈，未正式发布或合main；按整段语音时长配速，未做逐字时间戳。

## 历史开发状态

# 当前开发阶段：底部音频波形 S1 本地通过、板测待验收

原目录分支`feature/bottom-audio-waveform`。已将宣讲圆环替换为铺满640像素图片底部的80根紫色音量竖条；宣讲字幕上移，情景/预警/预览/菜单隐藏波形。四张宣讲图去掉来源、版本和圆环占位区。

[固定固件、四图及预览](releases/v0.20.0/s1-local.1/README.md) · [验证](releases/v0.20.0/s1-local.1/VALIDATION.md) · [计划](docs/底部音频波形修改计划.md)。22项仿真通过；TD Setup +0.106ns/Hold +0.037ns、TNS0，17438 LUT、36 BRAM9k。需要同时更新bit和四张EDU图片，现有声音/字库/情景资源保留；本轮未写外接盘。未获板测确认，未正式发布或合并main。

## 历史开发状态

# 灾害 S2 本地通过、板测待验收

原目录分支 `feature/mountain-disaster-selector`，基线 `7e3ac02`。S1 选择性移植后，S2 已接入 SW3=C6 四类中文菜单、真实长目录扫描和独立缓存；保留双应用、音频、字幕、参数、预警、阶段预览及数码管。UART 两项默认关闭。KEY1/KEY2 选择，KEY4 确认，未确认拨回 0 取消；KEY3 仍复位。

[S2 固定候选与 bit](releases/v0.19.0/s2-local.1/README.md)：17525 LUT、11760 寄存器、57 BRAM9k、2 BRAM32k、14 DSP；DSP 相对基线 +1、相对 S1 -12。Setup +0.047ns / Hold +0.030ns，STNS/HTNS 均 0，120 份仿真及 86 份编译/模型日志通过。[S1 候选](releases/v0.19.0/s1-local.1/README.md) 保留。

[操作与板测](docs/灾害SW3操作与板测.md) · [分阶段计划](docs/灾害移植与SW3选择分阶段计划.md) · [验证](releases/v0.19.0/s2-local.1/VALIDATION.md) · [交接](HANDOFF.md)。未建立 board 标签、未正式发布或合并 main。

## 历史开发状态

# 当前开发阶段：灾害 S1 本地通过，实施 SW3 菜单 S2

原目录分支 `feature/mountain-disaster-selector`，基线 `7e3ac02`。四类图层与 BMP 类型已接入，保留旧编码及双应用。[S1 固定候选与 bit](releases/v0.19.0/s1-local.1/README.md)：15780 LUT、10878 寄存器、52 BRAM9k、2 BRAM32k、26 DSP；DSP 相对基线 +13，Setup +0.129ns/Hold +0.012ns、TNS0。45 份仿真通过，板测待验收。UART 两项默认关，SD 调试保留。

[分阶段计划](docs/灾害移植与SW3选择分阶段计划.md) · [验证](releases/v0.19.0/s1-local.1/VALIDATION.md) · [交接](HANDOFF.md)。S2 接入 SW3=C6 四宫格、实际长目录与独立缓存。未发布、未合并 main，无 board 标签。

## 历史开发状态

# 当前开发阶段：UART 资源裁减 S1，本地通过，待上板

已按用户选择默认关闭串口日志和串口在线字幕，保留数码管 SD 调试页、固定/TEXT.BIN 字幕及双模式功能。LUT 16022→14092（减少1930，12.05%）；寄存器10686→9530（减少1156）；BRAM9k 56→46（释放10块）；BRAM32k和DSP不变。完整TD `uart_reduction_td_attempt05`：14092 LUT（71.90%）、9530寄存器、46 BRAM9k、2 BRAM32k、13 DSP；Setup +0.040ns/Hold +0.019ns，STNS/HTNS均0；11份本轮仿真/20份编译模型日志通过，实际模型边界和既有时序例外见[验证](releases/v0.18.0/uart-s1-local.1/VALIDATION.md)。

[固定候选与bit](releases/v0.18.0/uart-s1-local.1/README.md) · [板测步骤/真实记录](releases/v0.18.0/uart-s1-local.1/BOARD_RESULT.md) · [计划](docs/UART资源裁减分阶段计划.md) · [交接](HANDOFF.md)。标签 `v0.18.0-uart-s1-local.1`，原目录分支 `feature/uart-resource-reduction`。恢复UART须同步恢复SDC对应的TX/RX约束，详见候选说明。

本候选未获板测确认；M6内容/完整听审、≥40分钟及整机计时继续待办。硬件回退M5 board.1原bit，正式回退v0.16.0；未发布、未合并main。

## 历史交付：v0.18.0 宣传模式 M6 local.1（验收仍待办）

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
