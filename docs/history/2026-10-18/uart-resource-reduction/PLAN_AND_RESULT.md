# UART 资源裁减分阶段计划

日期：2026-10-18。用户授权：去掉串口日志与串口在线字幕，保留数码管 SD 调试页。先补计划再改代码。本次独立于宣传 M6 的内容/整机验收，不改写其结果。

## 基线、回退与标签

- 原目录开发，分支 `feature/uart-resource-reduction`，起点 `075ab05`（`v0.18.0-m6-local.1`）。已有个人 `问题小记录.txt` 原字节保留、不提交；旧 worktree、用户 TD 工程和 best_result 不动。
- 硬件对照/开发回退为 M5 board.1 / M6 local.1 共用的 [M5 固定 bit](../../../../releases/v0.18.0/m5-local.1/demo.bit)，正式回退 [v0.16.0](../../../../releases/v0.16.0/README.md)。参考资源 16022 LUT、10686 寄存器、56 BRAM9k、2 BRAM32k、13 DSP；Setup +0.006ns、Hold +0.030ns。
- 计划标签 `v0.18.0-uart-plan.1`；本地硬件候选 `v0.18.0-uart-s1-local.N`；用户确认具体候选后才建 `v0.18.0-uart-s1-board.N`。不移动旧标签、不发布正式版、不合并 main。按执行规则同步 new-origin 的本分支与本次标签。

## S1：顶层功能裁减与验证

1. 增加默认关闭的 `UART_LOG_ENABLE`、`UART_SUBTITLE_ENABLE`，generate 隔离 logger/TX、RX/字幕控制器/字幕 CDC。两者关闭时 TX 恒高；无日志但单独开启字幕时回复 ready 恒 1，命令生效但不发送回复。两开恢复原有日志与回复仲裁。
2. 禁用字幕时 runtime 文本、长度、使能和 changed 明确置零，保留固定文字及 TEXT.BIN 情景字幕。保留 `osd_pixel_position` 的共享 frame_start/first_active，保护身份、参数与转场提交。共享模块端口、引脚约束、SD 调试采集及数码管不改。
3. 直接专项验证默认关闭、RX 流量无效、TX 空闲、共享帧边界及面板保留；原 UART 日志/字幕回归验证可恢复模块；受影响生产 top 最终像素、TEXT.BIN、音频/状态回归。
4. 使用新的 diagnostics/output 隔离目录完成 TD 综合、布局布线、STA 和 bitgen；实测 LUT/BRAM，对照基线审阅告警、未约束路径及 UART 常量引脚造成的变化。无 ERROR、Setup/Hold>0、TNS=0 才固定 local 候选。
5. 固定候选 bit、变化源码、实际设置/必要报告、验证及板测说明，同步 README、CHANGELOG、HANDOFF。上板验证 SD 调试页、双模式图片/字幕/音频/参数/切换与 UART TX 空闲；板测与 M6 旧待办保持真实状态。

不在本次执行字幕以外的图层裁减、SD 调试页删除或 BMP 头检查共用。资源收益以完整构建为准，不预填估算为实测。

## 执行记录

- 已检查分支、工作区及旧 worktree；只存在个人记录改动。计划先于 RTL 修改建立。
- S1本地完成：14092 LUT（71.90%）、9530寄存器、46 BRAM9k、2 BRAM32k、13 DSP；Setup +0.040ns/Hold +0.019ns，STNS/HTNS均0。LUT 16022→14092（减少1930，12.05%）；寄存器10686→9530（减少1156）；BRAM9k 56→46（释放10块）；BRAM32k和DSP不变。11份仿真/20份编译模型日志核验通过；固定[UART候选](../../../../releases/v0.18.0/uart-s1-local.1/README.md)，板测尚待反馈。

### S1 约束适配（首轮构建后补充）

TD attempt01 中，UART TX 常量化后，工具将原 `-to uart_tx` 的 10ns max-delay 错误扩展到 42455 条内部路径，遮蔽原 SD 时序约束，最终 Setup -15.747ns，拒绝作为候选。attempt02 尝试 Tcl if 存在性判断，但 TD 的 SDC 读取器仍无条件读入内部命令，此尝试同样不交付。

S1 最终采用最小 timing.sdc 适配：默认关闭 UART 时注释其三条 TX 延时命令；重新开启 `UART_LOG_ENABLE=1` 时必须同时取消三条 `# UART_TX_ON ` 前缀。用已启用 UART 的基线数据库验证恢复后的约束只覆盖原 1 条 TX 路径，关闭数据库验证默认约束不含 UART max-delay；随后重新完整构建并审阅 timing exception 范围。其余时序要求、引脚分配及 SD 调试页保持原样，不放宽内部路径时序。

attempt03 已注释 TX 约束，但 RX false-path 仍启用，且未开启基线 TD27 的 HighAreaOptimization，最终 15423 LUT、Setup -0.645ns/Hold -0.020ns、STNS -13.134ns/HTNS -0.083ns，同样拒绝交付。关键路径为原应用/缓存控制组合路径，Hold 涉及音频 RAM 地址；attempt04 恢复基线面积优化选项，以相同 RTL/约束重新综合及布局布线，不修改内部时序要求。

attempt04 获得14092 LUT、9530寄存器、46 BRAM9k，Setup +0.040ns/Hold +0.019ns、TNS0，但审计发现接收器删除后，旧RX false-path成为1条无效约束，不固定候选。最终同时注释 `# UART_RX_ON ` 这一条RX约束；恢复在线字幕时取消该前缀并审阅实际PAD FF目标。attempt05使用同一RTL和面积优化设置重新完整构建；约束探针constraints04基于最终SDC重验开启/关闭数据库。

## S1 最终交付

选用 `uart_reduction_td_attempt05`，默认UART双关，SD调试页保留。完整[验证](../../../../releases/v0.18.0/uart-s1-local.1/VALIDATION.md)及[真实板测入口](../../../../releases/v0.18.0/uart-s1-local.1/BOARD_RESULT.md)。111工程输入与根脚本逐字节一致，仅备份两个变化生产文件；个人记录原样不提交。恢复日志时，设置 `UART_LOG_ENABLE=1`，并取消 `timing.sdc` 三条 `# UART_TX_ON ` 前缀；恢复在线字幕另设 `UART_SUBTITLE_ENABLE=1`，取消一条 `# UART_RX_ON ` 前缀并审阅其输入寄存器目标。单开字幕时命令生效但无串口回复；两开恢复日志和回复仲裁。任何恢复配置均须重新验证、构建及审阅约束匹配。

按执行规则提交/推送当前分支与本次plan/local标签；不合并main、不发布正式版。当前无本地阻塞，等待本候选板测及前序M6内容/听审和整机实测。[本地阶段归档](README.md)。
