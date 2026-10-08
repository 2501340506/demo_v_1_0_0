# BMP 2.11 板级版本说明

版本：v0.6.0-bmp211-s3-board.1，2026-10-08，本地板级验收版本。复用 releases/v0.6.0-bmp211/s3-local.1/demo.bit，不重新构建、不提前创建其他正式版本号、不上传 GitHub。

变更：独立 bmp24_decoder 固定接入生产；共享 bmp_header_check；去除 bmp_read 旧头解析、RGB 组装及重复像素计数，保留 SD 读取与加载控制。生产显示格式、外部接口、双缓冲显示提交流程保持。

用户确认：好图板侧功能正常；混合样本只显示好的 24 位图；第三步错误后恢复和 AUTO 功能正常。未提供实测时长或逐项次数，不补写。第四项只是扫描说明。

TD 沿用已验收 bit 的原构建证据：Setup +0.111 ns、Hold +0.024 ns，STA 99.93%；6379 LUT、4122 寄存器、4 BRAM、4 DSP、1 PLL。保留厂商警告，约束未放宽。失败 attempt1/2 不交付。

release 只备份三个改动 RTL，未改动源码引用配套仓库。UART 启动行仍为 v0.5.4-s3-local.2，按 bit 路径识别版本。

回退版本：v0.6.0-bmp211-s2-board.1，使用 releases/v0.6.0-bmp211/s2-local.1/demo.bit。

边界：仅完成 2.11，2.12 尚未实现；生产仅 24 位，原始扇区无真实 EOF 的限制保留。GitHub 上传作为单独操作等待用户明确授权。