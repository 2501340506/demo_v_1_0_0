# Anlogic EG4 HDMI BMP Player

基于安路 EG4S20 FPGA 的 TF 卡 BMP 图片播放器。工程从 TF 卡扫描并读取图片，使用 SDRAM 双缓冲保存帧数据，通过 HDMI 输出 640x480 RGB 视频，同时输出 48 kHz I2S 测试音。

## 功能

- 上电后扫描 TF 卡前 131072 个扇区，查找最多 4 张符合要求的 BMP 图片
- KEY1 稳定按下切换下一张，按住不连发
- KEY2 短按释放切换自动轮播，长按 1 秒切换上一张，长按释放不附带短按
- 自动轮播间隔 3 秒，手动切换完成后重新计时
- 使用 SDRAM 双缓冲，完整写入下一帧后再切换显示
- HDMI 1.4b 输出 640x480 视频和 48 kHz 音频
- 首图提交前数码管显示读取状态，提交后显示图片编号

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

工程按扇区顺序查找图片，不依赖 FAT 文件名。上电后自动显示找到的第一张图片。加载期间每个方向最多挂起一次请求，下一张优先于上一张，再优先于自动轮播。

## 当前版本：v0.1.0

2026-10-03 用户确认当前按键功能及稳定性表现良好，作为本次稳定归档版本。ModelSim 14 组回归通过；TD 完成综合、布局布线和 bitstream 构建。Setup WNS -6.699 ns，Hold WNS +0.011 ns：功能验收通过，但时序尚未完全收敛。

版本说明见 [CHANGELOG.md](CHANGELOG.md)，修改经验见 [按键与加载链路经验](docs/KEY_CONTROL_LESSONS.md)，仿真范围见 [diagnostics/README.md](diagnostics/README.md)。

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

仓库中的 `TD_project/demo_Runs/best_result/demo.bit` 已更新为本次验收版本，构建时间为 2026-10-03 02:23:16。该目录是发布归档，不表示时序最优；使用版本标签 v0.1.0 可定位本次源码与产物。IP 包装文件已包含在 `user_source/hdl_source/IP`，相关说明见 `user_source/hdl_source/_IP核需在TD中生成.txt`。

