# v0.14.0 正式版：图片缩放与四宫格缩略图

[下载 demo.bit](demo.bit)（661052 字节）。复用已验收 s3-local.3 原 bit，逐字节一致，未重新构建。基线及回退：[v0.13.0](../v0.13.0/README.md)。

支持正高度、24 位非压缩 BMP，横向不超过 1920×1080、竖向不超过 1080×1920；最近邻等比缩放至 640×480 并居中补黑边。

SW2/SW1=11 进入四宫格，KEY1/KEY2 选图，KEY4 在预览与全屏间切换。预览保留状态、计时和背景音乐，隐藏滚动字幕与圆环；全屏恢复。KEY2 长按重扫，KEY3 复位保留。

S3 功能通过，S4 用户确认完成持续运行 20 分钟、Flash 烧录和完全断电冷启动。大图首次加载仍需读取完整 BMP，四图缓存日志约 14.96 秒，未增加读取优化。

[最终验证](FINAL_VALIDATION.md) · [S4 板测](S4_BOARD_RESULT.md) · [S3 板测](s3-local.3/BOARD_RESULT.md) · [源码输入](s3-local.3/MANIFEST.md) · [时序报告](s3-local.3/reports/final_timing.rpt) · [归档](../../docs/history/2026-10-13/image-scaling-thumbnails/README.md)。

各候选目录保留本阶段变化源码与必要证据；local.1/local.2 是历史失败候选，不用作正式交付。
