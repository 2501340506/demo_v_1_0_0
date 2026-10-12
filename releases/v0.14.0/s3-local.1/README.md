# v0.14.0 S3 local.1

这是 v0.14.0 S3 四宫格生产接入本地候选，基线为 v0.13.0，功能分支为 `feature/image-scaling-thumbnails`。

候选 bit：`demo.bit`，661052 字节。总回退为 `releases/v0.13.0/demo.bit`，阶段回退为 `releases/v0.14.0/s2-local.1/demo.bit`。

## 本地验证

- TD Setup `+0.117 ns`，Hold `+0.012 ns`，STA coverage 99.97%，原 timing.sdc 未修改。
- 最新联合仿真 `scale_s3_preview_final11`：165 帧、60 预览帧、10 次实际提交与提示音、139171 个 PCM 样本、4 个播放会话，无欠载/溢出。
- `scale_s3_fat32_7`：42 项 FAT32 回归通过。
- `scale_s3_stream3`：160×120、640×480、801×601、1920×1080、1080×1920 完整字节流逐像素通过。
- `scale_s3_loader3`：真实 SDRAM 双 writer、缩略图和刷新/背压专项通过。
- SD 扇区协议专项通过；预览、失败保留、重试、超时缓存选择和字幕/圆环隐藏恢复通过。

MISO 返回路径增加一级保持 LUT 以修复器件 Hold 偏斜；该原语由 TD 器件库提供，仿真脚本显式加载 `al_lmacro.v`。不修改约束、不降低功能范围。

## 上板步骤

按 [BOARD_VALIDATION.md](BOARD_VALIDATION.md) 使用混合尺寸 BMP 与 BGM 测试。SW2/SW1=11 进入四宫格，KEY1/KEY2 移动焦点，KEY4 在预览和全屏间切换。请记录实际候选路径、观察结果及是否继续进行 S4 的持续播放、Flash 和完全断电冷启动。

本候选尚未获得用户板测确认，因此未建立 board 标签，也不代表正式 v0.14.0。