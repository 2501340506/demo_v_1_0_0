# 当前交接：宣传模式 M5 local.1 本地通过，待板测（2026-10-17）

- 当前任务：用户确认“M4功能正常”后实施M5；原目录feature/science-publicity-mode，输入eb7deb3/总体确认e548d72，开发回退v0.18.0-m4-board.1复用[M4原bit](../../../../releases/v0.18.0/m4-local.1/demo.bit)，正式回退v0.16.0。
- 已完成：参数、身份与AUTO门控整合；情景11焦点和提交同步阶段/音频/同页重播/退出预警。固定[候选](../../../../releases/v0.18.0/m5-local.1/README.md)、[操作与板测](../../../宣传模式操作与板测.md)，仅备份三个变化生产文件。
- 验证：183份仿真及69份编译/模型日志核验通过；生产最终像素/状态栏/PCM及旧卡/缺文件/恢复、双村、真实SDRAM系统/预览回归完成。TD `publicity_m5_td_attempt27`：16022 LUT（81.74%）、10686寄存器、56 BRAM9k、2 BRAM32k、13 DSP；Setup +0.006ns/Hold +0.030ns，TNS0，STA覆盖率99.97%，无ERROR、完整bitgen；111输入及根脚本、bit/变化源逐字节一致。审计及边界见[验证](../../../../diagnostics/publicity_mode/M5_VALIDATION.md)和[审计](../../../../releases/v0.18.0/m5-local.1/reports/AUDIT_REVIEW.md)。
- 卡住的问题：无本地阻塞；M5板测、正式内容/配音、M6≥40分钟与实际计时待办；不替前序补验收结论。
- 下一步：按操作说明上板，填[实际结果](../../../../releases/v0.18.0/m5-local.1/BOARD_RESULT.md)；获具体候选确认后才建board并同步。失败保留local.1，修复递增候选。M6须另获指令，正式发布/合并main仍待用户确认。
- 踩过的坑：情景预览直接走cache会使阶段/音频不同步；旧回归未启用宣传不能独立证明双应用输出；TD bitgen/exit0不代表时序通过。失败尝试完整保留在diagnostics/output。审计有既有dummy模型、无IO delay和sd_miso例外，不称零告警/全IO覆盖。个人问题记录原字节不改不提交，TD用户工程/best_result/旧worktree不操作，Python用py -I -X utf8。
- 归档：[M5阶段归档](README.md)。只推new-origin当前分支与M5 local标签，远程结果按实际引用核对；未发布v0.18.0。
