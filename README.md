# 山区地质灾害科普与避险演示系统 v1.0.0

本项目是在安路科技 EG4S20 FPGA 上实现的地质灾害科普与避险演示系统。系统从 TF 卡读取图片、音频、字幕和场景数据，通过 HDMI 输出图像与声音，提供宣讲、情景演示、灾害选择和参数调节等完整功能。

v1.0.0 是项目首个稳定正式版，用于比赛提交、作品演示和后续维护。

## 主要功能

- 支持 TF 卡 FAT32 文件系统扫描与长文件名目录识别。
- 支持 24 位 BMP 图片解析、缩放、缓存和 HDMI 显示。
- 支持 WAV/PCM 音频读取、播放、音量调节和 HDMI 音频输出。
- 宣讲模式包含滑坡、泥石流、山洪、地震四类科普页面，以及中文滚动字幕、讲解音频和底部音频波形。
- 情景模式包含四类灾害的阶段动画、风险提示、避险信息和旁白。
- 支持灾害菜单、四宫格缩略图预览、AUTO 自动播放、按键操作和数码管状态显示。
- SW4 参数面板可调节亮度、对比度、音量、波形显示、场景速度、状态栏、字幕和转场效果。
- 首次上电时讲解等待 HDMI 输出稳定约 4 秒后开始，避免显示器亮屏前漏掉语音开头。

## 硬件与开发环境

| 项目 | 配置 |
| --- | --- |
| FPGA | Anlogic EG4S20BG256 |
| 开发工具 | Tang Dynasty 6.2.168116 |
| 工程入口 | `TD_project/demo.al` |
| RTL 顶层 | `top_tf_hdmi_audio` |
| 视频输出 | HDMI 640×480 |
| 外部存储 | TF 卡、板载 SDRAM |
| Flash 加载时钟 | 16 MHz |

## 使用方法

1. 使用 Tang Dynasty 打开 `TD_project/demo.al`。
2. 使用正式固件 [releases/v1.0.0/demo.bit](releases/v1.0.0/demo.bit) 执行 Program Flash。
3. 插入准备好的 TF 卡并冷启动开发板。
4. 通过拨码开关选择工作模式，通过 KEY1、KEY2 和 KEY4 完成选择、翻页和确认操作。
5. 拨动 SW4 可打开中文参数调节面板。

正式版烧写 Flash 后使用，沿用当前 TF 卡内容，无需更换卡内资源。

## 源码结构

```text
TD_project/
  demo.al                       Tang Dynasty 工程入口
user_source/
  hdl_source/                   Verilog RTL 与 IP 包装
  constraints_source/           引脚和时序约束
  ip_source/                    PLL 等生成 IP
releases/v1.0.0/
  demo.bit                      v1.0.0 正式固件
  README.md                     正式版发布说明
```

## 构建参数

本设计接近 EG4S20 的资源上限，不能直接使用 TD 默认策略。默认策略可能产生约 5167 个 MSLICE，并在布局阶段报 `PHY-9009`。

综合参数：

```text
gate opt_area high
gate pack_effort high
```

布局布线参数：

```text
place pack_mode more_lut_pair
place seed 3
place hfn_opt_effort high
place fix_hold high
route post_route_opt high
route postrt_opt_extra_round 4
place effort high
route effort routability
place opt_timing ultra
place post_place_opt high
```

## 资源与时序

| 指标 | 结果 |
| --- | ---: |
| LUT | 17777（90.70%） |
| Setup WNS | +0.252 ns |
| Hold WNS | +0.011 ns |
| Setup/Hold TNS | 0 ns |
| 布局布线 Seed | 3 |

## 验证结果

- 核心控制、媒体读取、图片显示、音频播放、字幕、AUTO 播放和首启语音等待相关仿真通过。
- Tang Dynasty 完整综合、布局布线和 bitstream 生成通过。
- Setup 与 Hold 均满足时序要求。
- 开发板实测功能正常，首次亮屏后的讲解开头完整。

## 正式版文件

- [v1.0.0 发布说明](releases/v1.0.0/README.md)
- [v1.0.0 正式固件](releases/v1.0.0/demo.bit)
- [版本变更记录](CHANGELOG.md)
