# S1构建与证据

最终构建：diagnostics/output/v054_s1_final。工具TD 6.2.168116、EG4S20BG256，单PLL 100/40/40/25/125MHz，SPI 16.667MHz。high-fanout high、timing ultra、post-place high、默认seed。工程新增UART源编译顺序53/54，生产GUI工程保留原样。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/uart_fastboot/run_sim.ps1 -RunName v054_s1_uart_reproduce
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/flash_boot/run_baseline.ps1 -Stage v054_s1_reproduce
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/flash_boot/run_reset_tests.ps1 -Suite startup
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/uart_fastboot/run_td.ps1 -BuildName v054_s1_reproduce
```

构建必须使用新的BuildName。sources/TD_project/demo.al包含完整清单，sources/user_source为生产快照；sources.txt列出各文件字节数。tests保存本阶段脚本与测试；其他既有测试入口由对应本地标签固定。timing保存最终综合/布局/时序/约束例外和原始日志，simulation/final为验收证据。

最终八项既有回归由首轮通过的前七项加修正连接后单独通过的复位项组成；不是声称首轮批处理全部通过。simulation/initial保留首轮日志；experiments保留首次TD编译顺序告警。

原始PowerShell重定向日志为UTF-16，ModelSim原生日志为UTF-8；读取工具按BOM识别，保留原始字节。未重跑已通过且未受修改影响的BMP/音视频测试。
