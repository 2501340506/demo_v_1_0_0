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

## attempt35 字幕回复选择链（失败，生产修改已撤回）

选择证据：attempt34中字幕`index-9`生成的sub2寄存器/组合链到UART reply_byte为-0.351ns，8级逻辑、最大扇出55。subtitle_uart_controller物理868 LUT/452 seq，综合842 LUT/450 seq。源代码先按宽下标从125位snapshot选择8位，再按index奇偶选4位；本轮仅将其改为固定120位文本字段上直接选择4位，下标`((index[4:0]-5'd9)^5'd1)`限定为5位。合法文本0至15字节都在30个半字节以内，字符32处按模32回绕恰好对应后续文本；不改reply_valid/last、队列、配置或握手周期。

adjust_reply_fields1通过124928次旧新查询格式化比较（每个文本源位、长度0..15、index0..63及随机文本），并在现有真实RX/TX串口/回复仲裁集成中逐周期比较新旧控制器全部输出，零错误、零警告。BMP流控制未改，本轮无需重跑其回归；attempt35已启动固定HighFanoutOptimization/strategy5完整TD。最终资源、时序待补，Hold/removal暂不叠加修改。

最终：字幕模块综合842→847 LUT、物理868→888 LUT，并无资源收益；全设计17363 LUT/9347寄存器、4801 MSlice/4808 LSlice，Setup -1.632ns（124失败端点）、Hold -0.020ns（3失败端点）。完整TD无工具ERROR但不合格。已将subtitle_uart_controller.v恢复至1c0efbb内容，失败源码快照及结果保留attempt35，不能用它代表当前源码或候选。格式化等价测试作为这项实验的诊断保留；不以源码看起来简单代替硬件收益。

## attempt36 UART队列BRAM化（完整TD结束，时序失败）

当前生产修改仅在UART事件队列：attempt34综合日志确认它是8×154位Logic DRAM。改为同步BRAM读口，显式使用本项目IP已有的`fehdl force_ram=1, ram_style="bram"`属性；新增一拍loading，将BRAM读出的记录装入原serializer后才置active。保留日志格式、时间戳取样、八条可用队列容量、DROP和回复独占仲裁，记录发送前多一个系统时钟的内部装载时间。物理环深度16、可用容量仍8，使满队列同时出入队时读写地址不同，不依赖BRAM同址读写模式。Hold/removal未叠加修改。

adjust_queue_fields2：52864次字段格式化旧新比对、原线级UART日志（CR/LF、同时事件、快照、DROP=2、CACHE消息）通过；新队列专项448装载、440次满队列同时出入队、576溢出事件，多次指针回绕且无同址读写，数据/计数一致。adjust_queue_subtitle1真实RX/TX及回复仲裁集成通过，均零错误/零警告。attempt36固定strategy5完整TD运行中，待确认实际BRAM映射、资源和时序。

综合已确认实际队列映射9个BRAM9K，总BRAM52/64；相对attempt34，UART综合LUT1170→910，全设计16635→16350（-285）。不是只接受属性而仍用Logic DRAM。adjust_queue_gate1独立TD综合后的网表（测试时钟/波特率、QUEUE_DEPTH=2，仍映射9个BRAM）在线级UART专项通过：实际厂商BRAM模型下字节、快照、时间戳、DROP及CACHE记录正确。该门级日志有2446条厂商原语未接端口/端口类型警告，零错误，不声称零警告；与生产完整TD的容量8配置区分，容量8的队列压力已由RTL专项验证。

### attempt36 最终资源与时序

完整综合、布局布线及bit生成结束，无工具ERROR；门槛脚本因负时序退出1，正确拒绝产物。当前102个工程输入（包括工程、引脚及SDC）与attempt36快照逐字节一致。保留队列BRAM改动作为资源优化阶段结果，没有合格S2候选。

| 指标 | attempt34 | attempt36 |
|---|---:|---:|
| 全设计LUT | 17224 | 16929 |
| 寄存器 / LE | 9349 / 18647 | 9339 / 18224 |
| MSlice / LSlice | 4818 / 4813 | 4695 / 4697 |
| BRAM9K / DSP | 43 / 15 | 52 / 15 |
| Setup WNS / TNS ns | -0.356 / -4.390 | -1.009 / -23.488 |
| 最大延迟失败端点（含recovery） | 24 | 72 |
| Hold WNS / TNS ns | -0.005 / -0.008 | -0.020 / -0.070 |
| 最小延迟失败端点 | 2 | 6 |

UART物理899 LUT（840 lut + 59 ripple）、382 seq、9 BRAM。全设计LUT减少295，MSlice减少123，LSlice减少116，是真实资源和打包收益；时序反而变差，不称为收敛。代价是新增9个BRAM、总占用52/64，及出队记录开始发送前增加一个系统时钟。

已导出`adjust_s2_attempt36/timing_analysis/expanded.timing`（每组100端点）和`routed.v`。72个最大延迟失败端点实际为71条setup及1条recovery；默认报告前10条漏掉的recovery是`u_reset_sd/release_pipe`→BMP streamer `remaining_bytes.sr`，-0.038ns，不能按数据Hold处理。

Setup按目的模块分布：decoder头检查20、decoder像素控制5、scanner9、preflight5、SD扇区读写15、UART3，其余14分散于读取/写FIFO/音频/缓存控制。最差为buffer实际`file_byte_offset[21]`→header `file_len.ce`，-1.009ns，8级LUT，cell 2.612ns、net 8.117ns（76%）、最大扇出12。头检查内部使用32位offset选择0..33字节并控制header_complete，实际路径穿过共享高位译码与多级使能；像素控制仍有pixel_offset→green.ce -0.845ns。下一项优先调查如何切断这两类宽偏移译码，而不是假定只有大扇出或仅靠减少LUT就能通过。

六条负Hold：streamer数据→sector buffer RAM -0.020ns；UART pending→队列RAM -0.020ns；完整图写FIFO地址→RAM -0.012ns；缩放raw_pipe_x→RAM -0.011ns；PCM rd_bin→RAM -0.004ns；UART rd_ptr→队列RAM -0.003ns。实际网表确认UART `ramread0_syn_64.dib[0]`对应`pending[1]`，`addrb[5]`对应`rd_ptr[1]`，不能直接按源寄存器编号推断RTL位。尚未添加新保持LUT；应在下一项结构变化的最终报告上重新定位。

下一轮从attempt37起，固定HighFanoutOptimization/strategy5。若改变BMP头或流接口，专项覆盖连续字节、背压、取消、末字节/结束同拍和缩放逐像素；sector buffer有FETCH气泡不代表所有decoder调用者均有气泡，不能据此无条件提前采样。attempt35实验复现可用`run_subtitle_fields.ps1 -SourceRoot diagnostics/output/adjust_s2_attempt35 -RunName <新目录>`；默认使用当前生产源码，不能将默认运行称为重跑已撤回优化。

## attempt37 BMP头地址提前译码（完整TD结束，时序仍失败）

依据attempt36：缩放decoder/u_header物理476 LUT（316+160）、247 seq，20个Setup失败端点；最差buffer offset高位经8级译码到file_len.ce，-1.009ns。只在bmp_scale_stream显式启用新的HEADER_OFFSET_LOOKAHEAD参数：利用buffer已有FETCH/PRESENT合同，将32位offset提前寄存为6位header地址。0..63保留，其他地址映射为63（头检查不对63写字段或改变header_complete）。缩放字节消费、ready/valid、数据和结束时序不变；通用decoder参数默认关闭，连续字节调用者仍走原32位地址。

验证计划：以44792e9旧decoder为参考，在完整BMP缩放字节流上逐周期比较全部decoder输出及头字段，断言每次有效消费时预译码地址正确；补取消/重启和末字节同拍场景，通用连续字节解码回归、42项FAT32读取。通过后固定strategy5完整TD，检查原20个头译码负端点与整体资源；本轮暂不叠加Hold修改。

验证边界：旧`tb_bmp24_decoder`直接在最后一个解码字节同拍给file_end；当前44792e9基线也会得到307200像素、err=3而不提交（`adjust_header_lookahead2/baseline.log`），不是本次预译码回归。本轮通用decoder专项按生产重放合同在最后消费字节后一拍给结束，连续字节、头拒绝、截断及上游取消仍保留，并增加旧新逐周期比较。输入端末字节与结束同拍通过完整buffer→decoder链路验证，不声称直接decoder同拍结束通过。首轮检查器缺timescale装载失败，补测试生成文件的timescale后重跑，未改生产时序。

实际通过：adjust_header_lookahead3五尺寸逐周期等价/逐像素（每图307200像素）、取消/不复位重启、输入末字节同拍、16项通用decoder场景；adjust_header_scaler1十尺寸缩放及原五尺寸字节流；adjust_header_reader1全部42项；adjust_header_reader_scaled1为case0碎片文件、ScaleTest=1、ByteGap=0、TestMode=5。所有通过日志零错误警告。attempt37完整TD已启动，固定HighFanoutOptimization/strategy5，尚待最终资源和时序。

### attempt37 最终结果与下一步

完整综合、布局布线及bit生成结束，无工具ERROR；中间一处布线冲突最终消除。门槛脚本因负时序正确拒绝。102个工程输入（含工程/引脚/SDC）与attempt37快照逐字节一致，无候选、无local/board标签。

| 指标 | attempt36 | attempt37 |
|---|---:|---:|
| LUT / 寄存器 | 16929 / 9339 | 16988 / 9343 |
| LE | 18224 | 18171 |
| MSlice / LSlice | 4695 / 4697 | 4727 / 4729 |
| BRAM9K / DSP | 52 / 15 | 52 / 15 |
| Setup WNS / TNS ns | -1.009 / -23.488 | -0.346 / -1.767 |
| 最大延迟失败端点 | 72（含1 recovery） | 13（均setup） |
| Hold WNS / TNS ns | -0.020 / -0.070 | -0.020 / -0.042 |
| 最小延迟失败端点 | 6 | 3（均hold） |

实际Routed网表中三个物理Slice的Q分别驱动header地址[1,2]、[3,5]、[4,0]，六位寄存边界保留。`timing_analysis/expanded.timing`每组100端点列全13/3条负路径，所有decoder/u_header端点及decoder像素控制均无负路径，原20个头检查负端点消除，本轮没有负recovery/removal。预译码结构保留；这是路径切断，不是面积改善：物理header LUT 476→481、整个decoder 726→739；全设计LUT+59、MSlice+32，但LE-53、Setup总负余量显著减少。

下一轮从attempt38起，固定HighFanoutOptimization/strategy5，优先处理剩余Setup控制链：

- `candidate`→`header_lba[31]`，-0.346ns，7级（含2级加法）、最大扇出53、70%布线。RTL在SELECT_CHECK同时做clusters[candidate]选择及减2；可调查在前一SELECT拍捕获选中cluster/size，再计算头扇区地址，保留候选推进/无效项/重扫语义。
- scanner `total_sectors`→12个`sector_lba`使能，最差-0.265ns，8级、最大扇出18、70%布线。RTL的bpb_ok是宽字段联合判定，参与ZERO_PARSE选择MBR/直接BPB及BOOT_PARSE。字段在扇区早段收齐，可调查提前寄存BPB判定，不要把最终signature或sector_error提前漏判。
- Hold实际位已从网表确认：PCM `rd_bin[9]`→RAM addrb[10] -0.020ns；缩放`raw_pipe_rgb[8]`→RAM dia[0] -0.011ns；UART `pending[7]`→RAM dib[6] -0.011ns。与attempt36不同，尚未添加新保持LUT，应在下一次结构变化后的最终报告重核。

若动reader/scanner，重跑对应专项及受影响生产联合场景。已通过的BMP功能验证可作本轮保留改动证据，不能据此宣称后续reader/scanner修改也已通过；失败bit继续留在diagnostics/output。

## attempt38 BPB合法性判定预寄存（完整TD结束，时序仍失败）

本轮只处理attempt37中scanner total_sectors→sector_lba使能的12个Setup失败端点，最差-0.265ns、8级、70%布线；scanner物理资源以attempt37报告为准。BPB参与字段最晚在byte47收齐，ZERO_PARSE/BOOT_PARSE在512字节扇区结束后使用，故将原组合bpb_ok拆为同表达式bpb_fields_ok及一拍寄存的bpb_ok。签名510/511字节与sector_error检查不变，不改扫描状态拍序/输出/时钟约束，暂不改candidate路径或Hold。验证以86bad25为逐周期参考，补42项FAT32（包含MBR、坏BPB、错误与重扫）、碎片缩放及生产音频联合，再做固定strategy5完整TD。

attempt37 scanner物理1646 LUT（1398+248）、1165 seq。直接专项adjust_bpb_equivalence1（参考86bad25，GAP=0/1/5）逐周期全部输出等价通过；adjust_bpb_scaled1碎片缩放（case0、ByteGap=0、TestMode=5）通过；adjust_bpb_production1生产联合9279个PCM精确比较通过，覆盖四图、碎片循环、事务中重扫、故障回退/重试、无BGM、音频独立启动及短循环，均零错误警告。42项零间隔FAT32回归及完整TD结果待补。

adjust_bpb_reader1全部42项零间隔FAT32回归通过，零错误警告。attempt38已启动固定HighFanoutOptimization/strategy5完整TD，尚待最终结果。

### attempt38 最终结果

完整TD结束，无工具ERROR，中途布线冲突最终消除；门槛脚本因负时序正确拒绝。102个工程输入与attempt38快照逐字节一致。实际网表bpb_ok_reg_syn_5的Q驱动scanner/bpb_ok，预寄存没有被消掉；每组200端点的`timing_analysis/expanded.timing`确认原total_sectors→sector_lba的12个负端点全部消除。保留本轮BPB改动，无S2候选或local/board标签。

| 指标 | attempt37 | attempt38 |
|---|---:|---:|
| LUT / 寄存器 | 16988 / 9343 | 17126 / 9346 |
| LE | 18171 | 18230 |
| MSlice / LSlice | 4727 / 4729 | 4703 / 4706 |
| BRAM9K / DSP | 52 / 15 | 52 / 15 |
| Setup WNS / TNS ns | -0.346 / -1.767 | -0.141 / -0.703 |
| 最大延迟失败端点 | 13 setup | 9 setup + 1 recovery |
| Hold WNS / TNS ns | -0.020 / -0.042 | -0.011 / -0.037 |
| 最小延迟失败端点 | 3 | 4 |

scanner同口径综合LUT 1415→1370（-45），seq1169→1170；物理LUT1646→1627（-19），seq1165→1143。整体LUT增加138，但MSlice减少24、LSlice减少23；不能将局部LUT收益写成全设计LUT下降。Setup和Hold最差余量均改善，但还有负路径。

剩余Setup：字幕index→UART reply_byte -0.141ns（9级、fanout51、52%布线）；reader sector_byte→scanner audio_match -0.116ns；task_size→scan_found_size -0.085ns；load_control state→preflight dib_size两条-0.072ns；preview ack→音频控制两条-0.047/-0.043ns；candidate→header_lba -0.032ns；decoder预译码寄存器→pixel_count使能-0.021ns。原BPB路径消除不代表整个scanner或BMP链路所有路径都已通过。

Recovery -0.074ns：报告源实例名为`u_picture_adjust/rgb_out_b12[8]_syn_4`，但实际Q[0]是共用物理Slice内的`u_reset_sd/release_pipe[2]`，不是图像数据串到UART。到UART物理`tx_data[5]_syn_27.sr`为上升沿→下降沿5ns预算，reset网络fanout1262、95%布线。应按实际复位释放处理，不能按实例名或数据Hold加延迟。

四条Hold实际位：streamer file_byte[3]→sector buffer RAM dia[3] -0.011ns；UART pending[10]→RAM dia[0] -0.011ns；UART pending[27]→RAM dib[8] -0.011ns；UART wr_ptr[3]→RAM addra[7] -0.004ns。已查实际网表拼接，不沿用attempt37的PCM/缩放RGB端点。

下一轮从attempt39起，继续固定HighFanoutOptimization/strategy5。最差再次是字幕查询格式化到UART接收寄存器；attempt35直接半字节选择已失败撤回，不重复。优先调查按字符握手预计算/寄存回复数据，保持query快照、index/last推进与日志仲裁；或处理有明确寄存边界的candidate选择链。每次只实施有证据的一项，验证后完整TD，再按最终报告重核Hold和Recovery。

## attempt39 字幕回复寄存切分（完整TD结束，时序仍失败）

attempt38字幕模块物理915 LUT（661+254）、430 seq；index→UART reply_byte为最差-0.141ns、9级、fanout51。此次保留原字节选择表达式，在选出的原始ASCII/半字节与hex转换之间增加prepared_data/hex/last/valid寄存级。只有reply_valid&&reply_ready推进index；每字符增加一个内部准备拍，背压时数据与last保持，快照/active/pending与溢出ERR语义保持。没有重试attempt35的直接半字节选择，没有叠加Hold或复位改动。先验证全部字段、握手/背压/排队/重置和真实RX/TX日志仲裁，再固定strategy5完整TD。

adjust_reply_pipeline2已通过：124928次旧新字段比较；102个接受字节、106个背压周期（含0/2/12字长度、连续ready、快照、pending溢出ERR、背压复位）；真实RX/TX 8N1字幕/日志仲裁、ASCII/CN/mixed、12/13边界、坏停止位、帧提交与复位，全部零错误警告。参考b5b48c9控制器按新实现的实际接受时刻握手，比较有效数据/last和逐周期配置更新，不把新增准备拍声称为valid逐周期等价。首轮测试台用Verilog不支持的字符串CR转义，改为八进制015后重跑；生产RTL未因此修改。旧run_subtitle_fields是组合输出合同的历史实验工具，当前流水请使用run_reply_pipeline；重现attempt35需旧快照SourceRoot。attempt39完整TD已启动，结果待补。

### attempt39 最终结果

完整综合、布局布线和bit生成结束，无工具ERROR；门槛脚本因负时序正确拒绝。102个工程输入与attempt39逐字节一致。实际网表prepared_data[6:0]、prepared_hex、reply_last（prepared_last重命名）和prepared_valid均由Q驱动，数据最高位恒0被优化，寄存边界保留。扩展报告每组200端点：只剩1条setup、2条hold，无负recovery/removal，原字幕回复负路径消除。保留本轮改动，尚无S2候选。

| 指标 | attempt38 | attempt39 |
|---|---:|---:|
| LUT / 寄存器 | 17126 / 9346 | 16955 / 9345 |
| LE | 18230 | 18107 |
| MSlice / LSlice | 4703 / 4706 | 4693 / 4699 |
| BRAM9K / DSP | 52 / 15 | 52 / 15 |
| Setup WNS / TNS ns | -0.141 / -0.703 | -0.151 / -0.151 |
| 最大延迟失败端点 | 9 setup + 1 recovery | 1 setup |
| Hold WNS / TNS ns | -0.011 / -0.037 | -0.011 / -0.022 |
| 最小延迟失败端点 | 4 | 2 |

全设计LUT减少171、LE减少123、MSlice减少10、LSlice减少7；Setup最差略差0.010ns，但总负余量和端点明显减少。字幕物理974 LUT/484 seq，UART logger793 LUT/369 seq；模块间映射有变化，不能只看字幕单模块判断总收益。

唯一负Setup：报告`u_cache_control/cache_failed_reg[3]_syn_16.clk`→音频streamer `sector_lba_reg[10].ce`，-0.151ns，7级、fanout20、76%布线。实际起点Q网络是`g_preview$control/preview_request`，经过fullscreen_ready、重扫/音频停止控制进入streamer使能，不是cache_failed数据。下一轮优先研究`sd_card_bmp`的rescan_event/audio_run与`fat32_pcm_stream`取消/启动路径的寄存切分，保持音频事务排空后再接受扫描的合同，不能只延迟单个取消脉冲。

两个Hold均-0.011ns：PCM `wr_bin[11]`→RAM csa[1]（深度分块片选），UART `pending[75]`→RAM dib[1]。后者报告源实例为subtitle/lt74，实际是共用Slice内的UART时间戳寄存器。已查实际网表；不能继续处理旧pending[10]/[27]、地址wr_ptr[3]或将它误判为字幕字段。

下一轮从attempt40起，固定HighFanoutOptimization/strategy5。若修改音频/重扫控制，补生产联合和事务中取消/重扫验证；按新完整TD重核Hold及实际恒等LUT，Setup/Hold均非负前不打包、不建local标签。
