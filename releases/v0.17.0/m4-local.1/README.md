# v0.17.0 M4 local.1 本地候选

M4 已实现四阶段场景状态机、SND1–4 分段播放及逐槽 BGM 回退、样本驱动时间轴和音画切换淡入淡出。生产提交 `0540d43`，开发输入 `v0.17.0-m3-local.1`（4aab2ba），候选标签 `v0.17.0-m4-local.1`，分支 `feature/mountain-escape-classroom`。正式版及已板测回退仍为 v0.16.0。

上板使用固定 [demo.bit](demo.bit)（664544 字节），按 [板测步骤](BOARD_VALIDATION.md) 验证；[场景素材清单](board_samples/manifest.json) 对应 board_samples 中四张 BMP 和四段 PCM。拨码所有 mode 已占用，场景入口为 `00` 下长按 KEY4 1 秒。场景中 KEY2 短按下一阶段、KEY1 科普/预警、KEY4 短按 1×/2×/4×；KEY4 长按或拨码离开 00 退出，KEY2 长按 2 秒仍重扫。

完整 TD attempt04（strategy 7 / timing high / high fanout）结果：15181 LUT（77.45%）、8882 寄存器、56 BRAM9k、0 BRAM32k、13 DSP，Setup +0.133ns/Hold +0.004ns，TNS 0。68 份仿真、22 份编译日志与 12 项 PC 工具测试通过；108 个实际构建输入逐字节一致。见 [验证记录](VALIDATION.md)、[输入清单](MANIFEST.md) 和 [时序报告](reports/final_timing.rpt)。sources 仅保存相对 M3 变化的 11 个生产输入，其余引用 M3 标签。

本候选尚未板测；M1/M3 板测及 M2 目视也待确认。四段音频是各 8 秒的占位音效，旁白关键词同步、物理 SD/HDMI 行为和无爆音须实际验收。FONT/TEXT、预警边框、速度 OSD 和阶段数码管属于 M5；整机持续运行、Flash 及冷启动属于 M6。未建立 board 标签，未推送。

异常时回退 [v0.16.0 固定 bit](../../v0.16.0/demo.bit)，保留本候选并递增 local 编号。用户工程、best_result、旧候选和既有素材均保留。
