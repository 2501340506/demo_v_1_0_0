# v0.17.0-m6-local.1 本地候选

开发基线 v0.17.0-m5-local.1（34d7a82），功能实现 bc19864，分支 feature/mountain-escape-classroom；正式回退 v0.16.0。本候选完成本地验证后固定，板测与正式发布尚待用户确认。

## 本次变化

- 恢复 KEY4 短按 AUTO；场景 KEY1 长按一秒调速 1X/2X/4X，短按切换预警，长按松手不误触短按。KEY4 长按进/退场景、KEY2 下一阶段/长按重扫保留。
- 场景 AUTO 等当前动画到 t=239 并显示完整终态帧后切阶段；进入场景继承普通 AUTO，退出后普通 AUTO 关闭；预警保持，不自动离开。
- 普通场景文字改为黑色 32px，预警语居中红色 32/64px 周期缩放，保留闪烁红框；SND4 循环警报。缺资源回退及旧 UART 字库保留。
- 固定“示意村”和“山洪村”两套场景卡；第二张卡具有独立底图、文字、路线和避险点，同一份 bit 可读取两卡。

## 下载与拷卡

烧写本目录 [demo.bit](demo.bit)，673856 字节；不要使用会被后续构建覆盖的 diagnostics/output 或 TD 工程运行目录 bit。两张 FAT32 卡分别放入 [cards/demo_village](cards/demo_village) 和 [cards/flood_village](cards/flood_village) 的四个 PIC、四个 SND、FONT.BIN、TEXT.BIN，共十个媒体文件；manifest.json 为说明，可不拷卡。换卡后复位，不能混用两个村的同名文件。

拨码 {SW2,SW1}=00 下，四图就绪后长按 KEY4 一秒进入场景。短按 KEY4 控制 AUTO，场景内短按 KEY1 切预警，长按 KEY1 一秒调速。详细操作与全功能回归见 [板测清单](BOARD_VALIDATION.md)。

两村均为虚构教学图。SND1–3 为节拍音效，SND4 为警报，无实录旁白；普通第四阶段与预警共用 SND4。previews/ 下拼图及参考图只展示灾害图层，不包含最终 OSD。速度影响动画时间轴，不改变 PCM 音高和播放速率；关闭 AUTO 停留当前阶段终态，不是任意时刻暂停。

## 验证与下一步

TD mountain_m6_attempt02：15083 LUT（76.95%）、9751 寄存器、56 BRAM9k、2 BRAM32k、13 DSP；Setup +0.101ns/Hold +0.019ns，TNS 0，无 ERROR，完整 bitgen。具体仿真统计、编译与审计范围见 [VALIDATION.md](VALIDATION.md)，111 个工程输入清单见 [MANIFEST.md](MANIFEST.md)。仅备份相对 M5 改动的四个生产文件，未改输入由 M5 标签引用。

板测至少连续 40 分钟，测量 Flash 完全断电冷启动和双向换卡复位到首帧耗时，完成双卡及原功能回归。请回传候选标签、实际时间、通过/未测/异常项及是否同意正式发布，结果记入 [BOARD_RESULT.md](BOARD_RESULT.md)。用户确认后才建立 board、发布 v0.17.0、归档并合并 main。

失败保留此候选，修复后递增 local 编号，不移动标签。整机回退使用 [v0.16.0](../../v0.16.0/README.md) 的已验收 bit；历史 M5/M4 候选保留。
