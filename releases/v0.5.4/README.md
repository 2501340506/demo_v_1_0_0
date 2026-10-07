> 2026-10-07更新：用户确认S1全部通过；同一bit由v0.5.4-s1-board.1固定。S2接续开发，S1用户串口行尾r现象在S2处理。以下旧待上板描述属于候选阶段记录。

# v0.5.4 UART可观测性与首图快速显示

当前：S0完成，S1本地验证通过，等待用户上板后才上传GitHub并进入S2。

[固定候选bit](v0.5.4-s1-local.1/demo.bit) · [S1说明](v0.5.4-s1-local.1/README.md) · [板测表](v0.5.4-s1-local.1/BOARD_VALIDATION.md)。Setup +0.177ns、Hold +0.011ns；七套BMP、三组异步交接、八项回归及UART专项通过。未建立board/正式标签。

[阶段计划](../../docs/v0.5.4_UART与快速启动分阶段计划.md) · [复现](../../diagnostics/uart_fastboot/README.md)

S1增加D12 UART 115200/8N1启动版本行；不包含完整事件日志或快速启动。S2事件、S3暂停续扫、S4快速启动分阶段交付。
