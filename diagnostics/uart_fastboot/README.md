# v0.5.4 UART与快速启动复现

S1：100MHz控制域，D12输出115200/8N1启动行。GUI用户工程不改，构建使用v0.5.3归档单PLL清单加新UART源文件。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/uart_fastboot/run_sim.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/flash_boot/run_baseline.ps1 -Stage v054_s1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/uart_fastboot/run_td.ps1 -BuildName v054_s1_attempt1
```

每次TD构建使用新的BuildName，完整快照在diagnostics/output/<BuildName>。归档工程可在TD打开，新UART文件仅加入隔离工程，不覆盖用户TD_project/demo.al及best_result。

UART引脚异步于PC接收端。SDC仅对FPGA TX寄存器到引脚定义10ns工程传播预算，不声称接收端同步setup/hold验证；协议采样由独立UART接收模型检查。原有SPI/HDMI约束保留。
