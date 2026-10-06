# local.2 诊断构建

生产协议决策与 local.1 相同，只增加命令/R1 观察寄存器和 F 状态面板显示。`cmd_response` 在每条命令开始时设 FF，完整六字节之后捕获有效 R1；`sd_debug` 在 SD 顶层保留命令号与返回值，初始化失败复位 SPI 时不清除此记录。两个寄存器将值送到面板域。双 PLL、SD 100 MHz、内存 125 MHz、像素 25 MHz、串行 125 MHz 及 SDC 均不变。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_td_build.ps1 -BuildName v052_s2_local2_final -HighFanoutOptimization -TimingOptimization ultra -PostPlaceOptimization high
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/sd_recovery/run_tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/stability/run_regression.ps1 -Stage v052_s2_local2
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/sd_recovery/run_handoff.ps1
```

本轮四个协议/按键/初始化/引脚级入口通过，诊断保持断言通过；面板测试验证 `29FF0F` 六位译码。七个既有回归入口先通过；最后一个顶层复位入口遇到声明顺序编译问题后修复，单独重跑 `diagnostics/history/v0.3.0/run_s9_reset_tests.ps1` 通过。保图三组合再次通过。日志见 `simulation/`，不重复宣称所有测试在一次未中断调用中完成。

源码对应本地标签 `v0.5.2-s2-local.2`。工程源清单沿用 local.1，无新生产源文件；附 `demo.al` 仅为快照，相对路径以项目 `TD_project` 为基准。原工具报告保留，不改写格式。内部与硬核边界分别见 `TIMING.md`。

本轮没有复现用户板上故障，诊断版不代表已修好；未固化、未上传、未进入 S3。
