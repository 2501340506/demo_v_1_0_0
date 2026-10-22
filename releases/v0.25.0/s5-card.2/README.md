# v0.25.0 S5 情景卡 2：整段旁白作字幕（卡资源包）

四个 SW3 场景目录的 FONT.BIN、TEXT.BIN、SND1–4.PCM，共 24 个文件。**SND 与 [s5-card.1](../s5-card.1/README.md) 逐字节相同**，只有 FONT/TEXT 变了：每个阶段底部滚动的字幕不再是我精简的一句话，而是这个阶段的整段旁白（各句之间空两格），和参考项目 A 的卡一样。

> **这个包只能配 [s5-local.6](../s5-local.6/README.md) 或更新的固件。** 字幕最长 40 字，旧固件（包括 s5-local.1–.5）每段最多认 31 字，会判定文字文件有错，整个场景的字都不显示。

## 和参考项目 A 的卡对照

按屏幕上实际画出的点阵逐段比较（A 和本项目的 TEXT.BIN 段号顺序、转义码编号不同，但画出来的字一样）：四张卡的村名、预警语、4 个标题、4 段字幕、4 行图例，**56 段全部与 A 一致**。字形数：滑坡 102、泥石流 102、山洪 89、地震 110（上限 128）。

## 生成与验证

- 生成：`python -I -X utf8 tools/mountain_port/make_card_narration.py prepare --legends --output diagnostics/output/<新目录>`；`scene.yaml` 里去掉了 v0.25 S2 加的 `subtitle:`，于是用旁白。两次生成逐字节一致。
- 仿真：`diagnostics/lut_opt25/run_s5_overlay.ps1`，用生产的 `scene_text_overlay` 对这四张卡逐像素比对，通过；用真实 RTL 渲染的滑坡卡四帧与 A 的示意图逐像素一致。
- 写卡用 `install --card <卡盘符>/情景模式 --output <同一目录>`，被替换的原文件先备份。**写之前确认固件已经是 s5-local.6 或更新。**
- 2026-10-23 已写入用户的 SD 卡（G 盘），固件 s5-local.8 板测正常之后写的：24 个文件写入并读回一致；被替换的 24 个文件已备份，与 s5-card.1 逐字节一致；PIC、THUMB 和宣讲模式的其余 30 个文件未变。写卡清单见 `validation/card_write_result.json`。**整段旁白字幕在板上的效果待用户确认。**

回退：用 [s5-card.1](../s5-card.1/README.md)（精简字幕，配 s5-local.1–.6 都可以）的同名文件覆盖。
