# v0.25.0 S3 候选：旁白播完才 AUTO 换阶段（Seed 43）

候选 `v0.25.0-s3-local.1`，源码提交 `396ac71`，构建 `lut25_narration_td_s43`。与 [s3-local.2](../s3-local.2/README.md) 源码相同、只差布局种子，**请至少上板其中一个**；两个都过更好。

## 功能

- 场景模式（SW3 菜单进入的四个灾害场景）下，AUTO 在“本阶段的 SND 旁白还没读完一遍”时不换阶段，播完后在下一帧换。
- **1×：** 每个阶段约 8.5 秒（新卡音轨长度），比以前约 8 秒多半秒。**2×/4×：** 以前 t 到 239 就换，会把旁白截断；现在等旁白说完。
- 不变：KEY2 手动换阶段、预警模式（KEY1）、没有 SND 文件的阶段（仍按帧计时）、宣讲模式、SW3 菜单、按键 1 ms tick（沿用 S1 批次 1）。
- 实现：`fat32_pcm_stream` 新增 1 位 `pass_done`；`sd_card_bmp` 在“本阶段用 SND 文件、正在播放、尚未读完一遍”时输出 `narration_hold`；`scenario_fsm`（`NARRATION_GATE=1`）在 AUTO 条件上与上它的取反。播放缓冲里最多还剩约 64 ms 音频时标志就已置位，新卡音轨末尾是静音，不受影响。

## 本地结果（lut25_narration_td_s43）

| 项 | v0.25 S1 批次 1（`lut25_keys_td01`，已上板通过） | 本候选 |
|---|---:|---:|
| LUT | 16761 | 16793 |
| 寄存器 | 10010 | 10023 |
| BRAM9k / 32k、DSP | 53 / 2、12 | 53 / 2、12 |
| Setup / Hold (ns) | +0.110 / +0.035 | +0.108 / +0.019，STNS/HTNS=0 |

同源码的 Seed 47 构建 Setup −0.386 ns（`lut25_narration_td01`，最差路径在 FAT32 扫描器内部、与本次改动无关），不交付；Seed 43、53 都通过。

## 验证

- `diagnostics/lut_opt25/run_s3_narration.ps1`：与冻结的 v0.24 `scenario_fsm` 逐拍对比，16 种参数组合 × 120 万拍，输出和内部状态每拍一致，AUTO 被拦 1143 次、放行 158 次；定向测试（2× 旁白未完 AUTO 不走、KEY2 不受影响、播完后一步走、无旁白不变、预警不变）；4 个变异体全部测出。
- `diagnostics/pcm_audio/tb_audio_stream.sv`：`pass_done` 与 `loop_count!=0` 每拍一致。
- SD 引脚级启动仿真（`diagnostics/lut24/run_sd_pin_boot.ps1`）改动前后逐项一致。
- 复位审计（`reports/audit/reset_drivers.txt`）：v0.24 出过问题的 SD 命令模块复位和读卡器解析器复位仍由寄存器驱动，没有退化。
- 约束与 v0.24 相同（`reports/timing.sdc` 与工作区逐字节一致）。

## 使用与检查

1. 烧录本目录 [demo.bit](demo.bit)（SHA-256 `8213a70f47897e9e085450b1918cd2550598ed400613b5e218a4fd9b80ff2c15`）。卡用已写好的 [s2-card.1](../s2-card.1/README.md)。
2. 开机首图、SW3 菜单、四场景 KEY2 换阶段、预警。
3. **本批重点：** 进入场景，短按 KEY4 打开 AUTO，1× 下看一个阶段是否在旁白说完后才换到下一阶段、最后一句没有被截断；再用 KEY1 长按切到 2×、4×，确认仍等旁白说完才换。换到第 4 阶段再回第 1 阶段正常。
4. 宣讲模式的语音、波形、字幕、AUTO 不受影响。
5. 若失败请记录现象（卡在哪个阶段、是否一直不换、数码管内容）。

回退：[v0.25 S1 批次 1 候选](../../../diagnostics/output/lut25_keys_td01/TD_project/demo_Runs/phy_1/demo.bit)（本地构建目录）或 [v0.24.0 正式版](../../v0.24.0/demo.bit)。

当前无 board 标签，未正式发布。
