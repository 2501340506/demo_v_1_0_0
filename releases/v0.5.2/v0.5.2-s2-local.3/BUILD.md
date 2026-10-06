# local.3 构建及验证

顶层 `top`，EG4S20BG256，双 PLL。TD 6.2.1 参数沿用 high fanout / timing ultra / post-place high：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_td_build.ps1 -BuildName v052_s2_local3_phase -HighFanoutOptimization -TimingOptimization ultra -PostPlaceOptimization high
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/sd_recovery/run_tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/stability/run_regression.ps1 -Stage v052_s2_local3
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/sd_recovery/run_handoff.ps1
```

四个协议/按键/初始化/引脚入口、八个既有回归入口及三组保图配置通过。新增面板轮换、token 最后字节、实际/计算 CRC、第一次失败保持及复位重采样断言。引脚测试数据每字节为 `(i*37+11)&255`，512 字节 CRC 为 D594，由独立软件计算后固定到测试中。

没有修改协议状态转移或成功/失败判定；增加的寄存器只供诊断。生产源清单、SDC、ADC、PLL 及内存参数与 local.2 一致。附 `demo.al` 是项目快照，相对路径以 `TD_project` 为基准，不直接从发布子目录打开。

中间构建发现诊断总线 SD→面板路径 hold 违例；诊断总线增加 SD 域下降沿暂存，再送面板两拍，保留路径时序分析，不增加例外。修改后顶层复位测试重跑通过。中间构建不作为交付候选，证据保留在 `diagnostics/output/v052_local3_rejected_timing/`。

本地源码对应 `v0.5.2-s2-local.3`，bit 与 TD 最终输出逐字节核对，报告和日志附目录。完整硬件功能仍未验收；等待用户四页显示再修复，不上传、不固化。
