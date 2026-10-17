# UART 资源裁减验证

生产顶层默认 `UART_LOG_ENABLE=0`、`UART_SUBTITLE_ENABLE=0`。保留共享帧边界、卡上 TEXT.BIN 字幕及 SD 数码管调试页。阶段范围见[计划](../../docs/UART资源裁减分阶段计划.md)，最终结果见[固定候选](../../releases/v0.18.0/uart-s1-local.1/VALIDATION.md)。

## 复现

在仓库根目录执行，输出名必须尚不存在；Python 使用 `py -I -X utf8`。ModelSim 位于 `F:/modelsim/win64`，TD 位于 `E:/TD`。

```powershell
powershell -NoProfile -File diagnostics/uart_reduction/run_options.ps1 -RunName uart_reduction_options01
powershell -NoProfile -File diagnostics/publicity_mode/run_m5.ps1 -RunName uart_reduction_pixels01 -Suite pixels
powershell -NoProfile -File diagnostics/publicity_mode/run_m5.ps1 -RunName uart_reduction_status01 -Suite status
powershell -NoProfile -File diagnostics/publicity_mode/run_m5.ps1 -RunName uart_reduction_legacy01 -Suite legacy_top
powershell -NoProfile -File diagnostics/publicity_mode/run_m5.ps1 -RunName uart_reduction_voice01 -Suite voice_top
powershell -NoProfile -File diagnostics/mountain_scene/build_m5.ps1 -BuildName uart_reduction_td_attempt05 -PlacementStrategy 5 -PlacementSeed 12 -HighPlaceEffort -HighAreaOptimization -TimingOptimization high
powershell -NoProfile -File diagnostics/uart_reduction/audit.ps1 -BuildName uart_reduction_td_attempt05
py -I -X utf8 diagnostics/uart_reduction/package.py review uart_reduction_td_attempt05
# 人工审阅审计和告警差异后：
py -I -X utf8 diagnostics/uart_reduction/package.py uart_reduction_td_attempt05
```

`run_options` 驱动四种开关组合的真实串口命令，检查默认 RX 无效/TX 空闲、可恢复字幕及 CDC、共享身份帧提交、SD 调试数据通路和复位；同时重跑原日志与字幕专项。SD 面板专项注入已知 debug 总线验证顶层传递，实卡采集与数码管目视由板测确认。生产回归复用原测试模型，实际边界见候选验证。

`probe_constraints.ps1 -RunName uart_reduction_constraints04` 需要本机既有 M5 TD27 与失败 attempt01 数据库：将当前 SDC 的三条 UART_TX_ON 和一条 UART_RX_ON 命令恢复到诊断副本，在开启 UART 的基线上TX max-delay应只覆盖 1 条路径；关闭数据库读取默认 SDC 时该约束必须不存在。脚本只生成诊断结果，不替代新完整 TD 构建。第一次 probe 因诊断脚本路径/引号问题失败，第二次揭示 TD 不执行 SDC 内的 if 判断；第三次显式恢复/注释TX验证通过，第四次使用最终同时注释RX的SDC，原输出保留。

首轮 TD 在常量 TX 上错误扩展旧约束，第二轮条件语句无效，第三轮时序未达标，均不能交付。第四轮时序达标，但RX删除后留下一条无效的旧false-path；第五轮默认同时注释TX三条延时和RX false-path，重新完整构建。不改引脚、时钟或内部路径要求。审计同时保存 timing exception 报告，避免只看总体 WNS。

重新开启日志还须取消 timing.sdc 三条 # UART_TX_ON 前缀，再设 `UART_LOG_ENABLE=1`；串口字幕设 `UART_SUBTITLE_ENABLE=1`，同时取消一条 # UART_RX_ON 前缀并核对其输入寄存器目标。只开字幕时命令生效、TX 保持空闲，无串口回复；同时开启两者才恢复日志和字幕回复仲裁。改参数后必须重新构建并审阅约束匹配，不沿用本候选验证或板测结论。
