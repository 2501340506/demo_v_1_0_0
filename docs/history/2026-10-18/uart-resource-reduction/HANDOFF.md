# 当前交接：UART 资源裁减 S1 local.1，本地通过，待板测（2026-10-18）

- 当前任务：用户明确去掉串口日志和串口在线字幕，保留第3项SD数码管调试页；原目录feature/uart-resource-reduction，输入075ab05/M6 local.1。硬件回退M5 board.1原bit，正式回退v0.16.0。
- 已完成：顶层两参数默认0、generate裁减，TX恒高，保留共享帧边界和固定/TEXT.BIN字幕；仅改top与timing.sdc两个生产文件。LUT 16022→14092（减少1930，12.05%）；寄存器10686→9530（减少1156）；BRAM9k 56→46（释放10块）；BRAM32k和DSP不变。固定[候选](../../../../releases/v0.18.0/uart-s1-local.1/README.md)，标签v0.18.0-uart-s1-local.1。
- 当前验证：本轮11份仿真与20份编译模型日志通过；四种UART组合/原日志字幕、双应用最终RGB/TMDS、状态栏、TEXT/FONT和逐样本VOI/音量/HDMI。完整TD `uart_reduction_td_attempt05`：14092 LUT（71.90%）、9530寄存器、46 BRAM9k、2 BRAM32k、13 DSP；Setup +0.040ns/Hold +0.019ns，STNS/HTNS均0；实际异常约束与告警审阅见[验证](../../../../releases/v0.18.0/uart-s1-local.1/VALIDATION.md)。111工程输入/根脚本、bit/变化源逐字节核对。
- 卡住的问题：本地验证无阻塞；GitHub分支/local标签推送多次遇到curl 55连接重置，当前只核对到plan标签已上传，尚未确认分支/local标签同步完成。本候选[板测](../../../../releases/v0.18.0/uart-s1-local.1/BOARD_RESULT.md)待用户；前序M6四页内容/完整听审、≥40分钟、Flash冷启动及双向切换/换卡复位原始计时仍待办。新bit不继承M5总体板测确认。
- 下一步：交用户烧录固定bit并记录本候选板测；当前分支与本次plan/local标签随阶段提交同步new-origin并核对远程引用。具体候选确认后才记board并推送；正式版本及main合并继续等待约定整机验收和发布确认。
- 踩过的坑：常量TX使TD把旧10ns约束扩大到42455内部路径；SDC内Tcl if无效。最终默认注释三条TX命令和一条RX false-path，恢复日志时，设置 `UART_LOG_ENABLE=1`，并取消 `timing.sdc` 三条 `# UART_TX_ON ` 前缀；恢复在线字幕另设 `UART_SUBTITLE_ENABLE=1`，取消一条 `# UART_RX_ON ` 前缀并审阅其输入寄存器目标。单开字幕时命令生效但无串口回复；两开恢复日志和回复仲裁。任何恢复配置均须重新验证、构建及审阅约束匹配。 attempt01–04均不交付；bitgen/exit0不代表时序通过。RX关闭后的旧false-path已注释；既有IO/model例外保留，不称全IO覆盖。个人记录原字节不改不提交，用户TD/best_result/旧worktree/原卡不动，无哈希/批量删除。
- [本地阶段归档](README.md)。仅归档本轮本地结果，不把UART或M6待测项写成验收完成。
