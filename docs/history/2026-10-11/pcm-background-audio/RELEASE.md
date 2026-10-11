# v0.12.0 正式版

TF 卡 PCM 循环背景音乐及 SD 初始化超时恢复已完成验收。用户确认功能正常、运行 20 分钟、Flash 烧录与完全断电冷启动通过。

下载：[demo.bit](demo.bit)。复用 S3 local.2 已验收原 bit（629,624 字节），未修改生产源码或重新构建。基线 v0.11.0；回退：[v0.11.0/demo.bit](../v0.11.0/demo.bit)。

将 48kHz、16bit、有符号小端、单声道裸 PCM 文件命名为 `BGM.PCM`，放入 FAT32 TF 卡根目录。可使用项目 tools/make_audio_corpus.py 转换，现有试听文件为 tools/BGM.PCM。扫描和预填充后自动循环，左右声道相同、固定音量 128/256；切图、AUTO、转场不重启音乐。无音乐时恢复原图片琶音和提示音，播放音乐时不混提示音。支持碎片文件和仅音频卡。

初始化单轮超时 2000ms 后最多额外恢复三次，每轮重新发送 88 个启动时钟并从 CMD0 开始；无卡约 8 秒后停止报错。该机制已通过功能板测，但原偶发故障的物理根因未确定。保留既有字幕、计时和按键含义；不支持 WAV 硬件解析、播放列表及播放控制。

[最终验证](FINAL_VALIDATION.md) · [S4 结果](S4_BOARD_RESULT.md) · [构建报告](s3-local.2/reports/final_timing.rpt) · [源码清单](SOURCE_MANIFEST.md) · [历史归档](../../docs/history/2026-10-11/pcm-background-audio/README.md)。阶段候选、失败构建与原有工具提示保留。
