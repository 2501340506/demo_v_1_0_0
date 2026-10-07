# v0.5.2 — 单 PLL、40 MHz SDRAM 与 TF 恢复

2026-10-07 发布。用户确认 S3 全部 SRAM 项目及 S4 全部规定测试通过。

[正式 bit](demo.bit) · [S3 验收](v0.5.2-s3-board.1/README.md) · [S4 验收](v0.5.2-s4-board.1/README.md) · [归档](../../docs/history/2026-10-07/v0.5.2/README.md)

正式 bit 为 629624 字节，沿用 s3-local.1 → s3-board.1 → s4-board.1 同一产物，逐字节一致；发布未重新构建。

|PLL 输出|频率|相位|用途|
|---|---|---|---|
|C0|100 MHz|0°|SD/控制及 BUFG 外部反馈|
|C1|40 MHz|0°|SDRAM 控制|
|C2|40 MHz|172.8°，12 ns|SDRAM 采样|
|C3|25 MHz|0°|像素与音频|
|C4|125 MHz|0°|HDMI 串行|

外部输入及面板保持 50 MHz；唯一 PLL 锁定信号驱动五域三拍高有效复位，PLL reset 只接外部复位。

KEY2 短按松手翻图，任意模式长按 2 秒重初始化与重扫；恢复保留旧图，新首图提交后回 MAN 并提示一次。保留 CMD59、CRC7、CRC16 和 CMD55 合法 00/01 响应修复。不增加自动插卡检测、写卡或 Flash 参数持久化。

S4：Flash 写入/校验、脱离下载器 10 次独立冷启动、5 次拔插恢复、30 分钟 AUTO 全部通过（来源：用户整体确认；未提供逐次日志、Flash 型号后缀或额外次数）。

## 构建和证据边界

沿用 TD 6.2.168116 attempt4，参数 `-HighFanoutOptimization -TimingOptimization ultra -PostPlaceOptimization high`。[完整时序](v0.5.2-s3-local.1/timing/demo_pr.timing)报告 Setup +0.168 ns、Hold +0.041 ns，无报告内负端点，覆盖率 99.89%。保持 SDRAM 硬核边界分析及像素/串行相关路径；板级 I/O 延时未指定，不能视作所有外部时序均已证明。

PLL 厂商模型验证周期与相位通过，load_reg 声明冲突产生两个宽度警告。控制、SD 协议/CRC、音频、HDMI、视频、复位/启动日志见候选 simulation。`refresh_expression.log` 是修复前 period=8、refresh_macro=0 的问题复现，不能用作修复通过证据。修复后宏为 25 ns、终值 1249；真实刷新最迟服务、完整帧 100/40/25 MHz FIFO 空读和刷新竞争专项证据未齐，早先“本地验证全部完成”的表述过宽。用户板级通过单独成立，不补造这些仿真结果。

源清单见 [source_inventory.md](source_inventory.md)。旧候选、旧标签与原始证据全部保留。
