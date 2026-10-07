# v0.5.4最终验收摘要

2026-10-07。最终采用已获用户“功能正常”确认的S3 local.2；[板测记录](S3_board_validation.md)和[UART原文](S3_local2_board_uart.txt)保留。S4用户明确跳过；S5无RTL、约束或构建变化，不重复要求相同板测。

正式releases/v0.5.4/demo.bit与S3 local.2原bit逐字节一致，629624字节；生产源码及既有验证脚本与v0.5.4-s3-board.2一致。串口保留BOOT v0.5.4-s3-local.2。未重新构建，未将其他候选或诊断的结果套用到该文件。

复用S3证据：七套BMP、三组像素交接、三组重扫、八项既有回归、UART独立接收模型以及扫描接口专项通过；生产关闭接口时与S2逐拍对比1856569拍/307200像素通过。TD Setup +0.121ns/Hold +0.014ns、覆盖99.92%，原警告保留。S3旧失败版本的全帧补测不冒充local.2重测结果。

用户整体确认首图、MAN/AUTO、音视频及恢复正常；没有新增冷启动次数、长稳时长等验收要求。S3早期失败的具体物理根因未证明，历史失败与对照记录不撤销。

本次仅版本与文档收尾。用户原有TD_project/demo.al、best_result和.recent_user_depot.ini保持不变，不纳入提交。未验收阶段本地文件移入diagnostics/output/v054_s4_skipped_archive，不删除、不纳入本版。
