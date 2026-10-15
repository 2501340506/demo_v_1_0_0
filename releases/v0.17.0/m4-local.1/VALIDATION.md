# M4 本地验证（2026-10-15）

以下是本候选的实际本地结果，不能替代板测。生产提交为 `0540d43`；可复现入口见 [M4_TESTS](../../../diagnostics/mountain_scene/M4_TESTS.md)，逐日志 PASS 标记见 [logs.json](validation/logs.json)。

| 范围 | 实际结果 |
|---|---|
| FSM、按键、CDC、fade、扫描器 | unit03 五项通过；覆盖四阶段/回环、预警、1/2/4 倍速、t=239 饱和、持续握手、退出/重扫、无音频回退；扫描器 10 场景 |
| 样本/视频跨域 | 13106 个样本 Gray 计数、566 个帧事件及 8192 次整帧状态检查通过 |
| 主音量 | 淡出/淡入各 4682 个样本（约 97.54ms）、步长 14，背压与中断淡变通过；普通调节步长仍为 256 |
| 场景 PCM 集成 | scenario_pcm02：69840 个精确样本、10 次会话；四阶段、回环、预警、速度、碎片文件、两字节短循环、SND3 缺失回退 BGM、停止排空/首新样本握手、退出/重扫和无音频帧计时通过 |
| 新/旧 top | top01：414125 像素/1392 音频；legacy_top01：336269 像素/1148 音频；均通过，43 条已知 IP 告警与 M3 相同 |
| 原 PCM | pcm01 两项通过，9279/9280 个样本比较；包含预览/重扫行为 |
| 受影响回归 | adjust01 六项、reader01 42 项、reader32_01 case0–3/scale1、decoder01 两矩阵、scaler01 两项通过 |
| 长系统回归 | preview01 和 system01 通过，覆盖原有功能及真实 SDRAM；实际统计见下方 |
| PC 工具 | audio_tool02 四项、image_tool02 八项通过；除 manifest 外 37 个图像输出与 M2 逐字节相同，四段原生 WAV/输出 PCM 数据逐字节相同 |
| 占位 WAV 复现 | make_audio_inputs.py 的 --output 生成四个文件，与入库 WAV 逐字节一致（各 768044 字节）；再次运行拒绝覆盖，四文件保持一致，见 validation/mountain_m4_audio_inputs02.log |

共保留 68 份仿真和 22 份编译日志，均为 Errors=0、要求的 PASS 标记齐全；所有告警均经既有 IP、PLL load_reg、glbl 重定义和多宏参数告警白名单核实。场景 PCM 集成在扇区字节接口注入数据，未模拟物理 SD 信号；top 专项检查生产接线和帧内状态。旧系统长回归默认关闭场景功能。hazard_layer 和其 SDRAM 专项使用 M3 历史证据（24 张参考图和真实 SDRAM 像素验证），未在 M4 重跑、不计入上述 68 份日志。

```text
mountain_m4_preview01:
# PASS preview failure recovery: failed foreground retains preview, retry, timeout cached selection
# PASS preview system: frames=293 preview=200 commits=10 cues=10 refresh=180720
# PCM system observations: 238405 exact samples, 4 sessions; no underrun/overrun
mountain_m4_system01:
# PASS integrated cache hits/AUTO: starts=4 reads=9028 commits=14
# PASS integrated rescan: pending commit, active load, compact/missing/no card preserve old pixels
# PASS integrated ordinary failure retry/skip/manual reload with retained FAT32 volume
# PASS integrated timeout keeps cached manual switching
# PASS cache system: starts=14 completions=10 commits=22 cues=22 hits=15 frames=591 refreshes=365203
# PCM system observations: 481827 exact samples, 5 sessions; no underrun/overrun
# PASS S2 origin: 2 AUTO wipes, 15 manual fades
# PASS transition system: 17 fades, 17 black frames, 183705600 pixels
# OSD system observations: 598 frame snapshots, 251159248 pixel/blanking checks
# UART system observations: 4 serial command stages applied at frame boundaries
# Scroll system observations: 251159248 output checks, 253839 foreground pixels
# Timestamp system observations: 598 frame edges, 251159248 pixel/blanking checks, 181532 foreground pixels
# Band system observations: 251159248 output checks, 12155041 dimmed pixels
```

## TD 与文件一致性

合格构建为 `mountain_scene_m4_attempt04`，TD v6.2.168116（E:/TD），placement strategy 7、timing high、high fanout optimization。综合和物理实现均 exit 0，无 ERROR，bitgen 完整结束。最终资源：15181 LUT（77.45%）、8882 寄存器、56 BRAM9k、0 BRAM32k、13 DSP，Setup +0.133ns/Hold +0.004ns，TNS 0。LUT 相对 M3 增加 661，低于 85% 上限 16660；Slice 86.31%，BRAM9k 56/64，BRAM32k 尚未使用。

108 个当前工程/源码/约束输入与隔离构建逐字节一致，清单列出每个文件大小。仅将相对 M3 变化的 11 个生产输入备份到 sources。固定 bit 为 664544 字节，与 attempt04 逐字节一致；四张 BMP 与 M2 一致，四段 PCM 各 768000 字节。约束审计 31 条类别/异常汇总与 M1 一致；TD 综合/物理告警内容规范化后无新增。构建与仿真工具原告警留存在报告/日志中。

## 历史失败与未验证项

- TD attempt01 在 ECO timing 阶段内部崩溃；attempt02 因外部 TD GUI 重存工程丢失四个新源条目而失败。重存工程先保存为 `diagnostics/output/mountain_m4_project_resaved_1907.al`，随后仅补回缺失条目，保留外部 AutoExcluded 修改。attempt03 虽生成 bit 且时序为正，但有 `PHY-8103 ERROR: x_offset.size() <= 0`，已拒绝作为候选。上述失败输出保留本地，交付仅使用无 ERROR 的 attempt04。
- scenario_pcm01 的测试台声明/watchdog 问题修正后以 02 通过；unit01/02 为早期运行，最终用 03。PC tool01 日志存在 PowerShell stderr 包装，最终使用干净捕获的 tool02。失败及早期证据均未清理。
- TD GUI 可能继续保存旧内存工程并丢失新源条目；请重新加载磁盘工程后再保存。打包核对的是完整的当前 108 个输入。
- 本机 PATH 无 ffmpeg，仅原生 48kHz/mono/s16 WAV 提取路径实测通过，其他格式重采样路径未验证。占位音效不能证明旁白关键词同步。
- Hold 仅 +4ps；板上转场无爆音、物理 SD/HDMI 行为、持续运行、Flash 和完全断电冷启动均未验证。M1/M3 板测和 M2 目视仍待确认。
