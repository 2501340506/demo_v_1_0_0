# v0.12.0 S2：独立 PCM 模块验证

本目录没有 bit，不是硬件候选。基线 `v0.12.0-s1-board.1`，已完成音频目录发现、文件限流及循环、跨域 PCM 缓冲、音源选择、转换工具的独立验证。

46 个 RTL 仿真日志全部通过，四个模块 TD 独立综合通过，实际 FFmpeg 转换通过。完整说明见 [S2_VALIDATION](../../../diagnostics/pcm_audio/S2_VALIDATION.md)，改动范围和文件大小见 [清单](SOURCE_MANIFEST.md)。

`samples/BGM.PCM` 是 3 秒 440Hz、48kHz/16bit/mono 示例；可先试听配套 WAV。当前 S1 固件尚不播放它，后续 S3 固件才会读取根目录 BGM.PCM。

其他音频转换：

```powershell
python tools/make_audio_corpus.py input.wav BGM.PCM
```

当前可上板回退仍为 `releases/v0.12.0/s1-local.1/demo.bit`。S2 不建立 local/board 标签；S3 需完成顶层接入、系统仿真、完整 TD 和用户上板。
