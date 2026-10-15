# v0.17.0 M5 local.1 本地候选

M5 已完成 FONT/TEXT 扫描和两块 BRAM32k 加载、卡上中文字库与阶段标题/字幕、预警红框、速度参数条及阶段/A 数码管。无有效文件时保留原文案和 case 字库回退；PC 工具新增 FONT/TEXT 生成。生产提交为 `ba79e51`、`74a79d3`，开发输入 `v0.17.0-m4-local.1`（e7bfa29），候选标签 `v0.17.0-m5-local.1`，分支 `feature/mountain-escape-classroom`。正式版回退仍为 `v0.16.0`（1818adc）。

上板使用固定 [demo.bit](demo.bit)（673856 字节），按 [板测步骤](BOARD_VALIDATION.md) 验证。将 [board_samples](board_samples/manifest.json) 中四张 PIC、四段 SND、FONT.BIN（1536 字节）、TEXT.BIN（104 字节），共十个文件放入 FAT32 卡根目录，换卡后复位。四张 PIC、四段 SND 与 M4 固定素材逐字节一致。

拨码 `{SW2,SW1}=00` 下长按 KEY4 至少 1 秒进入/退出场景；KEY2 短按下一阶段，长按至少 2 秒重扫；KEY1 切换科普/预警；KEY4 短按切换 1×/2×/4×。预警显示第四阶段、A、固定预警语及四周 8px 闪烁红框；科普显示各阶段标题和滚动字幕。

合格 TD 构建为 `mountain_m5_attempt24`：14897 LUT（76.01%）、9707 寄存器、56 BRAM9k、2 BRAM32k、13 DSP，Setup +0.008ns/Hold +0.014ns，TNS 均为 0，无 ERROR、完整 bitgen。112 份仿真、28 份编译日志和 15 项 PC 测试通过。111 个工程输入与构建逐字节一致，sources 仅保存相对 M4 变化的 13 个输入，其余引用 M4 标签。见 [验证记录](VALIDATION.md)、[输入清单](MANIFEST.md)、[时序报告](reports/final_timing.rpt) 和 [复现入口](../../../diagnostics/mountain_scene/M5_TESTS.md)。

审计新增 FONT/TEXT 两个 `ram.dob[9]` dummy-node 报告，其余汇总与所有时序例外同 M1；该报告原因未进一步定位，原始证据保留。时序余量较小，M5 尚未上板，未建立 board 标签、未推送 M5。M4 用户总体反馈“暂无大问题”已单独记录，不替代本候选验收。四段声音仍为占位音效，不能证明旁白关键词同步；ffmpeg 重采样路径未实测。M6 第二张卡、40 分钟稳定性、Flash 与冷启动计时未实施。

请在 TD GUI 重新加载磁盘工程后再保存，避免旧内存工程丢失三个新增源条目。异常时保留本候选，修复后递增 local 编号；可回退 [v0.16.0 固定 bit](../../v0.16.0/demo.bit) 或对比 [M4 固定 bit](../m4-local.1/demo.bit)。
