# v0.8.0 S1 local.1：读写分离候选

这是 v0.8.0 四 bank 帧缓存的 S1 本地候选。S1 只完成 loader/reader 分离，生产调度仍为双缓冲；四 bank 缓存控制属于后续 S2/S3，不能把本候选描述为四图驻留完成。

## 基线与下载

- 基线：分支 `feature/four-bank-frame-cache`，提交 `1c68673`；回退使用 `releases/v0.7.0/demo.bit`。
- 候选 bit：[demo.bit](demo.bit)，由 TD 6.2.168116 在 EG4S20BG256 生成。
- 本候选构建：`four_bank_s1_attempt2`，TD 工程快照见 [project/demo.al](project/demo.al)，相对基线修改/新增源码见 [sources](sources)。
- 资源：9205 LUT、5793 寄存器、4 BRAM、2 DSP、1 PLL；具体报告见 [reports/demo_phy.area](reports/demo_phy.area)。
- 路由时序：Setup WNS +0.100 ns、Hold WNS +0.030 ns，STA coverage 99.95%，见 [reports/final_timing.rpt](reports/final_timing.rpt)。
- `check_timing`：0 个无时钟、0 个无路径约束；保留现有 v0.7.0 的 8 个无输入延时、16 个无输出延时和 1 个异常 SPI 输入延时，均为既有板级接口边界，未新增未约束时钟。

## 已验证

- ModelSim 真实 SDRAM 控制器、厂商 FIFO 和 BL4 命令/DQ 模型：四个逻辑 bank 逐像素读回、RGB/垂直翻转、并发读写、刷新间隔；17 个显示帧通过，刷新间隔 1100 周期。
- loader：源失败、短帧、FIFO 溢出、写停滞、活动 burst 取消均不提交失败帧；最后像素同时 EOF 的路径通过。
- reader：显示下溢输出黑色、HS/VS/DE 保持，下一帧 FIFO 重建恢复。
- 现有 FAT32/SD/按键/AUTO/音频/视频/启动回归通过；六组原异步交接测试在 split 端点上通过（17/2、19/16、23/64 三组时钟/源间隔）。
- 启动和复位测试通过。完整日志在候选 [evidence](evidence)。

## 尚未验证与限制

- 用户尚未确认上板，因此这是 `local.1`，没有 `board` 标签；不能据此声称板级通过。
- S2 四 bank cache controller、首图后台补齐、bank 映射和重扫保图尚未实施。
- 长时间 Flash 冷启动、拔插、持续 AUTO、实际 HDMI 显示质量、SDRAM 器件电气裕量尚未由用户确认。
- ModelSim 的 2685/2718 FIFO 空端口、2121 加密 IP 未定宽常量告警保留在日志中；其他 Error/Fatal 均为 0。SDRAM BL4 模型不是器件电气签核模型。
- 完整 bit 已固定在本目录；TD 运行目录及失败输出留在 `diagnostics/output`，未复制到 releases。

## 上板反馈格式

请记录使用本目录 `demo.bit` 的实际结果：首图启动、手动四图往返、AUTO、加载期间按键、重扫保图、音频/HDMI、异常卡恢复，以及测试时长和失败现象。用户确认该具体候选后，才能建立 `v0.8.0-s1-board.1`。

[源码清单](sources.txt) · [四 bank S1 验证说明](../../../diagnostics/four_bank/README.md) · [阶段计划](../../../docs/四bank帧缓存分阶段修改计划.md)
