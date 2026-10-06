# local.5 构建与验证

顶层 top，EG4S20BG256，TD 6.2.1，双 PLL，原工程源清单、时钟、SDC 和 ADC 不变。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/sd_recovery/run_tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/stability/run_regression.ps1 -Stage v052_s2_local5
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_td_build.ps1 -BuildName v052_s2_local5 -HighFanoutOptimization -TimingOptimization ultra -PostPlaceOptimization high
```

复现：引脚卡模型在 ACMD41 返回 idle 后、下一次 CMD55 前变为 ready，不随 FPGA 局部复位自动复位。原 local.4 RTL 在缩短至 50 ms 的初始化期限内发出 166 条命令，ACMD41 仅执行 1 次，最终 `diagnostic=00000000000037ff`。`simulation/repro_before_fix.log` 中的 Fatal 是修正前复现证据，不属于修正后的通过结果。

修正后同一模型正常完成第二次 ACMD41、CMD16、CMD59 和正确 CRC 扇区读取。字节级专项另外确认 CMD55 R1=00 接受、R1=04 拒绝；已有 idle=01 路径继续覆盖。四个专项及八项既有回归日志附 simulation/。保图/写取消 RTL 未变，三组恢复专项沿用 local.4 结果，本轮不声称重新执行该专项。

附 demo.al 为以 TD_project 为相对路径基准的工程快照。候选对应本地 `v0.5.2-s2-local.5`，不移动旧标签，不推送。实际板级问题是否消除仍待用户确认。
