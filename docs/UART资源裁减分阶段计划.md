# UART 资源裁减分阶段计划

日期：2026-10-18。用户授权：去掉串口日志与串口在线字幕，保留数码管 SD 调试页。先补计划再改代码。本次独立于宣传 M6 的内容/整机验收，不改写其结果。

## 基线、回退与标签

- 原目录开发，分支 `feature/uart-resource-reduction`，起点 `075ab05`（`v0.18.0-m6-local.1`）。已有个人 `问题小记录.txt` 原字节保留、不提交；旧 worktree、用户 TD 工程和 best_result 不动。
- 硬件对照/开发回退为 M5 board.1 / M6 local.1 共用的 [M5 固定 bit](../releases/v0.18.0/m5-local.1/demo.bit)，正式回退 [v0.16.0](../releases/v0.16.0/README.md)。参考资源 16022 LUT、10686 寄存器、56 BRAM9k、2 BRAM32k、13 DSP；Setup +0.006ns、Hold +0.030ns。
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
- 验证、构建与候选结果待实施后回填。
