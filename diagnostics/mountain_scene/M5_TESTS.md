# M5 本地验证（2026-10-16）

开发输入 v0.17.0-m4-local.1，正式版回退 v0.16.0。ModelSim SE-64 10.6e：F:/modelsim/win64；TD 6.2：E:/TD。所有运行使用新目录，历史失败和中间输出保留在 diagnostics/output。本地通过不代表板测通过。

## 已完成的专项

| 范围 | 运行 | 实际结果 |
|---|---|---|
| FONT/TEXT 扫描 | mountain_m5_unit03 | GAP=0/2，各六种目录场景：文件在 PIC/BGM/SND 后、目录 FAT 链、重名、属性、扩展名、缺失、重扫 |
| 文件到 BRAM | mountain_m5_unit03 | GAP=0/2，各十种加载场景：4096 字节/八簇、偏移、部分末扇区、缺失、错误大小/簇/扇区、提前 EOF、重新加载 |
| 文本与字库像素 | mountain_m5_text06 | 实际 EG4 BRAM32k 双时钟模型，3,529,098 次像素/视频随行信号比较；四阶段、村名、滚动字幕、预警、13 个旧中文字、八类损坏/重载/缺失场景；16 种转义逐行对比原 5×7 字库 |
| 参数条与数码管 | mountain_m5_unit03 | 110 次物理段码采样，阶段 1..4/A、SD 错误优先、旧 AUTO 小数点、576 个 1X/2X/4X 速度文字像素 |
| 生产顶层新卡 | mountain_m5_integration03 | 实际 SD 扇区服务→加载器→BRAM→资源 CDC→最终 HDMI，684745 次视频束比较、六次扇区请求，四阶段/速度/预警/数码管 |
| 原顶层与场景顶层 | mountain_m5_legacytop03 / top04 | 分别 336269/414125 像素、1148/1392 音频采样，普通/调节/预览/黑场/静音 |
| M4 控制回归 | mountain_m5_m4unit03 | FSM、样本 CDC、淡变、按键、SND 扫描五个测试台通过 |
| 生产场景 PCM | mountain_m5_scenario_pcm01 | 69840 个精确样本、十次会话，四阶段/循环/预警/速度/SND3 回退/静音切换/重扫/无音频帧时钟 |
| PCM 重扫回归 | mountain_m5_pcm02 | production / preview_rescan 分别 9279 / 9280 次精确比较，碎片循环、在途重扫、错误重试、缺 BGM、仅音频、短文件 |
| PC 工具 | mountain_m5_image_tool02 / audio_tool02 / text_tool03 | 8+4+3 项通过；两份新目录的 44 个输出逐字节一致，PIC/SND 与 M4 固定素材一致，原 13 字点阵逐位一致、编码/上限/拒绝覆盖 |
| 缩放/预览整机 | mountain_m5_preview02 | 253 帧、174 预览帧、6 次提交/提示音、156272 次刷新、206204 个精确 PCM 样本，两次会话，无上溢/下溢 |
| 完整系统 | mountain_m5_system02 | 591 帧、22 次提交/提示音、15 次缓存命中、365203 次刷新、481827 个精确 PCM 样本，五次会话，无上溢/下溢；17 次转场及 251159248 次 OSD/消隐检查 |
| SD 超时路径与物理接口 | mountain_m5_sd02 | M4 原模块与最终模块五组参数、至少 1011617 次全部公开输出逐拍一致；1/2 周期边界、响应/令牌超时、读写/数据态/随机复位；协议、初始化、物理 SPI 引脚 CRC7/CMD59/CRC16、三次重试后停止四项回归均通过，无告警 |

FONT.BIN 为 1536 字节，TEXT.BIN 为 104 字节；另从二进制点阵重建预览，人工检查四阶段中文、预警语及“示意村”可读。此检查只涉及本机生成物，不替代板上显示验收。

## 回归与最终构建状态

最终 reader 小常数比较由 32 位比较改为高位归零与低六位比较，数学结果及周期不变。该等价改写后 mountain_m5_reader03（24bpp 全 42 例）、mountain_m5_reader3205（32bpp 全 42 例）及 mountain_m5_reader3204（32bpp 缩放 0..3）全部通过。长整机/预览回归 mountain_m5_system02 / preview02 在该等价改写及最终 ASCII 等价译码前编译；包括 M5 扫描器提交寄存、13 位资源加载计数和数码管半周期寄存等全部行为变化；旧整机测试不例化新增文字叠加器。最终 ASCII 译码由 text06/integration03/top04/legacytop03 覆盖。最后的 SD 超时等周期切分由 sd02 对 M4 原模块及物理 SPI 回归覆盖；此前的顶层/长整机在扇区接口注入数据，不验证物理 SPI。共 112 份选定仿真日志、28 份编译日志审核通过。

TD attempt01/02 为工程源条目问题；attempt03/04/05 虽生成 bit，时序未达标，均不可上板。attempt05：16327 LUT，Setup −0.521ns、Hold −0.011ns。attempt06 局部布线冲突失败；attempt07：16205 LUT，Setup −0.105ns/Hold −0.020ns；attempt08：16405 LUT，Setup −0.121ns/Hold −0.020ns。07/08 的 Slice 占用超过工具 Hold 修复门槛。attempt09 高面积/打包优化恢复 Hold +0.024ns，但 Setup −1.154ns。attempt10/11 配合 ultra 时序优化后，Setup 均为 −0.007ns，Hold 分别 +0.024/+0.004ns；仍拒绝作为候选。后续保持 RTL/约束不变检查其他布局策略。固定候选必须同时满足正 Setup/Hold、LUT ≤16660、实际两块 BRAM32k、无 ERROR、完整 bitgen、全部工程输入逐字节一致和时序审计。

attempt12/13 的布局策略 5/8 均因局部布线冲突失败；attempt14 增加布线后优化、15 增加布局 effort，仍为 Setup −0.007ns/Hold +0.004ns，均拒绝交付。随后仅切分报告中的旧 sd_card_cmd 超时比较路径，约束未改。attempt16 布线中间 Setup 已正，但 Hold 修复时报 PHY-8023/8075 无效物理复位引脚及 RUN-8102，拒绝交付。sd01 为测试运行器的 Windows 库路径格式问题，编译通过、仿真未装载；改用正斜杠后 sd02 五项全部通过。

attempt17 同样在 Hold 修复时报无效物理复位引脚；attempt18 虽完成 bitgen，最终 Setup +0.064ns/Hold +0.024ns，但物理日志包含 PHY-8103 内部 ERROR，仍拒绝交付。attempt19/20 更换布局策略或降低布局后优化强度，仍在激进路径优化步骤报同类内部 ERROR。随后回到 timing high 检查；失败 bit 不进入 releases。

attempt21（strategy 7、timing high）完整 bitgen、无 ERROR，但 Setup −0.035ns/Hold +0.021ns，拒绝交付；attempt22（strategy 9、timing high）仍有 PHY-8103 ERROR，最终 Setup −0.291ns/Hold +0.014ns，同样拒绝交付。

attempt23（strategy 7、timing high/post-place high）仍为 −0.035/+0.021ns，拒绝交付。最终 attempt24 使用 strategy 5、timing high、post-place auto、高面积/打包/扇出/布线 effort，无 ERROR、完整 bitgen：14897 LUT、9707 寄存器、56 BRAM9k、2 BRAM32k、13 DSP，Setup +0.008ns/Hold +0.014ns，TNS 0。111 个工程输入及构建脚本逐字节一致，仅保存 13 个变化输入；bit 实际 673856 字节。TD 告警与 M1 规范化比较无新增；审计比 M1 多出 EG_PHY_BRAM32K dummy 模型类别，具体为 FONT/TEXT 两个 ram.dob[9]，其余汇总及所有例外相同。完整报告保留，不以仿真代替此项板级确认。

封装初次检查沿用 M4 bit 长度和审计完全相同的假设，均在写入候选前停止。按实际 M5 长度及上述两个精确 BRAM 节点修正后，通过全部门槛并固定 m5-local.1；未修改候选 RTL、约束或 bit。

## 复现入口

在仓库根目录 PowerShell 运行，RunName/BuildName 必须使用新名字：

```powershell
& diagnostics/mountain_scene/run_m5_unit.ps1 -RunName mountain_m5_unit_new
& diagnostics/mountain_scene/run_m5_text.ps1 -RunName mountain_m5_text_new
& diagnostics/mountain_scene/run_m5_top.ps1 -RunName mountain_m5_integration_new
& diagnostics/mountain_scene/run_m4_top.ps1 -RunName mountain_m5_top_new
& diagnostics/mountain_scene/run_m4_top.ps1 -RunName mountain_m5_legacytop_new -Legacy
& diagnostics/mountain_scene/run_m4_pcm.ps1 -RunName mountain_m5_scenario_pcm_new
& diagnostics/mountain_scene/run_legacy.ps1 -Suite reader -RunName mountain_m5_reader_new
& diagnostics/mountain_scene/run_legacy.ps1 -Suite reader32 -RunName mountain_m5_reader32_new
& diagnostics/mountain_scene/run_legacy.ps1 -Suite reader32 -RunName mountain_m5_scale32_new -ScaleTest 1 -Cases @(0,1,2,3)
& diagnostics/mountain_scene/run_legacy.ps1 -Suite pcm -RunName mountain_m5_pcm_new
& diagnostics/mountain_scene/run_legacy.ps1 -Suite preview -RunName mountain_m5_preview_new -Mixed 1 -Audio
& diagnostics/mountain_scene/run_legacy.ps1 -Suite system -RunName mountain_m5_system_new
& diagnostics/mountain_scene/run_m5_sd.ps1 -RunName mountain_m5_sd_new
py -I -X utf8 diagnostics/mountain_scene/test_scene_text.py
& diagnostics/mountain_scene/build_m5.ps1 -BuildName mountain_m5_attempt_new -PlacementStrategy 5 -HighRouteEffort -HighAreaOptimization -TimingOptimization high
& diagnostics/mountain_scene/run_legacy.ps1 -Suite audit -RunName mountain_m5_attempt_new
py -I -X utf8 diagnostics/mountain_scene/package_m5.py mountain_m5_attempt_new --candidate m5-reproduction
```

编译与仿真逐日志检查 Errors: 0；仅保留已知厂商 IP 告警，未知告警拒绝。M5 顶层多出的两条为新增 BRAM32k 未使用端口模型告警。通过的具体日志与标记由 m5_logs.json 固定，打包脚本重新检查并保留原字节。

早期 text01/02 为参考测试台的字库/预警期望错误，修正后 text03/04 通过；reader3203 为 PowerShell -File 数组传参被解析为 123，后改用脚本调用和 @(0,1,2,3)，reader3204 通过。失败输出不入候选。
