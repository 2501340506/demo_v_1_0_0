# 宣传模式 M5 验证记录

日期：2026-10-17；状态：本地仿真、TD及审计通过，固定 v0.18.0-m5-local.1，板测待用户确认。

输入 M4 local.1 `eb7deb3`；用户反馈“M4功能正常”，已记录为 board.1 `e548d72`。开发回退复用 M4 固定 bit，正式回退 v0.16.0。M4 总体确认不扩写成逐项听审或计时结果；M1 的 2/6/8/10 秒 VOI 仍是无人声测试音，专业内容/正式配音及前序 M6 未确认项保持待办。

## 实现与验证边界

M5 仅改三个生产文件。`mode_key_control` 将双应用情景控制限制在00，11的上一/下一转交预览焦点；`sd_card_bmp` 将情景预览提交交给 `scenario_fsm` 新增的默认关闭 `PREVIEW_SELECT` 接口，沿图片、转场、音频事务更新阶段、清预警并重启。同页提交也重启；旧参数关闭路径保留。

01/10参数、B/C/V优先于SPEED、公共参数保持、非00 AUTO门控及身份沿用M3/M4实现，通过本轮专项和实际生产顶层重新验证，不把早期建议端口当成实际新增模块。

## 专项及回归

最终选定183份完成仿真日志及69份编译/模型日志；逐份检查零仿真错误、PASS标记和已知厂商模型/既有诊断范围，不称零告警。索引见[m5_logs.json](validation/logs.json)。

| 运行目录（diagnostics/output/下） | 覆盖与当前结果 |
|---|---|
| publicity_m5_focused03 | 九项通过：参数两应用/四拨码/默认步进饱和/100ms组合/按住释放；情景终态门控与预览事务反压；当前集焦点/提交/同页/预警退出；切换中重扫重武装及真实SD读取失败后的恢复；音量与参数CDC/按键/OSD/十进制显示 |
| publicity_m5_focused02/preview_case1、2、10 | 额外三项通过：旧PIC、缺PIC2、纯EDU无目标情景，预览与拒绝不损坏当前应用 |
| publicity_m5_scan02 | 111项通过；任意目录顺序/尾部资源/缺槽/旧卡/取消恢复，旧参数全部旧输出逐周期对照，VOI异常大小与重复项/GAP回归 |
| publicity_m5_m401 | 七项通过；单次消费完成、会话身份、反压、FIFO尾、音量零、旧EOF、AUTO及元数据等周期比较 |
| publicity_m5_m301 | 17项通过；手势、身份CDC、启动与FAT链、重载case0–9、真实缩放及音频 |
| publicity_m5_unit01 | 22项通过；场景、音频、淡变、FONT/TEXT、缓存、转场、预览、参数、CDC、原PCM，loader GAP2/5 |
| publicity_m5_mode001、101、201、301 | 四项通过；生产SD/cache/scanner/reader完整双模式、缺VOI2、奇数字节VOI2及真实读取失败的回退 |
| publicity_m5_legacy_top01、flood01 | 示意村与山洪村生产旧顶层均通过；山洪村含685006次最终HDMI束检查，8扇区请求及四阶段/速度/预警/参数 |
| publicity_m5_rgba01、system01 | 通过：真实SDRAM混合RGBA；系统591帧/481827精确PCM、17转场、OSD/UART，系统状态快照598帧 |
| publicity_m5_preview01 | 通过：真实SDRAM预览293帧、200预览帧、10提交/10提示、180720次刷新；238405精确PCM/4会话；前景失败保留预览、重试、超时后的缓存选择恢复 |
| publicity_m5_voice_top01 | 完整生产top、实际307200像素scaler、主音量及HDMI音频有效负载逐样本比对通过：6次会话、1536源VOI样本、21948个音量后PCM及21948个HDMI样本逐项一致，四页/AUTO尾部/情景预警及返回 |
| publicity_m5_pixels02 | 完整生产top的实际BMP/scaler写像素、当前集bank映射、参数/SPEED与场景图层最终RGB/时序，独立解码HDMI TMDS，通过：15窗口/262080个RGB与时序、149760字形区、37440内容区、52416预览采样；9953280个HDMI TMDS视频像素解码一致 |
| publicity_m5_status01 | 通过：生产top状态元组CDC至最终RGB，14窗口/46592个精确像素；独立字形核对EDU/SCENE/COMPAT、页码、AUTO、N/W/V/D/E与BUSY/ERROR/NO SET |

最终像素台在外部SDRAM边界保存所有实际scaler写数据，按真实已提交bank/预览描述读出；建模SD扇区运输、外部存储握手和加速栅格。独立参考计算亮度/对比度、字形、边框、灾害着色，对最终RGB和同步逐项比较，检查HDMI视频符号解码。最终RGB采样范围为x=8–631、y=28–51及60–63，覆盖15个稳定窗口，并检查11拍流水后的同步；状态栏补充台采样x=400–607、y=8–23。真实SDRAM读路径由RGBA/系统/预览回归覆盖，不称检查了全部屏幕每一像素。

生产音频top保留真实采样/主音量/HDMI封包与尾部输出核验；加速帧和小源文件不作为板上五秒计时，300帧tick下限另有AUTO专项。旧顶层与长系统回归关闭PUBLICITY，只证明兼容通路，不替代启用双应用的生产top。

状态栏补充台从生产top的状态CDC源接口注入稳定元组，实际使用该top的CDC、视频流水和最终状态渲染；不把注入值写成真实控制器已产生的故障。实际应用、VOI及错误事件由重载、mode与完整音频top覆盖。该补充台不验证SDRAM或缩放。

## TD、审计及失败证据

硬门槛：LUT≤16660/19600、最终Setup/Hold均正、STNS/HTNS为0、无ERROR及完整bitgen。约束不改；隔离快照与111工程输入和根构建脚本逐字节核对，个人问题记录与M5开始副本逐字节一致。

以下为本轮实际隔离构建记录，最终时序取各自 `final_timing.rpt`，不是中间优化输出。所有未达门槛或含ERROR的运行均拒绝交付；失败快照、完整日志和未选构建继续保留 `diagnostics/output/`，不混入固定候选。表中的TNS为对应Setup/Hold总负裕量（ns）。

| 尝试 | LUT | Setup / STNS ns | Hold / HTNS ns | 结论 |
|---|---:|---:|---:|---|
| attempt01 | 16012 | -0.278 / -3.152 | +0.030 / 0.000 | 拒绝交付 |
| attempt02 | 15990 | -2.047 / -131.344 | +0.024 / 0.000 | 拒绝交付 |
| attempt03 | 16012 | -0.278 / -3.152 | +0.030 / 0.000 | 拒绝交付 |
| attempt04 | 16029 | -0.262 / -0.433 | +0.030 / 0.000 | 拒绝交付 |
| attempt05 | 16030 | -0.360 / -3.237 | +0.024 / 0.000 | 拒绝交付；PHY-8103 |
| attempt06 | 16033 | +0.102 / 0.000 | +0.009 / 0.000 | 拒绝交付；PHY-8103 |
| attempt07 | 16029 | +0.107 / 0.000 | +0.009 / 0.000 | 拒绝交付；PHY-8103 |
| attempt08 | 16021 | -1.699 / -2.875 | +0.009 / 0.000 | 拒绝交付 |
| attempt09 | 16021 | -1.699 / -2.875 | +0.009 / 0.000 | 拒绝交付 |
| attempt10 | 15990 | -2.047 / -131.344 | +0.024 / 0.000 | 拒绝交付 |
| attempt11 | 16009 | -0.927 / -6.449 | +0.047 / 0.000 | 拒绝交付；PHY-8103 |
| attempt12 | 16031 | 无最终报告 | 无最终报告 | 拒绝交付；PHY-8023, PHY-8075, RUN-8102 |
| attempt13 | 16011 | -0.448 / -1.072 | +0.047 / 0.000 | 拒绝交付；PHY-8103 |
| attempt14 | 16055 | -0.354 / -2.099 | +0.014 / 0.000 | 拒绝交付 |
| attempt15 | 17761 | -5.469 / -633.286 | -0.011 / -0.011 | 拒绝交付；PHY-8023 |
| attempt16 | — | 无最终报告 | 无最终报告 | 拒绝交付；PHY-9009 |
| attempt17 | 16054 | 无最终报告 | 无最终报告 | 拒绝交付；PHY-8023, RUN-8102 |
| attempt18 | 16033 | 无最终报告 | 无最终报告 | 拒绝交付；PHY-8023, RUN-8102 |
| attempt19 | 16034 | -0.125 / -0.159 | +0.021 / 0.000 | 拒绝交付 |
| attempt20 | 16002 | 无最终报告 | 无最终报告 | 拒绝交付；PHY-8023, RUN-8102 |
| attempt21 | 15986 | -0.437 / -6.290 | +0.004 / 0.000 | 拒绝交付 |
| attempt22 | 16047 | -0.263 / -0.263 | +0.014 / 0.000 | 拒绝交付 |
| attempt23 | 16068 | -0.113 / -0.541 | +0.024 / 0.000 | 拒绝交付 |
| attempt24 | 16041 | -0.725 / -2.534 | +0.021 / 0.000 | 拒绝交付 |
| attempt25 | 16034 | -0.621 / -2.721 | +0.021 / 0.000 | 拒绝交付 |
| attempt26 | 16069 | -0.350 / -0.639 | +0.014 / 0.000 | 拒绝交付 |
| attempt27 | 16022 | +0.006 / 0.000 | +0.030 / 0.000 | 选定，本地达标 |
| attempt28 | 16026 | 无最终报告 | 无最终报告 | 拒绝交付；PHY-8023, RUN-8102 |
| attempt29 | 16034 | 无最终报告 | 无最终报告 | 拒绝交付；PHY-8103, PHY-8023, RUN-8102 |
| attempt30 | 16020 | -0.385 / -2.881 | +0.021 / 0.000 | 拒绝交付；PHY-8103 |

最终构建 `publicity_m5_td_attempt27`；物理参数：`place seed 12 place hfn_opt_effort high place effort high place pr_strategy 5 place opt_timing high`；综合参数：`gate opt_area high gate pack_effort high`。根runner新增可选PlacementSeed，默认0保持原行为，TD原生参数依据 `E:/TD/doc/scripts/MultiSeed.tcl`；未改变RTL或约束。

合格构建已执行check_timing和独立最终报告审计；汇总与M4及规范化告警差异按实际审阅，固定[审计说明](reports/AUDIT_REVIEW.md)与原始报告。保留9输入无delay、16输出无delay、sd_miso max21/min0与两BRAM32k dummy等既有例外；不称零告警或全IO覆盖。

focused01为测试台焦点预期错误；pixels01为测试台变量声明顺序导致编译失败；scan01旧runner未显式连接新增端口，行为通过但告警不合格，改用M4端口适配runner重跑scan02。上述失败不纳入候选合格日志，不删除。最终183份仿真及69份编译/模型日志核验通过；111输入、根脚本、三份变化生产源和固定bit逐字节一致，个人记录与M5起始副本逐字节一致、不提交。

## 复现

最终TD命令（必须使用新BuildName）：

```powershell
& diagnostics/mountain_scene/build_m5.ps1 -BuildName publicity_m5_recheck_td01 -PlacementStrategy 5 -PlacementSeed 12 -TimingOptimization high -HighPlaceEffort -HighAreaOptimization
& diagnostics/publicity_mode/run_m4_audit.ps1 -BuildName publicity_m5_recheck_td01 -TdRoot E:/TD
```

```powershell
& diagnostics/publicity_mode/run_m5.ps1 -RunName publicity_m5_recheck_special01 -Suite m5
& diagnostics/publicity_mode/run_m4_scan.ps1 -RunName publicity_m5_recheck_scan01
& diagnostics/publicity_mode/run_m5.ps1 -RunName publicity_m5_recheck_pixels01 -Suite pixels
& diagnostics/publicity_mode/run_m5.ps1 -RunName publicity_m5_recheck_voice01 -Suite voice_top
& diagnostics/publicity_mode/run_m5.ps1 -RunName publicity_m5_recheck_mode01 -Suite mode -Case 0
```

其他Suite=m4/m3/unit/legacy_top/rgba/system/preview；mode补Case1–3；legacy_top分别Card=m6_demo/flood_village。额外预览用同一编译库对tb_m5_preview执行CARD_CASE=1/2/10。输出目录须不存在，Python用 `py -I -X utf8`，禁止覆盖历史候选。完整操作及待板测项见[说明](../../../docs/宣传模式操作与板测.md)。
