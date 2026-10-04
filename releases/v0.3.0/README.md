# v0.3.0 — HDMI音频与四图旋律联动

2026-10-05用户确认S9通过，R2计划结项。Git标签`v0.3.0`，开发分支feature/hdmi-audio-v0.3.0，不自动合并main。发布沿用仓库惯例：Git标签与固定产物，不额外创建GitHub Release页面。

## 本版功能

25MHz像素域生成48kHz双声道PCM，可读HDMI封装输出640×480视频；实际图片提交后触发100ms/1.5kHz提示及四组六音琶音，每音250ms、音量固定128。保留双缓冲、三键、四模式、AUTO及数码管。首图前静音；不实现EDID、音量设置或新的图像处理功能。

S9清理旧I2S/音频PLL/官方加密HDMI/AXIS依赖，保留历史源；系统/视频两颗PLL及五域同步释放复位。像素/串行路径实际纳入STA。

## 固定产物及验收

[demo.bit](demo.bit)，629624字节，沿用用户已验收S9构建（2026-10-05 01:02:06），逐字节一致。本次只更新版本文档、归档和标签，没有修改生产RTL、工程或约束，没有重新构建。

[S9完整仿真/构建证据](../v0.3.0-r2-s9-local.1/README.md) · [上板步骤及用户反馈](../v0.3.0-r2-s9-local.1/BOARD_VALIDATION.md) · [结项归档](../../docs/history/2026-10-05/HDMI音频升级/README.md)。S9为用户整体通过结论，不补造逐项测量。

## 已知问题与范围

复位偶发数码管卡0、扫描/读头阶段拔卡卡2、连续翻图时复位卡0仍未修复。用户明确本版本不修改，且暂不开展相应修改；[分析与复现](../../docs/diagnostics/s9_sd_recovery/analysis.md)仅为后续资料，不属于本版修复成果。

Setup WNS−6.565ns/TNS−294.439ns，Hold+0.004ns，64个SDRAM接口违例仍在；STA覆盖99.86%，像素→串行+6.376ns。全局时序未收敛，板级IO delay仍不完整。资源3301 LUT/2590寄存器/4 BRAM/1 DSP/2 PLL，详见[timing_comparison.md](timing_comparison.md)。

使用本目录固定bit；TD运行目录会被后续构建覆盖。S8恢复对照：[demo.bit](../v0.3.0-r2-s8-local.1/demo.bit)。
