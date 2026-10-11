# v0.11.0-s1-local.1：图片淡出淡入（2026-10-11）

固定下载：[demo.bit](demo.bit)。请按 [上板步骤](BOARD_VALIDATION.md) 验证。本地验证已完成，等待用户上板确认。

S1 手动上一张/下一张和 AUTO 均使用淡出到黑、实际切换、淡入。每侧 16 视频帧，完整过程约 0.53 秒加帧提交等待。目标未缓存时保持原画面，缓存就绪后才启动效果；首图、重扫恢复首图及同 bank 提交旁路。转场期间仍保留 OSD、字幕滚动、MM:SS 和原提示音。AUTO 间隔从完整淡入结束重新计时；忙时 next/previous 各保留一项，重扫等待当前转场结束。

沿用正式基线 v0.10.0，并保留计划之后 b76ec4f/d3c7996 的字幕与字模修改，默认 `胆子肥嘟嘟的 FPGA `。本候选尚未上板，不继承旧版板测结论。S2 的 AUTO 黑底水平揭示未启用；真正新旧图 Wipe 不在此版范围。

实现：控制域接受缓存已准备好的显示事务，像素域按帧改变 level；start/black/done 以 toggle 跨域。全黑许可控制原显示请求发出，真实 reader ack 不延迟。原媒体提交 CDC 保留提示音，并在像素域触发等待下一帧淡入。RGB888 运算在 OSD 之前，零额外像素延迟，level=16 精确透传、0 精确全黑。顶层 TRANSITION_ENABLE=0 可编译回旁路。

已通过的独立证据：异步专项 3 次事务、延迟提交、复位与旁路、27,648 RGB 检查；播放器联动 5 次提交，连续按键方向缓存和 AUTO 完整间隔；21 项相关回归；关闭效果完整缓存系统 57 帧、22 次实际提交/提示音。

完整 TD attempt2：Setup +0.117 ns、Hold +0.011 ns，覆盖率 99.96%；11,776 LUT、6,677 寄存器、4 BRAM、4 DSP、1 PLL。约束未修改；check_timing 分类与基线一致，no clock、invalid constraint、combinational loop、no path constraint、ignored exception 为 0。保留既有 SDRAM ECO 位置警告和 ext_mem_clk_sft → SDRAM_CLK 的单条局部布线警告，不声称无工具警告。

首轮 TD attempt1 Setup −0.087 ns，未交付；第二轮调整布局优化选项后通过。前序接线仅 lint 通过，不是阶段验收；本候选修正了许可错接缓存 ack 以及多位亮度跨域的问题。完整失败记录和复现命令见 diagnostics/transitions/VALIDATION.md。

完整启用转场联合测试 full2 通过：582 显示帧、17 次完整转场/17 个黑场、22 次提交与 22 次提示音、180,326,400 个转场像素检查；OSD 587 帧快照、246,539,248 个像素/消隐检查，4 组 UART 命令帧提交。0 Error，18 条既有 IP/模型及可选端口警告。83 个工程输入与 attempt2 构建快照逐字节一致；固定 bit 为 629,624 字节，与构建 bit 逐字节一致。相对 v0.10.0 的 10 个变更生产文件已归档，包含后续字幕修改，未改文件引用基线。详见 [清单](SOURCE_MANIFEST.md)。上板后确认才能建立 board 标签并进入 S2。总回退 releases/v0.10.0/demo.bit，保留其原字幕内容。
