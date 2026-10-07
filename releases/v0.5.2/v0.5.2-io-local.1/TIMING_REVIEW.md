# SPI / HDMI I/O 时序补全

2026-10-07。本地候选：`releases/v0.5.2/v0.5.2-io-local.1/`。生产源码已更新；旧正式下载仍是 s4-board.2。本候选已获用户“上板验证功能都没问题”的整体确认；用户随后明确免除 Flash、冷启动、拔插次数及长稳专项，本次验收通过，未重新构建。

## 结果

| 项目 | 旧基线 | 本候选 |
|---|---:|---:|
|全局 Setup / Hold|+0.128 / +0.012 ns|+0.148 / +0.011 ns|
|STA coverage|99.89%|99.90%|
|SD 传输频率|25 MHz|16.667 MHz|
|SD 初始化频率|200 kHz|200 kHz|
|MISO setup / hold|无外部输入预算|+7.412 / +0.014 ns|
|MOSI、CS setup / hold|无外部输出预算|+17.313 / +8.879 ns|
|SCLK clk-to-pad|4.620 ns，仅补测|4.620 ns，限值 5 ns|
|HDMI clk-to-pad|2.573 ns，仅补测|2.573 ns，限值 3.5 ns|
|SDRAM 控制→采样 setup / hold|+6.612 / +12.874 ns|+6.138 / +12.874 ns|

时钟仍是单 PLL 100/40/40(+12 ns)/25/125 MHz；顶层端口、按键行为、显示格式不变。SPI 单字节线传输时间从 320 ns 增至 480 ns，图片加载会变慢；具体整图耗时受卡响应、扫描及控制开销影响。没有改变全局 uncertainty，也没有切断 SDRAM 或像素/串行时钟分析。

## 预算来源与 SPI 建模

- 本地 `SDSDv17.pdf`（SanDisk SD Card Product Manual rev.1.7）：PDF 第 36–37 页表 3-7，输入 setup/hold 均 5 ns、输出 tODLY 0–14 ns；第 103 页 §5.5–5.7 明确 SPI 电气和总线时序沿用 SD 模式，CS 按其他卡输入处理。适用负载条件 CL≤25 pF。
- 使用板载卡座、无额外延长线的工程预算：每程 PCB/连接器延迟 0–1 ns，往返最多 2 ns；输出数据与时钟板级差异最多 1 ns。这是用户接受的设计适用条件，不是已测量的 PCB 数据。
- 生产模式 CPOL=1、CPHA=1。100 MHz 状态机每 `clk_div+2` 拍翻转 SCLK，下降沿发数据、上升沿采数据。MISO 在生成上升沿的系统时钟边沿采入，因此返回预算必须包括 SCLK 输出延迟，不能把外部卡上观察到的上升沿直接当成 FPGA 采样时刻。
- SCLK clk-to-pad 限值 5 ns；卡输出 14 ns、往返 2 ns，故输入 max delay=21 ns，min=0 ns（保守地允许新数据更早到达）。仅从 sd_miso 到 SD 时钟域的直接输入采样锥使用 setup=3、hold=2 的多周期约束。最终实际唯一端点为 `spi_master_m0/MISO_shift_reg[0]_syn_4.d[0]`；其他 SD 内部路径不受影响。
- MOSI/CS output max=6 ns、min=−6 ns，包含 5 ns 卡要求及 1 ns 板级差异；setup=3。hold=3 将检查放到前一个 100 MHz 边沿，实际协议在采样后仍至少保持一个 SPI 半周期，独立引脚测试检查真实 5 ns hold，首位、末位与片选切换均覆盖。
- 旧 25 MHz 半周期 20 ns 小于 `4.620+2+14+3.796` ns，尚未计入建立时间已不足。选择最小下一级分频 1，半周期 30 ns；没有增大卡允许延迟或切除输入路径。
- 独立延迟仿真采用 SCLK 输出 5 ns、每程板级 1 ns、卡输出 14 ns、输入路径 4.2 ns，另检查 0.2 ns 采样稳定量。候选报告中输入路径+建立时间+默认 0.1 ns uncertainty 共 3.633 ns，在模型包络内。默认时钟边沿间的额外偏差保留 0.5 ns 工程余量，返回总预算 `21+4.2+0.2+0.5=25.9 ns < 30 ns`。
- 约束中的最短半周期是三拍；任何将 SPI_HIGH_SPEED_DIV 改回 0、改变 100 MHz 控制频率或改变采样状态机的修改，都须重算预算。慢速初始化半周期 2500 ns，沿用更严的快速预算。

## HDMI 双沿预算

四路均使用硬 I/O ODDR，125 MHz DDR 对应 4 ns UI。生产限制 clk-to-pad≤3.5 ns，给单 UI 留出 0.5 ns 工程余量；它是数字传播时间上限，不是 HDMI 接收器建立/保持规范。

TD 的 `set_max_delay -datapath_only` 会抑制该输出路径的 hold 检查，因此额外用独立测量 SDC 提取快/慢角、上升/下降沿共 16 条路径。该测量 SDC 不参与候选构建，其宽限值只用于展开路径。候选慢角 clk-to-pad=2.573 ns，快角=2.031 ns；各通道同角同沿延时相同。包含时钟网络后的跨角跨沿到达时间包络为 3.215–4.404 ns，跨度 1.189 ns。

采用 HDMI 板级数据—时钟相对偏差≤0.25 ns，加 0.5 ns 接口工程余量：`1.189+0.25+0.5=1.939 ns < 2 ns`（半 UI 工程检查窗口）。这是对当前 FPGA 数字输出的保守预算检查，未测量走线、线缆、接收器抖动或模拟眼图；不将其称为 HDMI 电气认证。

## 未覆盖项审查

原报告 99.89% 是 TD 的 STA coverage，不是“有 0.11% 寄存器没时钟”。TD 手册没有给出可用于从百分比反推端点数量的完整分母定义，因此不声称百分比与下面清单一一对应。

原始 Check-Timing 清单列出 4 类物理模型、实际 108 个 dummy 管脚：96 个未用 LUT 半片输入、9 个未用寄存器 MI 输入、1 个不影响保留乘积位的高位输入、2 个常量 SDRAM 控制输出。候选布局改变后为 152 个管脚，分别 130/19/1/2。逐管脚清单和对应网表片段随候选保存。

判断依据：LUT f/fx 输出悬空且寄存器不存在或绕过 LUT 直接使用 MI；MI 所属寄存器 q 悬空；乘法器乘数为 1 且高位乘积不使用；SDRAM CS=0、CKE=1。脚本遇到无法解释的节点会失败，不把所有 dummy 一概标为可忽略。

| 剩余检查项 | 端点及处理 |
|---|---|
|8 个 no_input_delay|key1/key2/key4/sw1/sw2 为异步机械输入；rst_n 为异步复位源；HDMI_DDC_SCL/SDA 无接收逻辑。没有为这些信号编造同步外设输入延迟，也没有扩大 false_path。同步器后级和域内复位释放继续分析。|
|16 个 no_output_delay|seg_data[7:0]、seg_sel[5:0] 为无外部采样时钟的 LED 驱动；DDC 两线固定高阻、不实现协议。均非本项目同步数据接口。|
|1 个 abnormal input delay|21 ns 大于 100 MHz 周期，TD 通用检查提示；本接口为 CE 采样，实际 setup 窗口 30 ns，成对 MCP 详细路径及独立仿真均已验证。|
|PLL/buffer clocks(1)|一个 PLL 检查组，组内未约束输出数及频率不匹配数均为 0。另见下方实际本地反馈布线警告。|
|其余|no_clock、clock definition、invalid constraint、no-path constraint、partial I/O delay、组合环均为 0。|

额外发现：Check-Timing 日志给出 `USR-6135`，PLL 反馈使用本地网络，补偿延迟不可预测。布局日志另有 `PHY-5079`，但 CTS 表实际指向 `ext_mem_clk_sft / U3/u2_ram/SDRAM_CLK`，不能将两者归为同一路径。旧基线与新候选均有这些警告。当前预算结果是 TD 模型与上述板级假设下的结果；警告未由本轮消除，不能宣称整个时钟物理实现无警告。需另行核实厂商对反馈连接及 SDRAM 移相时钟布线的要求，本轮按计划保留单 PLL 配置，候选待实板验证。

## 复现与实际验证

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/io_timing/run_sim.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/io_timing/build.ps1 -Name io_timing_reproduce1 -Seed 3
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/sd_recovery/run_tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/sd_recovery/run_handoff.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/stability/run_stability.ps1 -Suite baseline
```

本轮实际通过：快慢延迟边界、初始化速度/传输速度、4 字节首末位/连续收发、旧 25 MHz 失败负对照、超预算失败负对照；含外部延迟的完整 SD 引脚初始化/CMD59/CRC7/CRC16/主机复位恢复与卡输入建立保持检查；SD 四专项；三组恢复异步交接；完整 640×480、307200 像素读取。后两项使用扇区/内存模型，不冒充物理卡整图板测。

构建使用 high-fanout high、timing ultra、post-place high、seed 3。首轮参数层级遗漏已修正；默认 seed 下内部地址路径 −0.115 ns，post-place ultra 无改善；seed 2 为 −0.151 ns，seed 3 收敛。失败尝试保留，不交付为候选。

上板功能验证已按用户整体反馈通过。用户明确免除后续 Flash 校验、10 次冷启动、5 次拔插恢复与 30 分钟 AUTO，本次验收通过；免测专项不再作为待办，也不记为实测完成。
