# v0.15.0 正式版：亮度、对比度与总音量调节

[下载 demo.bit](../../../../releases/v0.15.0/demo.bit)（662216 字节）。复用已验收 s2-local.1 原 bit，逐字节一致，未重新构建。基线及回退：[v0.14.0](../../../../releases/v0.14.0/README.md)。

SW2/SW1=01 默认调亮度、10 默认调对比度，KEY4 短按在画面参数与总音量间切换；KEY1 减、KEY2 加（亮度/对比度步长 16，音量步长 10%），100 ms 内双键恢复当前项默认值。参数跨切图、重扫和模式保留，复位清除。00/11 维持原图片与四宫格操作。参数条显示 B/C/V，仅在 01/10 出现。

为解除布线拥塞，S2 在功能不变前提下降低资源：16966→15402 LUT，Slice 96.56%→87.72%，54 BRAM9K、15 DSP；Setup +0.139ns、Hold +0.004ns。

S2 用户确认功能均正常；S3 用户确认 Flash 下持续运行 20 分钟及完全断电冷启动通过。

[最终验证](../../../../releases/v0.15.0/FINAL_VALIDATION.md) · [S3 板测](S3_BOARD_RESULT.md) · [S2 板测](../../../../releases/v0.15.0/s2-local.1/BOARD_RESULT.md) · [源码输入](../../../../releases/v0.15.0/s2-local.1/MANIFEST.md) · [时序报告](../../../../releases/v0.15.0/s2-local.1/reports/final_timing.rpt) · [归档](README.md)。
