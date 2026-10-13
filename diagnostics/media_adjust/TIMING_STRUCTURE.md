# v0.15.0 局部结构优化记录

## 修改前证据

2026-10-13，在原目录及 feature/brightness-contrast-volume 分支继续。当前 user_source 与 attempt25 快照逐文件比较（统一 CRLF/LF）无差异。v0.14.0 已验收构建为 miso_eqn_attempt1（s3-local.3/MANIFEST.md 指向它）。下表来自各自完整物理报告，不混用综合与布局数字。

| 构建 | LUT | 寄存器 | BRAM9K | DSP | 最终 MSlice / LSlice | Setup / Hold ns |
|---|---:|---:|---:|---:|---|---|
| v0.14.0 miso_eqn_attempt1 | 16757 | 8891 | 43 | 11 | 4658 / 4660 | +0.096 / +0.076 |
| attempt25，当前源码，strategy5 | 17341 | 9338 | 43 | 15 | 4801 / 4795 | -0.233 / -0.004 |
| attempt32，当前源码，strategy4 | 17357 | 9358 | 43 | 15 | 4800 / 4799 | -0.703 / -0.012 |

层次表的 LUT 数按 `lut+ripple` 计算，seq 包含打包 IO 寄存器，与总 reg 列口径不同；父模块包含子模块，不能再次相加。完整模块明细保存在各构建 `TD_project/demo_Runs/phy_1/demo_phy.area`。

| 模块 | v0.14.0 LUT / seq / BRAM / DSP | attempt25 LUT / seq / BRAM / DSP |
|---|---|---|
| SD/BMP 总体 | 8114 / 4680 / 15 / 7 | 8122 / 4745 / 15 / 7 |
| FAT volume scanner | 1583 / 1151 / 0 / 0 | 1614 / 1153 / 0 / 0 |
| 缩放流（含 decoder/scaler） | 1467 / 828 / 7 / 5 | 1432 / 848 / 7 / 5 |
| BMP preflight | 420 / 230 / 0 / 2 | 498 / 233 / 0 / 2 |
| 音频 FAT 流（含文件读取） | 1060 / 404 / 1 / 0 | 1019 / 424 / 1 / 0 |
| HDMI audio bridge | 1528 / 435 / 0 / 0 | 1567 / 445 / 0 / 0 |
| 音频环形 levels | 1299 / 559 / 1 / 0 | 1356 / 592 / 1 / 0 |
| UART logger | 1445 / 432 / 0 / 0 | 1308 / 417 / 0 / 0 |
| 字幕控制 | 909 / 435 / 0 / 0 | 871 / 446 / 0 / 0 |
| 图像亮度对比度 | 无 | 211 / 168 / 0 / 3 |
| 总音量 | 无 | 124 / 19 / 0 / 1 |
| 参数 OSD | 无 | 125 / 62 / 0 / 0 |

attempt25 最差 Setup：scanner/max_cluster → 音频 cluster_latched.ce，-0.233ns；另有 preview ack → 音频 streamer、scaler bottom_edge → yrem.ce、音频 FAT → bmp_error。唯一负 Hold 为 PCM FIFO wr_bin[1] → RAM addra[3]，-0.004ns。attempt32 最差变成 BMP buffer out_offset → header file_len.ce；另有读取 remaining_bytes、自身控制和 scanner 输出。资源大户与失败路径部分重叠，但并非单一数据通路算术超时。日志明确提示 Slice 超过90%，跳过 Hold fixing。

## 本轮唯一结构优化

修改 `uart_event_logger.v` 中 T/S/D 三个十六进制字段的动态选择器。原表达式从整条154位 snapshot 按宽下标选择4位；改为先固定切出32/32/64位字段，再用3/3/4位 nibble 下标选择。下标按各自字符范围取模，范围外仍由原分支处理，输出字符、队列、丢弃计数、回复仲裁和时序均保持。

选择依据：UART 为约1308 LUT的资源大户，源码显示三个宽选择器重复。该模块不在 attempt25 最差路径上，此改动目标是减少 LUT/布线压力，不宣称直接切断音频或缩放路径，也不预设一定修好 Hold。先比较全部字段字符和实际串口/回复行为，再按固定 strategy5 完整构建验证资源与物理效果；不混入其他 RTL 或策略改动。

验证：adjust_uart_fields1已通过52864次旧新实现等价比对（每个源位遍历字符下标、全部事件与phase、随机快照、BOOT），以及现有UART线级字节专项（时间戳、CR/LF、并发事件、快照、溢出DROP、CACHE_DONE/HIT）。adjust_uart_subtitle1通过真实RX/TX和回复仲裁集成。attempt33完整TD已完成（HighFanoutOptimization、PlacementStrategy 5），结果见下。仅改等价组合选择，未改文件读取/缓存协议，不无理由重跑长系统。

综合阶段：同口径 `syn_1/demo_gate.area` 中UART由1292 LUT/404 seq降到1182 LUT/388 seq（-110/-16），但全设计LUT由16757降到16749，仅净减8。未改模块也出现映射差异，例如HDMI audio bridge增加86 LUT、SD/BMP增加32 LUT、audio levels减少19 LUT。不能将局部减少110 LUT写成整体减少110 LUT，最终物理结果另列于下表。

## attempt33 完整结果

完整综合、布局布线和bit生成已结束，无工具ERROR或未解决布线冲突；门槛脚本因负时序正确拒绝该产物。没有建立local/board标签，没有打包候选。

| 指标 | attempt25 | attempt33 | 差值 |
|---|---:|---:|---:|
| 物理UART LUT（lut+ripple） | 1308 | 1197 | -111 |
| 物理UART seq | 417 | 386 | -31 |
| 全设计LUT | 17341 | 17357 | +16 |
| 全设计寄存器 | 9338 | 9339 | +1 |
| 全设计LE | 18551 | 18492 | -59 |
| 最终MSlice | 4801 | 4786 | -15 |
| 最终LSlice | 4795 | 4786 | -9 |
| BRAM9K / DSP | 43 / 15 | 43 / 15 | 不变 |
| Setup WNS / TNS (ns) | -0.233 / -1.128 | -0.216 / -0.216 | 仍不通过 |
| Hold WNS / TNS (ns) | -0.004 / -0.004 | -0.020 / -0.020 | 仍不通过 |

保留本次等价改动：UART局部资源确实下降，整体LE和打包Slice小幅减少；不声称全设计LUT下降或时序修复完成。

下一轮应针对下列实际路径，而非继续盲试布局策略：

- 唯一负Setup：`scanner/state_reg[18]_syn_4.clk` → `scanner/resource1_size_reg[16]_syn_4.mi[1]`，-0.216ns。数据延迟9.936ns，其中cell 1.584ns、net 8.352ns（85%），4级LUT，最大扇出66。路径经过共享`audio_found_n`（fo=66）及`audio_size_b[16]`再到图片资源大小寄存器；RTL对应目录记录第31字节的音频/图片提交及scan_start清零逻辑。先评估提前形成目录记录提交使能或拆开共享数据选择，不可直接凭网表寄存器编号判断RTL状态编码。
- 唯一负Hold：`g_audio$u_stream/cache_write_reg[2]_syn_4.clk` → `g_audio$u_stream/ramread0_syn_6.addra[6]`，-0.020ns；实际逻辑网名为`cache_write[3]`，不是源RTL第2位。数据延迟0.325ns（cell 0.109ns、net 0.216ns）。它是短音频循环缓存，已经不同于attempt25的PCM FIFO；后续只按最终路径定点处理，显式恒等LUT须配置EQN并验证实际网表。

这两处尚未改动。新构建从attempt34起，继续同一strategy5以隔离RTL效果。若后续修改scanner或音频缓存，必须补相应扫描/音频专项及联合场景，不能沿用本轮仅UART受影响的验证范围。时钟、引脚、约束保持原值；无合格候选时不运行发布打包、不进入板测或S3。
