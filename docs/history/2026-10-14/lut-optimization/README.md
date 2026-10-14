# LUT 极致优化归档（2026-10-14）

[完整计划](阶段修改计划.md) · [最终交接](HANDOFF.md) · [发布说明](RELEASE_NOTES.md) · [正式文件与验证](../../../../releases/v0.16.0/README.md) · [LUT 记录](../../../../diagnostics/lut_opt/LUT_RECORD.md)。

S0–S2 完成，S3 由用户决定不做。S1 attempt02（15072 LUT）、S2 attempt11（14190 LUT）均经旧新等价与全量回归后板测通过；S2 期间 LUT 下降暴露两条新关键路径，以等价寄存解决，attempt07/08 TD 崩溃在网表变化后消失。正式版复用 s2-local.1 原 bit；用户确认 Flash 冷启动、运行 40 分钟功能均正常。
