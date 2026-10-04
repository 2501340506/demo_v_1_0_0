# v0.3.0 回归归档

保存v0.3.0结项时的8个仿真入口、16个testbench和2个Python参考。目录整理只调整路径，测试逻辑保持不变；TD构建脚本仍在diagnostics根目录。ModelSim10.6e和TD6.2.1使用既有安装路径。

从项目根目录运行，需要的库自动新建，结果全部写入`diagnostics/output/modelsim_*`：

| 范围 | 命令参数（前缀均为 `powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/history/v0.3.0/`） |
|---|---|
| 图片与控制 | `run_control_tests.ps1 -Prefix current` |
| 模式/数码管 | `run_mode_tests.ps1` |
| 异步帧缓冲 | `run_buffer_handoff.ps1` |
| 独立PCM | `run_audio_tests.ps1` |
| HDMI基础及封装 | `run_hdmi_packet_tests.ps1` |
| 视频坐标/对齐 | `run_video_alignment.ps1` |
| 最终媒体/PHY/CDC | `run_hdmi_s6_tests.ps1 -Stage s9` |
| S9顶层复位 | `run_s9_reset_tests.ps1` |

例如：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/history/v0.3.0/run_hdmi_s6_tests.ps1 -Stage s9
```

S6/S7/S8参数、缓冲Baseline对照等历史入口保留；它们的范围以脚本为准。末轮固定证据见[已验收S9](../../../releases/v0.3.0-r2-s9-local.1/README.md)。SD缺陷复现已分离至[延期问题存档](../sd_recovery/README.md)，不属于正常回归通过项。
