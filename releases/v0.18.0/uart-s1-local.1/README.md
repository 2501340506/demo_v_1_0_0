# UART 资源裁减 S1 local.1

2026-10-18，本地候选 `v0.18.0-uart-s1-local.1`，分支 `feature/uart-resource-reduction`，输入 `075ab05` / `v0.18.0-m6-local.1`。下载 [demo.bit](demo.bit)，上板只用这个固定文件。

默认关闭串口事件日志和串口在线字幕，TX 恒高、RX 不影响字幕；保留数码管 SD 调试页、固定/TEXT.BIN 字幕、宣传与情景模式和共享帧边界。只改两个生产文件：[top](sources/user_source/hdl_source/top_tf_hdmi_audio.v) 和 [SDC](sources/user_source/constraints_source/timing.sdc)，引脚分配不变。

LUT 16022→14092（减少1930，12.05%）；寄存器10686→9530（减少1156）；BRAM9k 56→46（释放10块）；BRAM32k和DSP不变。完整 TD `uart_reduction_td_attempt05`：14092 LUT（71.90%）、9530寄存器、46 BRAM9k、2 BRAM32k、13 DSP；Setup +0.040ns/Hold +0.019ns，STNS/HTNS均0，STA覆盖率99.97%，无ERROR、完成bitgen。[时序与告警审阅](reports/AUDIT_REVIEW.md)保留既有IO/模型例外；11份本轮仿真及20份编译/模型日志通过，实际范围见[验证](VALIDATION.md)。111工程输入及根脚本、bit和变化源均逐字节核对，见[清单](MANIFEST.md)。

恢复日志时，设置 `UART_LOG_ENABLE=1`，并取消 `timing.sdc` 三条 `# UART_TX_ON ` 前缀；恢复在线字幕另设 `UART_SUBTITLE_ENABLE=1`，取消一条 `# UART_RX_ON ` 前缀并审阅其输入寄存器目标。单开字幕时命令生效但无串口回复；两开恢复日志和回复仲裁。任何恢复配置均须重新验证、构建及审阅约束匹配。

[板测步骤与结果](BOARD_RESULT.md)尚待用户执行；前序M6的内容/听审、≥40分钟和整机计时仍未完成。本次不建立board标签、不发布正式版、不合并main。硬件回退 [M5已确认bit](../m5-local.1/demo.bit)；正式回退 [v0.16.0](../../v0.16.0/README.md)。
