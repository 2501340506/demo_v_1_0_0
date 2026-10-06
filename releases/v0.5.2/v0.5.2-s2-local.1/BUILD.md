# 构建与复现

源码固定到本地标签 `v0.5.2-s2-local.1`，基线 `v0.5.1`，顶层 `top`，器件 EG4S20BG256。工具为本机 TD 6.2.1 和 ModelSim 10.6e。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_td_build.ps1 -BuildName v052_s2_local1 -HighFanoutOptimization -TimingOptimization ultra -PostPlaceOptimization high
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/sd_recovery/run_tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/sd_recovery/run_handoff.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/flash_boot/run_baseline.ps1 -Stage v052_s2_final
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/flash_boot/run_reset_tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/flash_boot/run_reset_tests.ps1 -Suite startup
```

逐条执行，不并行使用共享库或 TD 构建目录。实际工具路径：`D:/modelsim/win64`、`D:/TD/anlogic/TD6.2.1`。

本阶段工程源清单、SDC、ADC、PLL 和内存周期不变；新增端口接在已有源文件，不需新增工程项。附带 `demo.al` 为原工程快照，内部相对路径仍以项目 `TD_project` 为基准；复现时在标签检出目录使用 `TD_project/demo.al` 或上述脚本，不直接在发布子目录打开快照。实际构建配置见 `settings.cfg`，源路径见 `sources.txt`。

产物 `demo.bit` 629624 字节；复制后与本次 TD 输出逐字节比较一致。布线资源：LUT 4306、寄存器 3049、BRAM 4、DSP 4、PLL 2，详见 `demo_phy.area`。

`simulation` 保存专项和完整回归证据；构建日志为 `td_synthesis.log` / `td_physical.log`。板测仍待反馈，不能从工具通过推断已固化或已冷启动。
