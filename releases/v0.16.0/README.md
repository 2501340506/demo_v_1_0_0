# v0.16.0 正式版：LUT 优化（功能不变）

[下载 demo.bit](demo.bit)（662216 字节）。复用已验收 s2-local.1 原 bit，逐字节一致，未重新构建。基线及回退：[v0.15.0](../v0.15.0/README.md)。

用户可见功能与 v0.15.0 相同，仅降低资源：15402→14190 LUT（−1212，−7.9%，器件占用 78.58%→72.40%），寄存器 8551→8250，DSP 15→13，54 BRAM9K 不变；Setup +0.144ns、Hold +0.003ns。

- S1（批1–3）：逐周期等价的计数器/比较器收窄等，15402→15072 LUT，用户确认功能均正常。
- S2（批4–7）：HDMI 音频包 BCH 共享、ACR/InfoFrame 常数直出，簇号→扇区地址逐拍移位、按索引加载，字幕提交装载时判定变化，数码管单译码器，两处关键路径等价寄存，15072→14190 LUT。用户确认 Flash 冷启动、运行 40 分钟功能均正常。
- S3（放宽到可见行为）：用户决定不做，批8–11 未实施，留作后续备选。

[最终验证](FINAL_VALIDATION.md) · [S2 板测](s2-local.1/BOARD_RESULT.md) · [S1 板测](s1-local.1/BOARD_RESULT.md) · [源码输入](s2-local.1/MANIFEST.md) · [时序报告](s2-local.1/reports/final_timing.rpt) · [LUT 记录](../../diagnostics/lut_opt/LUT_RECORD.md) · [归档](../../docs/history/2026-10-14/lut-optimization/README.md)。
