# v0.13.0 正式版：彩色圆形音频可视化

[下载 demo.bit](demo.bit)（654068字节）。正式版复用已验收的s2-local.2原bit，与候选逐字节一致，未重新构建。基线v0.12.0；回退[v0.12.0/demo.bit](../v0.12.0/demo.bit)。

屏幕右侧偏下、圆心(520,310)显示黑色圆环和96根彩色圆头柱条，圆心透出原图片。柱条沿圆周六色渐变，随实际HDMI音频幅度跳动；静音缓慢回落。支持背景音乐和无BGM时的原琶音/提示音，不覆盖顶部状态、时间或底部字幕。有有效图片才显示。

这是音量波形环，不是FFT频谱。TF卡音乐格式、按键和UART接口沿用v0.12.0；独立编译参数AUDIO_VIS_ENABLE可关闭圆环。

用户已确认S2功能全部通过，并在S3三项验收要求后确认全部通过：持续播放20分钟、Flash烧录、完全断电冷启动。未补造额外时长或次数。

[彩色预览](s2-local.2/preview/music.gif) · [最终验证](FINAL_VALIDATION.md) · [S2板测](s2-local.2/BOARD_RESULT.md) · [S3板测](S3_BOARD_RESULT.md) · [源码清单](SOURCE_MANIFEST.md) · [构建报告](s2-local.2/reports/final_timing.rpt) · [归档](../../docs/history/2026-10-12/circular-audio-visualizer/README.md)。

报告保留既有厂商模型、SDRAM ECO、局部时钟及ROM推断提示。最终Setup +0.010ns、Hold +0.036ns，约束未放宽。旧候选和标签保留。
