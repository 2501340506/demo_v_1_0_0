# v0.12.0 S2 验证记录

S1 `v0.12.0-s1-board.1` 已由用户确认通过。本阶段只验证 PCM 音频模块，生产 top 尚未接入 BGM.PCM。

- `tools/make_audio_corpus.py`：固定输出 48kHz、16bit little-endian、单声道 PCM；调用 FFmpeg，报告字节数、样本数和时长。
- `pcm_stream_player.v`：完成写侧字节配对、双时钟循环缓冲、两级指针同步、48kHz 节拍、左右声道复制、欠载静音计数和 valid/ready 输出。
- `audio_source_mux.v`：WAV/PCM 源优先选择，未选中的琶音源继续消费以避免内部 FIFO 堵塞。
- `pcm_s2_player7`：ModelSim 通过，验证 8 个样本流入、输出有效、左右声道一致，零错误零警告。

尚未完成：FAT32 BGM.PCM 文件发现、共享服务音频客户端接入、循环 EOF、生产 HDMI 接线、完整 TD 和 S2 独立综合。下一步先补扫描器音频条目接口及音频客户端协议专项，再决定是否修订播放器接口。
