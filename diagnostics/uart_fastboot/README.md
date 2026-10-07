# v0.5.4 UART与快速启动复现

当前为 S2 修正版 local.2，待上板。真实事务观察位于 `sd_card_bmp.v`，顶层直接接入诊断包；不能用数码管复用显示码代替事件。S3 暂停续扫尚未交付。

本次复现命令（重新运行时使用新的输出名）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/uart_fastboot/run_sim.ps1 -RunName v054_s2fix_uart_final
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/flash_boot/run_baseline.ps1 -Stage v054_s2fix
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/sd_recovery/run_handoff.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/uart_fastboot/run_td.ps1 -BuildName v054_s2fix_final
```

[固定候选](../../releases/v0.5.4/v0.5.4-s2-local.2/README.md) 包含最终日志、源码和报告。`package_s2_fix.py` 只封装最终目录并逐字节核对，拒绝覆盖已有候选。下文保留 S1 复现方法。

S1：100MHz控制域，D12输出115200/8N1启动行。GUI用户工程不改，构建使用v0.5.3归档单PLL清单加新UART源文件。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/uart_fastboot/run_sim.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/flash_boot/run_baseline.ps1 -Stage v054_s1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/uart_fastboot/run_td.ps1 -BuildName v054_s1_attempt1
```

每次TD构建使用新的BuildName，完整快照在diagnostics/output/<BuildName>。归档工程可在TD打开，新UART文件仅加入隔离工程，不覆盖用户TD_project/demo.al及best_result。

UART引脚异步于PC接收端。SDC仅对FPGA TX寄存器到引脚定义10ns工程传播预算，不声称接收端同步setup/hold验证；协议采样由独立UART接收模型检查。原有SPI/HDMI约束保留。
