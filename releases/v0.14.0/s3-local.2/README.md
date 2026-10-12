# v0.14.0 S3 local.2

这是 S3 四宫格时序修复候选，基线为 v0.13.0，分支为 feature/thumbnail-timing-margin。候选 bit 为 `demo.bit`；阶段回退为 `releases/v0.14.0/s3-local.1/demo.bit`，已获功能板测确认的回退为 `releases/v0.14.0/s2-local.1/demo.bit`，总回退为 `releases/v0.13.0/demo.bit`。

本轮将文件扇区响应整体流水，保持字节、索引、完成和错误同拍；修正错误分类拍序。在解码器与缩放器之间加入一深度 ready/valid 寄存级，并预寄存文件结束判断。候选同时包含构建开始前工作区已有的 SPI MISO 保持 LUT 位置调整，实际构建输入已完整归档。

TD 使用原 timing.sdc、100MHz SD 域、high/high 与布局 Hold 修复。Routed Setup +0.096ns、Hold +0.076ns、STA coverage 99.97%；16757 LUT、43 BRAM9K、11 DSP、1 PLL。97 个工程输入与构建逐字节一致，bit、报告、审计、76 份通过日志及 24 个相对 v0.13.0 变化的生产输入已固定。

本地验证覆盖 42 项 FAT32、末字节同拍、五种尺寸完整字节流逐像素、真实 SDRAM 双 writer、混合尺寸预览、音频、失败保图、重试和超时后缓存选择。详情见 `VALIDATION.md`。

本候选尚未上板，不建立 board 标签，也不代表正式 v0.14.0。请按 `BOARD_VALIDATION.md` 测试 SW2/SW1=11 四宫格、KEY1/KEY2 焦点、KEY4 预览/全屏、图片音乐连续性、重扫与复位。通过后再记录 board.2 并进入 S4。
