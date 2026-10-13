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

## attempt34 定点修正

按attempt33报告处理两处：scanner在目录项第30字节预寄存五个目的地提交使能，第31字节仍原周期写入cluster/size/valid；结果写入不再直接依赖状态/名称/重复项的组合链。音频短缓存仅在`cache_write[3]`写地址增加保留的`AL_MAP_LUT1`，显式`INIT=2'b10, EQN="A"`，不改变读写周期。

已通过：adjust_scanner_commit1在GAP=0/1/5下，各七种目录场景的所有scanner输出逐周期对比ebc494d旧实现一致；adjust_commit_audio1扫描、音源mux及音频流通过，新增512字节短缓存逐样本循环，覆盖全部写地址。adjust_commit_reader1的42项FAT32读取回归通过；adjust_commit_production2生产音频联合9279样本精确比对通过，含四图、碎片循环、事务中重扫、故障回退/恢复、无BGM、音频独立启动和短循环。attempt34已启动固定strategy5完整TD，尚待结果及实际网表恒等LUT检查。

验证脚本修正：受影响脚本显式加载厂商AL_MAP_LUT1模型。旧production测试台漏连七个后续新增端口，adjust_commit_production1虽数值检查通过但被八条端口警告拒绝；仅补测试台端口连接后，production2重跑零错误、零警告，不把第一轮记作合格通过。

### attempt34 最终结果

完整TD已结束，无工具ERROR、无最终布线冲突，但仍不合格：Setup WNS/TNS=-0.356/-4.390ns（24个失败端点），Hold WNS/TNS=-0.005/-0.008ns（2个失败端点，包含一条removal）。全设计17224 LUT、9349寄存器、18647 LE、4818 MSlice/4813 LSlice、43 BRAM9K、15 DSP。相对attempt33，LUT减少133，但LE增加155、MSlice增加32；不能把这次局部修正描述为全局时序或打包收敛。

实际网表五位entry_accept均为寄存器。新增cache_write[3]经物理LSLICE的恒等功能接至短缓存RAM addra[6]，未被折叠；原MISO、缩放行数据恒等LUT也保留。三个实际物理LUT厂商模型0/1验证通过：adjust_commit_cache_gate1、adjust_commit_miso1、adjust_commit_scaler_gate1。抽取物理LSLICE时未接与被测组合功能无关的厂商引脚，日志分别保留10/10/13条模型端口警告；无错误或数值不一致，不写成零警告仿真。

默认报告每组仅10个端点，不足以列全本轮24个Setup失败端点；已导出`adjust_s2_attempt34/miso_gate_export/expanded.timing`（每组100端点）交叉检查。原scanner/resource1_size路径和短音频cache_write[3]→RAM均不在负路径内。一次直接按报告pin名调用report_timing_path未找到目标，两个空查询未作为验证依据。

当前关键阻塞：

- 最差Setup：BMP sector buffer out_offset[24]→decoder pixel_count使能，-0.356ns，7级逻辑，net占71%。其他负路径分散于BMP header宽offset译码、读错误→缩略图FIFO使能、字幕回复→UART（8级、fanout55）、UART事件名称选择、SD nCS。
- Hold：完整图写FIFO地址→RAM addra[8]，-0.003ns；另有完整图写FIFO跨域复位removal -0.005ns。后者来自异步复位释放路径，不能当成数据地址线一起加延时。

当前保留已通过行为等价/联合验证的两项定点修正，但尚不具备S2候选。后续从attempt35开始，先结合打包变化评估BMP offset译码和UART选择链的结构，优先减少真实选择逻辑/高扇出控制；不继续随机改布局策略或对所有地址位加LUT。修改BMP流控制时须验证背压、取消、文件末字节同拍和缩放字节流，不得仅沿用本轮扫描验证。新Hold/removal均应按最终报告分别处理。
