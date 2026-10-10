# v0.10.0-s2-local.1：UART 在线字幕

基于已板测通过的 v0.10.0-s1-board.1，在 feature/osd-gap-analysis 原目录实现 S2。固定下载文件为本目录 [demo.bit](demo.bit)，操作见 [上板步骤](BOARD_VALIDATION.md)。S2 尚未板测，S3 MM:SS 尚未实施。

新增 F12 RX、115200 8N1 接收、SUB 行命令、完整文本/长度/使能 mailbox、帧边界应用和独立回复排队。复用 D12 TX，日志与回复按完整行仲裁。字幕支持 12 槽在线 ASCII/课程汉字编号；复位保留 S1 的 15 槽默认中英标语。OFF 暂停滚动并隐藏字幕底条，ON 恢复；换文本从右侧重启。四 Bank、SDRAM、HDMI 音频及组合 RGB 路径保持原接口。

本地验证结果：

- UART 专项：真实 RX/TX 串行波形，CR/LF/CRLF、大小写转换、9 汉字编号、查询、12/13 字符边界、非法输入、帧错误、日志竞争、忙时完整提交和复位通过，0 Error/Warning。
- 运行时像素：144 行课程字模、665 帧、12,081,912 像素、92,354 字形像素通过，包含混排完整滚动周期、OFF/ON、清空、旁路与字形保护，0 Error/Warning。
- 真实 FAT32/BMP/SDRAM/FIFO 联合仿真：57 显示帧、22 次提交与 22 次音频提示，26,039,248 像素/消隐检查；4 组实际串口更新在帧边界应用。0 Error，18 条既有 IP/模型及测试台可选端口警告，不记为零警告。
- 21 项系统回归全部通过，包含原日志格式、启动/复位、播放控制、SD、HDMI 音频与视频对齐，各项 0 Error/Warning。
- 静态滚动 1,030 帧/19,422,858 像素、参数化滚动 23,040 像素及底条 614,400 像素通过，0 Error/Warning。
- 完整 TD `v010_s2_attempt3`：Setup **+0.105 ns**、Hold **+0.067 ns**，STA 覆盖率 **99.96%**；11,846 LUT、6,645 寄存器，较 S1 +1,741/+751；4 BRAM、2 DSP、1 PLL 不变。

时序审计：no clock、invalid constraint、combinational loop、no path constraint、shadowed/ignored exception 均为 0。与 v0.9.1 审计相比，no input delay 从 8 增至 9，仅新增异步 uart_rx；dummy node 4、PLL/clock buffer 1、no output delay 16、abnormal input delay 1 保留。RX 第一级已被 TD 合并为 F12 输入 PAD FF，例外仅从 uart_rx 到此单元；第二级仍为独立同步触发器。构建保留 SDRAM ECO 位置调整及 ext_mem_clk_sft 到 SDRAM_CLK 的单条局部布线警告；原 SDRAM 约束未放宽。工具审计不是板级信号完整性证明。

attempt1/2 的 RX 约束对象未匹配，虽有时序数值，均不交付。当前候选只使用 attempt3 bit。归档的 11 份生产变更相对 v0.9.1，未改源码从该基线取；当前 96 个工程/源码文件与本次构建快照逐字节一致，bit 与本次 phy_1 输出一致，见 [清单](SOURCE_MANIFEST.md)。完整快照与失败记录留在 diagnostics/output，不混入发布包。

协议和已知限制见 [实施合同](../../../docs/OSD_UART_S2实施计划.md)：一问一答，忙时合并最新完整配置，查询返回源域已接受状态；不支持通用 UTF-8、任意汉字和掉电保存，未覆盖的可打印 ASCII 字形显示问号。复位默认长度 15 是保留 S1 行为的明确例外，在线输入仍限 12。

阶段回退：[S1 bit](../s1-local.1/demo.bit)，对应 S1 local.2 / board.1；总回退：[v0.9.1](../../v0.9.1/demo.bit)。用户确认本候选功能正常后再建立 S2 board 标签和实施 S3。
