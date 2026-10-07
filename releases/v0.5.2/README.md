# 当前发布入口：刷新修复已验收

2026-10-07 用户确认“本候选 S3 全部通过”，随后确认“S4 全部通过”。验收对象为 v0.5.2-s3-local.2 / s3-board.2 同一 bit，629624 字节，已逐字节核对；发布未重新构建。

S4 Flash 写入校验、脱离下载器 10 次独立冷启动、5 次拔插恢复、30 分钟 AUTO 均按用户整体确认登记通过。Flash 型号/容量核对按整体确认记录；具体型号、容量数值及逐次日志未提供，不推测 flashsize 参数，不复用旧候选结果。

单 PLL C0–C4 为 100/40/40/25/125 MHz，C2 相对 C1 为 172.8°（12 ns），外部参考/面板 50 MHz。恢复功能及 CMD59/CRC7/CRC16/CMD55 修复保留。刷新调度为 1100 个 40 MHz 周期（27.5 μs），突发长度 64 字。

生产 FIFO、实际加密控制器和独立 DQ 功能模型下：完整帧 119 帧、36556800 像素、12 次提交、78197 次刷新；取消恢复 8 次提交、36249600 像素、77586 次刷新。刷新间隔均 1100 周期，无空读、混帧和冲突。SD 专项和 8 项稳定性回归通过。

TD attempt2 参数为 -HighFanoutOptimization -TimingOptimization ultra -PostPlaceOptimization high；Setup +0.128 ns、Hold +0.012 ns，30 个报告统计组无负端点；SDRAM 硬核边界 +6.612/+12.874 ns，覆盖率 99.89%。外部 I/O 延时仍未指定；DQ 模型是功能模型，不宣称完整电气时序验证。

[下载当前 bit](v0.5.2-s4-board.2/demo.bit) · [S4 验收](v0.5.2-s4-board.2/README.md) · [修复源清单](v0.5.2-s3-local.2/sources.txt)

下方为原 v0.5.2 发布历史，原 demo.bit 和标签保留；其中刷新失败已由本次修复及证据闭环取代。

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

2026-10-07 发布后新增[历史证据补测](evidence-2026-10-07/README.md)：完整帧 100/40/25 MHz 行为内存下逐像素、空读、AUTO、取消和恢复通过；实际控制器的完整帧请求轨迹刷新测试失败，最大观测间隔 3088 周期（77.2 μs），超过计划 1250 周期上限。刷新项由“缺证据”更新为“补测未通过”，物理 SDRAM 数据链路仍未完成验证。正式 bit 未修改，历史用户板测反馈保留。
