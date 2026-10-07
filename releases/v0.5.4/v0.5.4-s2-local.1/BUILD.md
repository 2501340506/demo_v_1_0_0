# S2构建与证据

最终TD构建目录：`diagnostics/output/v054_s2_attempt1`；仿真证据：`diagnostics/output/v054_s2_uart_sim`、`v054_s2_recovery.log`、`v054_s2_timeout_control.log`和`v054_s2_regression.log`。TD使用与S1相同器件、单PLL、策略和隔离清单，新增`uart_event_logger.v`编译顺序55。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/uart_fastboot/run_sim.ps1 -RunName v054_s2_uart_reproduce
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/uart_fastboot/run_td.ps1 -BuildName v054_s2_reproduce
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/stability/run_regression.ps1 -Stage v054_s2_reproduce
```

S2候选bit来自v054_s2_attempt1 TD输出，尚未板测，不复用S1板测结论。
