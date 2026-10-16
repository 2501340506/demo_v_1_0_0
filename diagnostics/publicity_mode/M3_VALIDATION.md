# 宣传模式 M3 验证记录

输入 8e6bf69（M2），原目录 feature/science-publicity-mode。硬件开发回退 v0.17.0-m6-local.1 未获整机验收；正式回退 v0.16.0。专项与回归通过不能代替本候选板测。155份专项/回归完成日志及33份编译/模型日志核验通过，TD14达标且审计完成；固定候选为v0.18.0-m3-local.1，等待本候选板测。

## 实现与验证范围

生产 top 默认启用 PUBLICITY_ENABLE；sd_card_bmp/mode_key_control 保留默认关闭参数，兼容旧诊断。应用编码 COMPAT=0、PUBLICITY=1、SCENARIO=2；拨码只决定操作页。KEY4 在00长按一秒切应用，释放短按AUTO，长短互斥；忙期间输入须释放后重新按下。宣传静态前后四页，AUTO明确禁用、VOI不播放，主音量保持静音。情景保留终态AUTO/预警/速度，离开00暂停自动推进，B/C/V及速度跨应用保留。

两表先预检，完整EDU优先，否则PIC COMPAT。目标不完整直接拒绝；同卡换表不重扫目录。取消排空旧预取、淡出静音、停止音频、逻辑失效四bank、装载并提交目标首图，显示身份含4位资源版本与2位应用，经8位身份/页号mailbox及视频消隐提交。等待真实帧边界后淡入；宣传启动另等实际主音量静音。覆盖后失败进入黑场ERROR，可短KEY4重试、长KEY4切另一可用套、长KEY2两秒物理重扫。

## 仿真证据

以下运行均在新目录，不改冻结诊断/历史候选；脚本使用 `py -I -X utf8` 生成显式旧端口适配副本。完整输出保留 diagnostics/output，最终精简日志随合格候选固定。

| 运行目录 | 实际覆盖 | 当前结果 |
|---|---|---|
| publicity_m3_attempt15 | 17项（含启动与FAT链各20个边界、scanner高低位25个边界）：按键、192次8位CDC提交含版本回绕、reload_case0–9、实际307200像素缩放、真实PCM流 | 通过 |
| publicity_m3_regression_attempt06 | 20项：缓存、转场、预览、参数、CDC、PCM、场景/中文；真实场景173939样本/11会话；另补bin_loader流水GAP2/5各10个用例 | 通过 |
| publicity_m3_reader_regression05 | 最终scanner簇检查流水，目录混排/尾项/缺槽/旧卡/取消/恢复；SCAN_PUBLICITY=0对8a90155逐周期比较，108份仿真 | 通过 |
| publicity_m3_rgba_attempt02 | 真实SDRAM四种尺寸RGBA、FAT32/缩放/显示，31帧，混合尺寸 | 通过 |
| publicity_m3_legacy_demo01、publicity_m3_legacy_flood02 | 示意村、山洪村各scenario_top/m6_top，真实FONT/TEXT和场景中文 | 四项通过 |
| publicity_m3_top_attempt07 | 生产PUBLICITY=1、真实按键/参数/身份CDC/图层/主音量/HDMI输入；外部SD运输、存储握手与raw像素模型；7016112时序检查、338602宣传/634652情景像素、546静音PCM | 通过 |
| publicity_m3_attempt15/streamer_start、streamer_chain | 各20个启动/真实扇区链边界：高低位进位、范围、非法SPC、空文件优先、EOC/自环/计数/高半字节掩码、目录大小EOF及精确输出字节 | 通过 |
| publicity_m3_system_attempt02 | 真SDRAM、OSD/UART、转场、故障重扫/超时；591帧、481827精确PCM/5会话、22提交，无underrun/overrun | 通过 |
| publicity_m3_preview_attempt02 | 真SDRAM缩放/混合尺寸/预览/转场/故障恢复，293帧、238405精确PCM/4会话，无underrun/overrun | 通过 |

控制器专项case8延迟取消17周期、第9周期插入旧完成toggle，核验迟到写入不提交；case9先实际进入preview_intent再退出并切应用。其他case覆盖缺EDU中槽、坏BMP表头、PIC不齐、旧卡、无图、失败两次/重试/切回/物理重扫。reload_audio使用实际PCM流但muted输入固定；实际主音量静音由生产top专项单独证明；最终top_attempt07通过。

RGBA/长系统/预览与双村旧top显式关闭PUBLICITY，仅证明原生产路径回归；它们不能替代新应用顶层。最终生产top_attempt07使用真实reader/scaler和完整307200像素，模型替换物理SD/存储握手及raw像素；另用真实SDRAM系统测试补存储边界，不宣称一次仿真覆盖全部组合。长系统/预览早于file_streamer比较优化；保持原延迟的启动/后继簇比较修改，由各20个真实边界用例、最终108项reader回归及20项音频/场景回归补齐。最终scanner/reader流水修改由17项专项（含25个真实BPB/连续目录字节边界）、108项reader回归及top_attempt07覆盖。

## TD 与审计

硬门槛：最终LUT≤16660/19600、Setup/Hold均为正、STNS/HTNS=0、无ERROR、完整bitgen，源码/工程与隔离快照逐字节一致。TD脚本exit0或存在bit均不足以证明合格。

历史构建全部保留在diagnostics/output，不纳入候选：

| TD尝试 | 实际结果与拒绝原因 |
|---|---|
| 01 | 17415 LUT，Setup −2.238ns/Hold −0.012ns |
| 02、04 | PHY-8023/RUN-8102布线失败 |
| 03 | 15895 LUT，Setup −1.429ns/STNS −22.036ns，Hold +0.014ns |
| 05 | 15770 LUT，Setup −0.401ns/STNS −0.432ns，Hold +0.011ns |
| 06 | PHY-8023；Setup −5.642ns/STNS −1827.852ns |
| 07 | 遗漏HighAreaOptimization，PHY-8023/RUN-8102 |
| 08 | 同样遗漏面积优化；17112 LUT超门槛，Setup −0.456ns/Hold −0.011ns |
| 09、10 | 15790 LUT，Setup −0.259ns/STNS −0.874ns，Hold +0.021ns；10增加PostRouteOptimization后最终相同 |
| 11 | 15761 LUT，Setup −0.944ns/STNS −5.712ns，Hold +0.014ns |
| 12 | 15844 LUT，Setup −0.620ns/STNS −1.193ns，Hold +0.024ns |
| 13 | 15771 LUT，Setup −0.872ns/STNS −4.799ns，Hold +0.024ns |

根据真实关键路径分拍scanner簇范围/目标使能、reader范围/表头长度/排空响应和FONT/TEXT元数据，file_streamer拆分高低16位比较保持原状态延迟；audio_run沿用既有audio_session寄存停止。旧参数关闭路径保持兼容，默认关闭scanner/reader逐周期对照通过。没有修改时序约束或旧UART掩盖问题，详见[M3实施](../../docs/宣传模式M3实施.md)。

attempt14使用strategy7/high/HighAreaOptimization，最终15785 LUT（80.54%）、10202寄存器、56 BRAM9k、2 BRAM32k、13 DSP；Setup +0.097ns、Hold +0.024ns，STNS/HTNS均0，STA覆盖99.97%，无ERROR且完整bitgen，bit 673856字节。时序审计汇总与M6相同，保留两块BRAM32k dob[9] dummy节点；综合/布线告警规范化后与M6集合无增减。111工程输入及根构建脚本与隔离快照逐字节一致。最终top07通过后封装通过，11个变化工程输入与bit/证据均逐字节固定。只允许已知工具模型/遗留诊断，不静默忽略新增告警。

## 仿真诊断边界

155份仿真完成日志全部通过逐项检查。33份编译/厂商/PLL/加密模型日志检查通过。封装要求无ERROR/FATAL且各仿真必须有最终PASS。保留原模型/可选端口/多宏参数/PLL诊断，不能称零告警。最终top_attempt07/compile.log另有一条tb_m3_top.sv(219)的vlog-2597：3000000000按32位有符号常量处理；仅测试台watchdog延迟常量，不在生产RTL/TD中。封装仅对此确切路径、行号及诊断文本放行，其他新增告警拒绝。

补测启动曾因Windows反斜杠库路径触发vopt-2253，未加载设计，失败日志保留；路径规范成正斜杠后的tb_m5_loader_gap2_retry与gap5_retry均零错误零告警通过。复现脚本unit现自动追加GAP2/5，新运行输出不带_retry后缀。

## 复现入口

在项目根目录 PowerShell 执行。以下示例名必须尚不存在；重跑时递增，不能覆盖本次证据或固定候选。环境为 ModelSim `F:/modelsim/win64`、TD `E:/TD`，Python统一使用 `py -I -X utf8`。

```powershell
& diagnostics/publicity_mode/run_m3.ps1 -RunName publicity_m3_recheck01
& diagnostics/publicity_mode/run_m2.ps1 -RunName publicity_m3_reader_recheck01
& diagnostics/publicity_mode/run_m3_regression.ps1 -RunName publicity_m3_unit_recheck01 -Suite unit
& diagnostics/publicity_mode/run_m3_regression.ps1 -RunName publicity_m3_top_recheck01 -Suite top
& diagnostics/publicity_mode/run_m3_regression.ps1 -RunName publicity_m3_demo_recheck01 -Suite legacy_top -Card m6_demo
& diagnostics/publicity_mode/run_m3_regression.ps1 -RunName publicity_m3_flood_recheck01 -Suite legacy_top -Card flood_village
& diagnostics/publicity_mode/run_m3_regression.ps1 -RunName publicity_m3_rgba_recheck01 -Suite rgba
& diagnostics/publicity_mode/run_m3_regression.ps1 -RunName publicity_m3_preview_recheck01 -Suite preview
& diagnostics/publicity_mode/run_m3_regression.ps1 -RunName publicity_m3_system_recheck01 -Suite system
& diagnostics/mountain_scene/build_m5.ps1 -BuildName publicity_m3_td_recheck01 -PlacementStrategy 7 -TimingOptimization high -HighAreaOptimization
& diagnostics/publicity_mode/run_m3_audit.ps1 -BuildName publicity_m3_td_recheck01 -TdRoot E:/TD
```

本次已完成的封装命令为 `py -I -X utf8 diagnostics/publicity_mode/package_m3.py publicity_m3_td_attempt14 diagnostics/publicity_mode/m3_logs.json`；脚本拒绝覆盖现有 `m3-local.1`。新候选须递增目录/标签并更新日志映射，不能将复现输出写回本候选。实际155份日志路径及最终PASS标记见 [m3_logs.json](m3_logs.json)，冻结副本见候选 `validation/logs.json`；新的unit运行自动补测loader GAP2/5，文件名没有本次手工补测的 `_retry` 后缀。

## 待人工确认

本阶段板测清单见 [BOARD_VALIDATION_M3](BOARD_VALIDATION_M3.md)。VOI仍为M1测试音，无正式讲解，M3不播放；宣传AUTO/单次EOF留M4，专业审阅/听审/HDMI可读性与整机数据留后续。旧M6/更早未确认项继续待反馈，不新增board或正式版结论。
