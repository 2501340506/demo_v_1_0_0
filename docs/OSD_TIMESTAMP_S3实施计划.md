# v0.10.0 S3：右上角累计 MM:SS

基线 v0.10.0-s2-board.1，原目录 feature/osd-gap-analysis；阶段回退 releases/v0.10.0/s2-local.1/demo.bit，总回退 v0.9.1/demo.bit。用户已确认 S2 功能正常并要求进入本阶段。

timestamp_osd 复用 osd_pixel_position 和 osd_font_5x7；默认 x=500..579、y=8..23，白色，16×16 字符单元，组合 RGB 叠加。每 60 个 VS 下降沿计 1 秒，复位清零，BCD 四位计数至 99:59 后回到 00:00；只在帧边界变化。一秒按 60 帧定义，不接 RTC，实际墙钟精度依赖视频帧率。

生产顺序为状态 → 字幕 → 时间 → 原底条 → HDMI 音频。默认不新增时间底条，glyph_active 汇总三层。顶层 TIMESTAMP_ENABLE 默认 1，0 时生成旁路、不实例化计时/字模硬件；OSD_ENABLE 同样控制该层。SDRAM、字幕协议和音频提交不变。

验证：复位、59/60 帧边界、所有秒进位及 99:59 回绕、帧内稳定、逐像素字模和区域外透传、禁用旁路；真实 SDRAM 系统同时开启三种文字和底条，运行原 21 项回归与完整 TD/时序审计。归档递增 v0.10.0-s3-local.N；用户板测确认后才建立 board 标签和正式结项。
