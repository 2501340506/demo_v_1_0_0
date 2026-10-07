# 当前交接：S3 local.2待板测，未提交

- 任务：修复S3 local.1首图花屏，完成本阶段后再进入S4。
- 用户证据：local.1首图花屏，S2回退正常；用户明确确认S2_parser_S3_banner.bit对照功能正常。不能将对照通过登记为原S3通过。
- 改动：ENABLE_SCAN_PAUSE默认0，生产显式关闭，专项显式启用；UART标识s3-local.2。PLL/SDRAM/约束/构建优化参数不变。
- 完成：开启专项、关闭时S2逐拍对比1856569拍/307200像素、七套BMP、三组像素交接、三组重扫、八项回归、UART通过；TD +0.121/+0.014ns，5885 LUT/3755寄存器，无新增告警类型。
- 卡点：local.2尚待板测，具体综合/物理根因尚未证实。当前仅缩小范围并明确隔离未启用逻辑，不宣称花屏已修复。
- 下一步：用户下载local.2先看首图；正常再确认MAN/AUTO、音视频和恢复。通过后才能commit、打标签和push，再进入S4；失败则沿此对照继续调查。
- 用户明确规则：上板通过前禁止本地commit、创建标签及push；本轮只修改工作区。旧S3已提前创建的提交/标签保留，不擅自改写。
- 产物：releases/v0.5.4/v0.5.4-s3-local.2/demo.bit；此名称只是候选名，未建同名标签。仅16个改动代码/测试/脚本，基线S2 board.2；完整隔离快照diagnostics/output/v054_s3r2_final。
- 踩坑：原local.1和对照BOOT相同，必须确认具体下载文件；新候选已改为local.2。scan_paused表示扫描事务暂停，加载时仍可为1。正时序裕量不能代替板测。
- 用户TD工程/best_result保留，不批量删除文件，不修改旧bit或标签。S4未实施。

[候选](releases/v0.5.4/v0.5.4-s3-local.2/README.md) · [故障记录](docs/history/2026-10-07/v0.5.4/S3_board_failure.md) · [阶段计划](docs/v0.5.4_UART与快速启动分阶段计划.md)
