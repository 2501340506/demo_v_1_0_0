# v0.31.0 S1 候选 2：首启讲解等待约 4 秒（Seed 3）

基线 v0.30.0。问题：首次上电进入宣传模式时，画面出来时讲解已经播了一段。原因是显示器识别 HDMI 要 2 秒左右（v0.30 结论），而首图约 0.94 s 就提交，讲解紧接着开始。

## 改动

只改 [sd_card_bmp.v](sources/user_source/hdl_source/SD/sd_card_bmp.v) 的 `publicity_voice_control`：

- 新参数 `BOOT_FRAMES`，宣传模式设为 240 帧（约 4 s）。local.1 为 180 帧，用户板测反馈讲解仍早约 1 s。复位后数 HDMI 帧，没数满时讲解停在 WAIT，不发请求；数满后计数停止，不再生效。
- 首图早于 4 s 提交：讲解在第 240 帧开始。晚于 4 s：立即开始。
- 翻页、切换应用、AUTO、退出再进入宣传都不受影响。BIN 加载期间的 busy 等待照旧。
- 首图最短停留 5 秒从讲解开始计，所以首启时首图实际停留约 4 s + 5 s。
- 换更慢的显示器时改 `BOOT_FRAMES` 重新构建（8 位计数，最大 255 帧约 4.2 s）。

其余 RTL、约束、卡资源与 v0.30.0 相同。卡不用换。

## 交付

[demo.bit](demo.bit)，677358 字节，与构建目录 `diagnostics/output/v31b_s3` 的输出逐字节一致。Flash 加载时钟 16 MHz。**烧 Flash 后冷启动测试**（JTAG 下载 SRAM 也能看讲解延后，但不代表实际开机时间）。

## 验证

| 项目 | 结果 |
|---|---|
| 新增 `diagnostics/boot_narration/tb_boot_narration.sv`：早首图等到第 240 帧、晚首图/后续翻页/重新进入立即、busy 仍优先 | PASS |
| `tb_m4_auto`（300 帧下限、尾帧、手动优先等） | PASS |
| `tb_voice_equivalence`（默认参数与参考模型逐拍一致） | PASS |
| 整机控制器 case0 / 16 / 18 / 19 AUTO（25 MHz tone） | PASS |
| TD Seed 3（v0.29 构建选项，HighAreaOptimization 等） | Setup +0.252 ns / Hold +0.011 ns，STNS/HTNS=0，17777 LUT（90.70%） |
| TD 其余种子 37/5/11/17/23/59 | 不通过：均有 Hold 或 Setup 违例（sd_card_clk 域），未交付 |
| 上板 | 通过（2026-10-24，用户反馈“功能正常，首图音频效果满意”），见 [BOARD_RESULT.md](BOARD_RESULT.md) |

整机仿真一帧只有 100 时钟，240 帧窗口很快过去；case19 只证明流程没被破坏，4 秒实际时长需上板确认。Hold 余量 0.011 ns 很小，与历史 SD 时钟域问题同类。

## 上板检查

1. 烧 Flash，断电冷启动，SW 拨到宣传：讲解从第一句完整开始，首图期间不提前出声。
2. 首图停留约 9 秒（含亮屏）后 AUTO 才翻页（若开 AUTO）。
3. 翻页、切到场景再回宣传：讲解立即开始，无额外延迟。
4. KEY3 复位后同样等待约 4 秒。

## 回退

对 [v0.30.0 demo.bit](../../v0.30.0/demo.bit) 执行 Program Flash 并校验。
