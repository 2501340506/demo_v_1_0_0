# v0.5.2-io-local.1 — SPI/HDMI I/O 时序候选

2026-10-07，本地验证完成，**用户确认上板功能验证通过，并明确免除后续专项，本次验收通过**。正式下载入口仍为 s4-board.2。

- bit：本目录 demo.bit，629624 字节，与独立 attempt5 构建输出逐字节一致；生产源码与 source/user_source 逐文件核对一致。
- SD 初始化保持 200 kHz，数据传输由 25 MHz 改为 16.667 MHz，使卡最大输出延迟、板级往返及 FPGA 输入路径适合 30 ns 半周期。SPI 数据 setup/hold 保留分析，未放宽 SD 内部路径。
- HDMI 四路加入 3.5 ns 数字输出传播上限；另保存快慢角、上升下降沿 16 条路径和偏差检查。
- Setup +0.148 ns、Hold +0.011 ns，无报告内负端点；SDRAM 边界 +6.138/+12.874 ns；coverage 99.90%。新增 I/O 约束有实际命中路径。
- TD 6.2.168116：high-fanout high / timing ultra / post-place high / seed 3。复现：diagnostics/io_timing/build.ps1 -Name <新名称> -Seed 3。

预算与限制：[IO_TIMING.md](../../../../docs/timing_closure/IO_TIMING.md)。板级延时采用工程假设，非实测数据；未完成 HDMI 模拟眼图认证。既有 USR-6135 为 PLL 反馈警告，PHY-5079 的 CTS 表则指向 SDRAM 移相时钟本地布线，两者不可混同。上板功能通过不改变这两项工具警告的记录。

证据：timing/CHECK_RESULTS.md、timing/nodes.md、timing/check_timing.txt、完整 summary/exception/双沿报告及 tests/ 仿真日志。最终 152 个 dummy 管脚均已分类，剩余 8 输入/16 输出无 delay 均按用途解释；未将 coverage 百分比反推为端点数量。

## 本地测试

- 200 kHz、16.667 MHz 及快/慢返回边界通过；旧 25 MHz、超预算延迟两个负对照正确失败。
- 外部延迟下真实引脚初始化、CMD59、CRC7/CRC16、主机复位恢复及卡端 setup/hold 通过。
- SD 四专项、三组恢复交接、640×480 全部 307200 像素测试通过。
- HDL 改动仅两层 SPI 默认分频参数；HDMI RTL 未修改。图片加载速度有所降低。

## 板级验收

2026-10-07 用户反馈“上板验证功能都没问题”，按本候选上板功能整体通过登记。C0 仍为 100 MHz，SPI 数据传输为 16.667 MHz；未重新构建。未提供逐项测试次数或加载耗时，不补造数值。

功能检查范围：首次显示、手动翻图、AUTO、图片提示音、KEY2 长按重扫、拔插恢复及保留旧图；以上按用户整体反馈记录，不作为独立逐项日志。

2026-10-07 用户明确要求后续 Flash 写入校验、10 次冷启动、5 次拔插恢复及 30 分钟 AUTO 长稳验证不需要做，记录本次为通过。上述专项按用户决定免测，不再作为验收待办；本次验收通过，不将免测项目记为实测完成。
