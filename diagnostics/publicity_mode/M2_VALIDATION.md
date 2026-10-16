# 宣传模式 M2：双资源扫描与四槽映射验证

2026-10-16，原目录 feature/science-publicity-mode，输入8a90155；M0计划v0.18.0-plan.1，M1实现d5ddf21。硬件开发输入/回退仍为未获整机验收的v0.17.0-m6-local.1，正式回退v0.16.0。M2只完成默认关闭的scanner→reader模块能力；sd_card_bmp不启用、不消费新接口，无生产bit，不建立local/board标签。

## 实现范围与契约

仅修改fat32_volume_scanner.v、fat32_bmp_reader.v。EDU/VOI独立四槽原表，槽0在低32位；新文件校验短名、属性、簇号和大小，EDU头在reader预检。开启SCAN_PUBLICITY后不因11个旧资源齐全提前结束，继续到目录零项/EOC或原错误/上限出口。原PIC/SND/BGM/FONT/TEXT判断不变。

reader同时导出PIC/EDU/VOI，锁存目标表。map_start复用扫描元数据重新预检，不物理重扫；EDU按原页号加载，PIC保留found_slot压缩兼容。mapped_valid是预检原槽mask，不以数量代表完整性。无效索引拒绝IO；忙时换目标不生效，音频客户端占用期间map_start不接受。取消扫描使元数据失效、取消预检仅使映射失效，取消文件保留映射；排空后取消事务不发虚假加载完成。默认参数0保持原取消行为。

map_start必须由上层在ready且两扇区客户端空闲、旧缓存/音频/预取/预览已安全停止后发出；不排队。scan_error为独立脉冲、scan_done为粘滞状态，须分别捕获。详细接口见[M2实施](../../docs/宣传模式M2实施.md)、[接口清单](../../docs/宣传模式接口清单.md)。本模块不拥有bank资源身份，不能独立证明应用切换安全。

## 最终执行

Windows PowerShell、ModelSim SE-64 10.6e、TD 6.2.168116/EG4S20BG256。所有输出使用原先不存在的新目录，Python均使用py -I -X utf8。

```powershell
./diagnostics/publicity_mode/run_m2.ps1 -RunName publicity_m2_attempt07
./diagnostics/publicity_mode/run_m2_synthesis.ps1 -BuildName publicity_m2_syn02 -PreparedRun publicity_m2_attempt07
py -I -X utf8 diagnostics/publicity_mode/collect_m2.py diagnostics/output/publicity_m2_attempt07 diagnostics/output/publicity_m2_syn02 diagnostics/publicity_mode/m2_evidence
```

复跑时换RunName/BuildName及证据输出目录，脚本拒绝覆盖已有输出。入口：[准备参考/启用wrapper](prepare_m2.py)、[仿真回归](run_m2.ps1)、[独立综合](run_m2_synthesis.ps1)、[证据核验](collect_m2.py)。证据归档转换为UTF-8文本，规范换行及行尾空白；原始日志/完整快照保留diagnostics/output，未放入releases硬件交付。

## 仿真与受影响回归

**108份仿真日志全部PASS，Errors: 0, Warnings: 0；1份编译日志同样零错误零告警**。完整逐项结果见[汇总](m2_evidence/simulation_summary.txt)、[编译](m2_evidence/compile.log)。未屏蔽工具告警。

| 验证 | 实际覆盖 / 数量 |
|---|---|
| [scanner专项](tb_publicity_scan.sv) | 每轮96场景，GAP=0/2/5；EDU全24排列及逆序VOI放在齐全11旧资源后，跨3目录簇；全部19资源64组确定性混排；完整32位cluster/size逐槽比较、末字节与done同拍 |
| 同上缺失/异常 | 无VOI用EOC退出、旧卡、缺EDU2/4及VOI2/4、首次有效元数据/重复项、非法簇/大小、零/奇数PCM、目录/卷标/LFN、错扩展名/小写/删除、零目录项后不再识别；链循环/越界/遍历上限 |
| [reader专项](tb_publicity_reader.sv) | 每轮53次操作，GAP=0/2/5；两套元数据及2×2 BMP实际像素逐个比较；八图加载、反复换表且boot/dir读次数不增；缺EDU2+坏EDU4头，rawmask=13、mappedmask=5，EDU3仍槽2；PIC1/3仍压缩为索引0/1 |
| 同上恢复/握手 | 旧卡/纯EDU/空卡清旧表、无效加载不发IO、忙时改目标/map_start不换表、取消物理扫描后重扫、取消预检后重映射、文件取消排空后重载、音频占用拒绝换表、预检IO错误后重试、物理重扫错误后恢复 |
| 默认关闭scanner等价 | 基于8a90155 scanner参考，原M5扫描测试全部原输出每周期#1比较，GAP=0/2/5 |
| 旧SND/BGM扫描 | tb_snd_scan、tb_audio_scan，分别GAP=0/2/5；共6轮 |
| FAT32 core | 原generate_core_fixtures的42个案例，BYTE_GAP=2；core检查与reader检查分别运行 |
| 默认关闭reader等价 | 原reader所有旧输出每周期#1对照8a90155；42个案例＋5个TEST_MODE＋4个SCALE_TEST，共51轮；含坏头、ack超时、尾字节done同拍与缩放 |

前5类专项/旧扫描合计15轮；core42、reader等价51，共108轮。六份宣传专项原日志：[scan0](m2_evidence/tb_publicity_scan_gap0.log)、[scan2](m2_evidence/tb_publicity_scan_gap2.log)、[scan5](m2_evidence/tb_publicity_scan_gap5.log)、[reader0](m2_evidence/tb_publicity_reader_gap0.log)、[reader2](m2_evidence/tb_publicity_reader_gap2.log)、[reader5](m2_evidence/tb_publicity_reader_gap5.log)。

旧测试源未修改。prepare脚本在新输出目录补齐测试副本的未用输出/新增输入常量；reference来自固定8a90155，所有旧输出均比较，新增输出不是旧参考的一部分。新宣传reader专项使用固定尺寸路径；生产SCALE_ENABLE=1下的默认关闭路径有4轮等价回归，新宣传映射与缩放/四bank的生产联合验证仍属M3，不宣称已完成。

## 启用参数的独立综合

两top均SCAN_AUDIO/TEXT/PUBLICITY=1；reader另LOAD_BY_INDEX=1、SCALE_ENABLE=1。从固定旧.al生成隔离.prj，CompileOrder唯一，read_design至opt_gate。TD进程均exit0，无ERROR，面积报告生成；scanner1份、reader10份RTL快照与最终活动源码逐字节一致，见[逐文件记录](m2_evidence/source_comparison.txt)。wrapper只是透出模块接口，不修改原生产工程。

| 独立top | LUT | 寄存器 | BRAM9k / BRAM32k | DSP | 告警 |
|---|---:|---:|---:|---:|---|
| scanner_enabled | 1477 | 920 | 0 / 0 | 0 | 无WARNING |
| reader_enabled | 4989 | 3162 | 9 / 0 | 7 | 1条SYN-6562，bmp_sector_buffer读寄存器初值因eram_init=off忽略 |

原始报告：[scanner日志](m2_evidence/fat32_volume_scanner_build.log)、[scanner面积](m2_evidence/fat32_volume_scanner_demo_gate.area)、[reader日志](m2_evidence/fat32_bmp_reader_build.log)、[reader面积](m2_evidence/fat32_bmp_reader_demo_gate.area)。面积取Utilization Statistics的#lut，不混用#Total_luts。reader告警对应未改的bmp_sector_buffer.v第17行；该通路先收集有效字节再FETCH/PRESENT，本阶段未修改该初始化或做门级初值专项，不写成综合零告警。

两个wrapper透出宽元数据，IO分别1445/1587，大于器件188个IO；用于内部逻辑独立综合，不能直接当上板顶层。资源数不是生产全设计，也不是生产增量。没有布局布线、生产约束审计、最终Setup/Hold或bitgen；build.log的basic timing不当整机时序结论。

## 提交前文件核对

个人问题记录与开始时副本逐字节一致（909字节），不纳入提交。TD_project、releases、best_result相对输入8a90155无Git差异；user_source仅修改本阶段两份RTL。32份待提交文本UTF-8解码、Python语法、Markdown围栏及325个本地链接检查通过；13份精简证据齐备。未改生产入口、旧候选或本机状态。

## 保留的尝试及限制

- attempt01：scanner功能PASS但新测试台少连输出，严格告警门槛拒绝。
- attempt02：测试副本补端口正则未允许实例名后的空格，误匹配，编译失败；修正匹配后重跑。
- attempt03：15轮专项通过，旧core固定fixture路径与省略decoder端口使core0失败；仅在生成副本重定向新fixture并补齐端口。
- attempt04：15轮专项/core0通过，reader逐周期对照本身通过，参考实例少连9个原有输出产生10条告警，拒绝归档为通过；补参考连接。
- attempt05/06：新增取消/IO边界测试最初误把粘滞scan_done及独立scan_error脉冲当同拍完成，测试断言失败；修正测试采样。实现中另补启用参数的扫描器取消复位及取消排空不报load_done，防止重扫卡住/虚假成功；最终attempt07全部通过。
- syn01：早期源码独立综合通过但隔离工程重复CompileOrder告警，不作最终证据；修正工程生成器，最终源码重跑syn02。所有失败/早期输出保留本地，不覆盖。

M3仍需接应用入口、四bank版本/失效、取消写排空和原子显示提交，完成实际生产专项/回归/完整TD后才有硬件候选。VOI只有格式与元数据，不代表PCM内容可播或自然EOF，M4才接音频。M1仍是测试音，内容专业审阅、正式录音、听审/HDMI可读性未完成。旧M6整机板测、40分钟、冷启动/换卡计时不增加结论，v0.17.0未正式发布。
