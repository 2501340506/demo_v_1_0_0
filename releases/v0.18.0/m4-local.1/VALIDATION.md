# 宣传模式 M4 验证记录

输入为M3 local.1（fdb8065）及其用户总体板测确认board.1（adfdd66），在原目录feature/science-publicity-mode实施。开发回退为M3固定bit，正式回退v0.16.0。M1四段VOI仍为2/6/8/10秒测试音，无人声；本记录不构成正式内容/配音审阅或M4板测结论。

## 实现范围

VOI按显示提交逐页从头单次播放，包含同页预览提交。短文件缓存与长文件两条循环路径均禁用；源EOF后继续供静音采样，使主音量淡变可完成。真实源样本逐项标记，只有消费者valid/ready接受最后源样本后才产生正常完成，音量零不改变进度。正常完成、读错和取消分别处理。

会话身份为{资源版本4位,应用2位,页号2位,会话8位}；先停止旧流、FIFO排空、确认及guard，再更新元数据/会话。完成为四相电平，身份稳定保持到停止确认。读域在run到达前采集稳定bundle，不对多位参数独立双触发采样。控制器仅接受当前身份，旧EOF不触发新页完成。

00短KEY4切宣传AUTO，完整淡入且音频就绪后至少300帧tick，并等待有效讲解消费完成；终态另留两个后续帧给HDMI管线。缺失/错误静音并按最短停留回退，分别显示N/E；E红色，播放V、完成D、等待W、自动/手动A/M。非00不自动翻页，保留完成，回00重新计300帧。手动优先，切应用AUTO关闭。情景SND/BGM/COMPAT保持循环。完整OSD整理属M5。

## 专项与回归

`m4_logs.json`列出选用的169份仿真日志路径及最终PASS标记，全部已完成并核验通过。编译/厂商模型日志另行逐项核验。专项测试在新输出目录生成端口适配副本，历史bench、参考RTL和冻结候选不修改。

| 运行目录（diagnostics/output/下） | 实际覆盖 |
|---|---|
| publicity_m4_finalspecial06 | 七项：播放器925个精确源样本；1/255/601/19/33/7样本、短预填充、正负/非零尾、反压、音量零、取消/身份复用；真实文件流1459个精确样本、2/512/1202字节、248次并发图片读取、碎片/缺失/奇数/空/读错；AUTO真实300tick、长短讲解、旧身份、尾帧保护、同页重启、手动、非00锁存和返回重计；原PCM流/播放器/mux回归；簇范围半字比较与冻结TD06源800用例/19428周期对照，状态及外部输出一致 |
| publicity_m4_acceptmode0_01 | 生产SD/cache/scanner/reader，四页逐槽VOI，2048精确样本/8会话；前后翻、同页预览提交、参数页完成锁存、AUTO、预警警报及双向应用切换，不物理重扫 |
| publicity_m4_acceptmode1_01、2_01、3_01 | 缺VOI2、奇数VOI2、真实扇区LBA21读取失败；缺/错误不同状态及AUTO回退 |
| publicity_m4_finalscan02 | 111项：108原scanner/reader回归，任意目录顺序/尾项/缺槽/旧卡/取消恢复；默认关闭与8a90155全部旧输出逐周期一致。另三种GAP各六扫描，空/奇数/越界、坏后好/好后坏重复、属性/重扫/复位清错 |
| publicity_m4_finalm3_04 | 17项：手势、192次身份CDC、启动/FAT链各20个边界、scanner25个边界、重载case0–9及SCALE/AUDIO；调整M3短AUTO检查后关AUTO，不再要求宣传永久静音 |
| publicity_m4_finalunit01 | 22项：场景/音频/淡变/预警速度、FONT/TEXT、参数、缓存、转场、预览、CDC、PCM生产/重扫；bin_loader GAP2/5 |
| publicity_m4_legacy01、legacy_flood01 | 示意村、山洪村各两项生产旧顶层，FONT/TEXT/场景中文 |
| publicity_m4_rgba01 | 真实SDRAM，四尺寸混合RGBA、缩放、31帧 |
| publicity_m4_preview01 | 真实SDRAM预览/转场/故障恢复，293帧、238405精确PCM/4会话 |
| publicity_m4_system01 | 真实SDRAM整机OSD/UART/转场/重扫恢复，591帧、481827精确PCM/5会话、22次提交，无underrun/overrun |
| publicity_m4_voice_top_final04 | 生产完整top、实际307200像素scaler、主音量、mux、HDMI packetizer/scheduler；源样本、实际gain缩放、每包四组双声道payload逐项核对；AUTO时检查末数据岛已发出。通过：1536 exact VOI source samples / 6 sessions, 21948 scaled PCM and 21948 HDMI payload samples; four pages, AUTO after transmitted tail, scene warning and return; real 307200-pixel scaler |

生产顶层保留真实音频采样/主音量淡变；外部SD运输、存储握手/raw视频时序为模型。帧为8000个像素时钟的加速时序，300tick的下限另由控制器专项核验，不能把顶层仿真墙钟或加速帧当板上五秒。双模式mode专项用2×2图片以覆盖大量交互；完整307200像素由生产top补齐。RGBA/长系统/预览/双村旧top关闭PUBLICITY，只证明兼容路径，不替代新模式验证。

最终scanner大小资格与file_streamer快照优化由finalspecial06、finalscan02、四种finalmode、finalm3_04及最终top覆盖。最后簇范围半字比较有800例/19428周期冻结源对照，保留CHECK/VERIFY周期；应用音源启动门控由最终四种mode/17项M3/生产top覆盖，mode0另断言目标资源选定前audio_run不能启动。unit/双村回归早于上述等周期优化和新应用门控；长系统/预览/RGBA早于单次metadata VERIFY与读域bundle优化，但其PUBLICITY关闭路径不启用单次或新应用门控。记录此范围，不称所有日志均由最终同一输入快照运行。

## TD与失败证据

硬门槛：LUT≤16660/19600，Setup/Hold均正、STNS/HTNS均0，无ERROR且完整bitgen；111工程输入和根构建脚本与隔离快照逐字节一致。约束及用户TD工程不改。

| 构建 | 实际结果 |
|---|---|
| attempt01 | PHY内部coredump，拒绝 |
| attempt02 | bitgen但Setup −1.062ns/STNS −24.272ns，Hold +0.014ns、16328 LUT，拒绝 |
| attempt03 | bitgen但Setup −0.561ns/STNS −1.556ns，Hold +0.011ns、16282 LUT，拒绝 |
| attempt04 | Setup −0.913ns/STNS −9.655ns、Hold +0.024ns，PHY-8103 ERROR，拒绝 |
| attempt05 | bitgen但Setup −0.131ns/STNS −0.512ns、Hold +0.004ns，16055 LUT，拒绝 |
| attempt06 | bitgen但Setup −0.541ns/STNS −0.832ns、Hold +0.004ns，16118 LUT，拒绝 |
| attempt07 | PHY-8023/RUN-8102增量布线失败，拒绝 |
| attempt08 | 源码发现应用启动门控问题后中止自己的旧源码构建；无候选 |
| attempt09 | PHY-8023/RUN-8102增量布线失败，16025 LUT，拒绝 |
| attempt10、11 | 审查新增TMR-2509/2507发现AUTO valid/ready组合反馈，修正前中止自有构建，无候选 |
| attempt12 | 无组合环诊断，完整bitgen但Setup −0.655ns/STNS −3.114ns、Hold +0.014ns，16007 LUT，拒绝 |
| attempt13 | 完整bitgen但Setup −0.414ns/STNS −0.435ns、Hold +0.014ns，15970 LUT，拒绝 |

依据真实关键路径，音频选源校验分拍、稳定bundle先采入读域再比较、scanner大小资格与entry_commit同拍寄存、FAT值与当前簇快照改连续采样而保持既有消费周期。第五轮剩余路径为扫描器表寄存器布线；同源码换布局的第六轮仍未达标，按其主路径再将单次音频簇范围比较拆为寄存的高/低16位谓词，保持原CHECK/VERIFY周期。没有修改约束。

早期生产top最终coverage失败，未纳入合格日志。先修正测试台跨时钟采样AUTO单拍事件的问题；final02完整运行随后明确报告7会话/1565源样本（应为6×256=1536），其中切入情景时旧VOI在静音转场内额外启动并消费29样本。原因是READY先于目标音源请求，audio_session已允许旧选择启动；已在其寄存启动门控中要求selected_publicity与scan_application匹配，避免给audio_run组合高扇出路径加译码。该修复的四种mode及17项M3回归通过。随后审查TD新增TMR-2509/2507，定位到auto_offer→cache_target→request_ready→auto_offer组合环；请求不再依赖ready，只在auto_accept使用ready，优先级/转场/前台忙在独立门控处理。专项新增ready低时请求仍保持且不接受的断言。最终完整重跑为voice_top_final04，保留逐样本及整体会话覆盖断言，不删断言绕过失败。

metadata最初生成器对共享端口宏再次补端口，compile报28项重复连接，已改为显式宏例化跳过旧端口适配；finalspecial06七项全过，失败finalspecial04保留。FastDebug仅诊断，不作为生产缩放/音频证据。历史失败和中止的自有诊断任务均留在diagnostics/output。

## 复现与当前状态

```powershell
& diagnostics/publicity_mode/run_m4.ps1 -RunName publicity_m4_special_recheck01 -Suite m4
& diagnostics/publicity_mode/run_m4.ps1 -RunName publicity_m4_mode_recheck01 -Suite mode -Case 0
& diagnostics/publicity_mode/run_m4.ps1 -RunName publicity_m4_top_recheck01 -Suite voice_top
& diagnostics/publicity_mode/run_m4_scan.ps1 -RunName publicity_m4_scan_recheck01
& diagnostics/publicity_mode/run_m4.ps1 -RunName publicity_m4_m3_recheck01 -Suite m3
& diagnostics/publicity_mode/run_m4.ps1 -RunName publicity_m4_unit_recheck01 -Suite unit
& diagnostics/mountain_scene/build_m5.ps1 -BuildName publicity_m4_td_recheck01 -PlacementStrategy 5 -TimingOptimization high -HighAreaOptimization -HighPlaceEffort
& diagnostics/publicity_mode/run_m4_audit.ps1 -BuildName publicity_m4_td_recheck01 -TdRoot E:/TD
```

输出目录必须不存在；mode Case1–3分别补缺失/奇数/读错；legacy_top分别Card=m6_demo/flood_village，其他Suite=rgba/system/preview。Python生成器用`py -I -X utf8`。ModelSim F:/modelsim/win64，TD E:/TD。

当前：169份仿真及53份编译/模型日志核验通过；最终生产top通过，publicity_m4_td_attempt14达标，审计已人工核对。固定v0.18.0-m4-local.1，等待本候选板测。

## 最终构建与封装

publicity_m4_td_attempt14：15966 LUT（81.46%）、10683寄存器、56 BRAM9k、2 BRAM32k、13 DSP；Setup +0.072ns/Hold +0.003ns，TNS0，无ERROR且完整bitgen，bit 673856字节。配置以固定reports/phy_1_settings.cfg和构建脚本为准。审计的真实差异说明见固定候选reports/AUDIT_REVIEW.md，不把厂商/既有诊断称为零告警。

111个工程输入及根构建脚本与隔离快照逐字节一致；仅备份相对v0.18.0-m3-local.1变化的8个生产文件。个人问题记录909字节与开始副本一致，不修改、不提交。所有证据/bit/变化源码复制后逐字节核对，不生成文件哈希。169份仿真及53份编译/模型日志核验通过，仿真无ERROR/FATAL；保留已知厂商模型、PLL端口和多宏定义等诊断，拒绝新增未知告警。最终watchdog使用64位常量。

M4板测、正式配音/专业内容审阅、M5/M6完整交互与整机计时仍待完成；不替前序v0.17.0/M6补验收。
