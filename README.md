# Anlogic EG4 HDMI BMP Player

基于安路 EG4S20 FPGA 的 TF 卡 BMP 图片播放器。工程从 TF 卡扫描并读取图片，使用 SDRAM 双缓冲保存帧数据，通过 HDMI 输出 640x480 RGB 视频，同时输出 48 kHz I2S 测试音。

## 功能

- 上电后扫描 TF 卡前 131072 个扇区，查找最多 4 张符合要求的 BMP 图片
- KEY1 通过组合窗口确认单键后切换下一张，按住不连发
- KEY2 短按释放切换自动轮播，长按 1 秒切换上一张，长按释放不附带短按
- 自动轮播空闲等待 3 秒；手势结束且加载空闲后重新计时，实际切图间隔另含图片加载时间
- 使用 SDRAM 双缓冲，完整写入下一帧后再切换显示
- HDMI 1.4b 输出 640x480 视频和 48 kHz 音频
- 首图提交前数码管显示读取状态，提交后显示图片编号

第三阶段已通过板级验收：图片编号所在位的小数点亮表示自动轮播开启，灭表示手动模式；加载或按键保持期间仍表示模式，不表示正在计时。组合 C/计数提示期间小数点仍有效。首图前、复位和诊断显示模式下不亮。已发布 v0.1.7 包含此提示，说明见 [第三阶段验收](diagnostics/STAGE3_DISPLAY_ACCEPTANCE.md)。

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

## 当前版本：v0.1.7

2026-10-04 用户确认轮播小数点提示改进后的板级功能正常，作为本次归档版本。ModelSim 14 组回归通过；TD 完成综合、布局布线和 bitstream 构建。Setup WNS -6.699 ns，Hold WNS +0.004 ns：功能验收通过，但时序尚未完全收敛。

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

当前验收产物及验证报告见 [releases/v0.1.7](releases/v0.1.7/README.md)，源码由标签 v0.1.7 定位。best_result 保留旧发布产物。时序问题按用户要求暂不处理。
