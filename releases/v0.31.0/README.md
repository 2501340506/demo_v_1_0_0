# v0.31.0 — 首启讲解等待显示器亮屏正式版

基线 v0.30.0。问题：首次上电进入宣传模式，画面亮起时讲解已经播了一段。原因是显示器识别 HDMI 约 2 s（v0.30 结论），而首图约 0.94 s 就提交，讲解紧接着开始。

正式文件：[demo.bit](demo.bit)，677358 字节。直接复用板测通过的 [s1-local.2](s1-local.2/README.md)，没有重新构建，两份逐字节一致。来源：源码 `5a5be55`，构建 `diagnostics/output/v31b_s3`，Seed 3，Flash 加载 16 MHz。

**烧 Flash 后冷启动使用。卡不用换。**

## 改动

只改 `sd_card_bmp.v` 的 `publicity_voice_control`：

- 新参数 `BOOT_FRAMES=240`（约 4 s）。复位后数 HDMI 帧，数满之前第一次讲解请求停在 WAIT；数满后计数停止，不再生效。
- 首图早于 4 s 提交时讲解在第 240 帧开始，晚于 4 s 时立即开始。首图最短 5 s 停留从讲解开始计，首启首图约停 9 s。
- 翻页、切换应用、AUTO、退出再进入宣传不受影响；BIN 加载的 busy 等待照旧。
- 换显示器后若需调整，改 `BOOT_FRAMES` 重新构建；8 位计数，最大 255 帧（约 4.25 s）。

## 资源与时序

17777 LUT（90.70%），Setup +0.252 ns / Hold +0.011 ns，STNS/HTNS=0。

同一源码共跑 7 个种子，只有 Seed 3 通过；其余在 `sd_card_clk` 域有 Hold 或 Setup 违例。这个域余量很紧，常数级改动也会让布局结果波动，后续改 RTL 需多跑种子，或单独做时序处理。

## 验证

- 仿真：新增 `diagnostics/boot_narration/tb_boot_narration.sv`；回归 `tb_m4_auto`、`tb_voice_equivalence`、整机控制器 case0/16/18/19（AUTO）全部通过。整机仿真一帧只有 100 时钟，实际 4 s 时长由上板确认。
- 上板：s1-local.1（180 帧）用户反馈讲解仍早约 1 s，未通过；s1-local.2（240 帧）通过（2026-10-24，用户反馈“功能正常，首图音频效果满意”）。没有次数和计时数据。

## 回退

对 [v0.30.0 demo.bit](../v0.30.0/demo.bit) 执行 Program Flash 并校验。
