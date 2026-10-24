# 开机加速 v0.30.0 归档

正式版 `v0.30.0`，复用板测通过的 `v0.30.0-s1-local.1` bit。只改 Flash 加载时钟（2.5 → 16 MHz），卡不用换，必须烧 Flash。实测和用户确认：开机慢主要是显示器识别 HDMI。已合并 main。

- [正式 bit 及说明](../../../../releases/v0.30.0/README.md)
- [实施计划快照](实施计划.md)
- [最终交接快照](最终交接.md)
- [发布说明快照](发布说明.md)

记录：[bitgen 脚本](../../../../diagnostics/fast_boot/run_bitgen.ps1) · [计时诊断](../../../../diagnostics/fast_boot/boot_time_seg.v) · [参数核实](../../../../releases/v0.30.0/s1-local.1/validation/mclk_probe.txt)

候选：[s1-local.1（交付）](../../../../releases/v0.30.0/s1-local.1/README.md)

前一版：[v0.29.0 场景底图与泥石流特效](../scene-art-debris-v0.29/README.md)
