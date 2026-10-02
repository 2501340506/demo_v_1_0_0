# Anlogic EG4 HDMI BMP Player

基于安路 EG4S20 FPGA 的 TF 卡 BMP 图片播放器。工程从 TF 卡扫描并读取图片，使用 SDRAM 双缓冲保存帧数据，通过 HDMI 输出 640x480 RGB 视频，同时输出 48 kHz I2S 测试音。

## 功能

- 上电后扫描 TF 卡前 131072 个扇区，查找最多 4 张符合要求的 BMP 图片
- 支持按键切换下一张图片
- 支持每秒自动轮播，可通过按键启停
- 使用 SDRAM 双缓冲，完整写入下一帧后再切换显示
- HDMI 1.4b 输出 640x480 视频和 48 kHz 音频
- 数码管显示 TF 卡读取状态

## 硬件与工具

- FPGA：Anlogic EG4S20BG256
- 开发工具：Tang Dynasty 6.2.168116
- 输入时钟：50 MHz
- 顶层模块：`top`
- 顶层文件：`user_source/hdl_source/top_tf_hdmi_audio.v`

## 图片要求

TF 卡中的图片需要满足以下格式：

- BMP 文件
- 640x480 像素
- 24 位色
- 不压缩

工程按扇区顺序查找图片，不依赖 FAT 文件名。上电后自动显示找到的第一张图片；`key1` 切换下一张，`key2` 开启或关闭自动轮播。

## 目录

```text
TD_project/
  demo.al                  TD 工程文件
  demo_Runs/best_result/   已生成的最佳布局布线结果和 bitstream
user_source/
  constraints_source/      引脚与时序约束
  hdl_source/              Verilog 源码、IP 包装和加密 IP
```

## 构建

1. 使用 Tang Dynasty 6.2 打开 `TD_project/demo.al`。
2. 确认器件为 `EG4S20BG256`，顶层模块为 `top`。
3. 依次运行综合和布局布线。
4. 生成的 bitstream 位于 `TD_project/demo_Runs/phy_1/demo.bit`。

仓库中的 `TD_project/demo_Runs/best_result/demo.bit` 是工程已有的可烧录结果。IP 包装文件已包含在 `user_source/hdl_source/IP`，相关说明见 `user_source/hdl_source/_IP核需在TD中生成.txt`。

