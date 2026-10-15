# M5 本地验证（2026-10-16）

候选 `v0.17.0-m5-local.1`，输入 `v0.17.0-m4-local.1`，生产提交 `ba79e51`、`74a79d3`。以下为实际本地结果，板测待用户确认。完整运行记录与复现命令见 [M5_TESTS](../../../diagnostics/mountain_scene/M5_TESTS.md)，选定日志与 PASS 标记见 [logs.json](validation/logs.json)，格式及接线约定见 [M5_IMPLEMENTATION](../../../docs/M5_IMPLEMENTATION.md)。

| 范围 | 实际结果 |
|---|---|
| 扫描器、加载器 | unit03：GAP=0/2，各六种目录场景、各十种加载场景；含目录 FAT 链、重名、属性、缺失、重扫、4096 字节/八簇及错误回退 |
| FONT/TEXT 像素 | text06：真实 BRAM32k 双时钟模型，3529098 次像素/视频束检查；四阶段、村名、滚动、预警、旧 13 字、八类损坏/重载/缺失；16 种 ASCII 转义逐行对比原字库 |
| UI 与生产新卡顶层 | unit03：110 次物理段码采样、576 个速度文字像素；integration03：684745 次最终 HDMI 视频束检查、六次扇区请求，覆盖加载/CDC/四阶段/速度/预警/面板 |
| 场景/旧顶层 | top04：414125 像素、1392 音频样本；legacytop03：336269 像素、1148 音频样本 |
| M4 控制与 PCM | m4unit03 五个测试台；scenario_pcm01：69840 个精确样本、十次会话，四阶段/循环/预警/速度/缺 SND3 回退/静音切换/重扫/无音频帧时钟 |
| 原 PCM 回归 | pcm02：production/preview_rescan 分别 9279/9280 次精确比较，碎片、短循环、在途重扫、重试、缺文件 |
| BMP reader | reader03：24bpp 全 42 例；reader3205：32bpp 全 42 例；reader3204：32bpp 缩放 case0..3 |
| 缩放预览整机 | preview02：253 帧、174 预览帧、6 次提交/提示音、156272 次刷新、206204 个精确 PCM 样本、两次会话，无上溢/下溢 |
| 完整系统 | system02：591 帧、22 次提交/提示音、15 次缓存命中、365203 次刷新、481827 个精确 PCM 样本、五次会话，无上溢/下溢；17 次转场/183705600 像素，598 帧快照/251159248 次 OSD 与消隐检查 |
| SD 等价与物理接口 | sd02 五项：与 M4 原模块五组参数至少 1011617 次全部公开输出逐拍比较；含 1/2 周期边界、响应/令牌超时、读写/数据态/复位；协议、初始化、物理 SPI CRC7/CMD59/CRC16 及三次重试后停止回归 |
| PC 工具 | 图像 8 项、音频 4 项、文字 3 项；44 个输出在新目录逐字节复现，PIC/SND 与 M4 相同，前 13 字点阵一致，格式/上限/拒绝覆盖通过；生成字体预览本机目视可读 |

共 112 份选定仿真、28 份编译日志，Errors=0、要求的 PASS 标记齐全。已知厂商 IP/PLL/glbl/多宏告警保留；新增 BRAM32k 在顶层模型中的两个未使用端口告警也保留，不将未知告警作为通过。

长整机 system02/preview02 编译于最终 reader 小常数比较及 ASCII 等价改写之前，包含 M5 全部行为变化；最终 reader 由上述 42+42+4 用例覆盖，ASCII 由 text06/integration03/top04/legacytop03 覆盖。SD 超时等周期切分由最终 sd02 对照 M4 模块及物理 SPI 测试覆盖；此前顶层和长系统在扇区接口注入数据，不证明物理 SPI 或板级 SD/HDMI 行为。旧系统长回归不例化新增场景文字叠加器。

## TD 构建与时序审计

TD 6.2（E:/TD），合格构建 `mountain_m5_attempt24`，命令如下；必须以新 BuildName 复现，避免覆盖原输出：

```powershell
& diagnostics/mountain_scene/build_m5.ps1 -BuildName mountain_m5_attempt_new -PlacementStrategy 5 -HighRouteEffort -HighAreaOptimization -TimingOptimization high
& diagnostics/mountain_scene/run_legacy.ps1 -Suite audit -RunName mountain_m5_attempt_new
```

构建启用 high fanout；综合 `gate opt_area high gate pack_effort high`，物理 `place hfn_opt_effort high route effort high place pr_strategy 5 place opt_timing high`，post-place auto。时钟、引脚、约束及 SD 超时参数未改。综合与物理进程 exit 0、无 ERROR、bitgen 完整结束。最终资源为 14897 LUT/LE（76.01%）、9707 寄存器、56 BRAM9k、2 BRAM32k、13 DSP；Setup +0.008ns、Hold +0.014ns、两者 TNS 0，STA coverage 99.97%。原始 [面积](reports/demo_phy.area)、[时序](reports/final_timing.rpt)、[物理日志](reports/phy_1_build.log) 与配置均已保存。

TD 综合/物理告警规范化后无新增。相对 M1，[check_timing](reports/check_timing.txt) 新增 `EG_PHY_BRAM32K` dummy-node 模型类别，具体只有：

```text
g_scene_text$font_ram/ram.dob[9]
g_scene_text$text_ram/ram.dob[9]
```

工具的 dangling 汇总从 3 类变为 4 类；其余审计汇总及所有时序例外与 M1 相同，无新增无时钟、环路或无效约束项。打包脚本严格检查上述两个节点和该类别变化，未放宽约束或忽略其他差异。这两项 dummy-node 的原因未进一步定位，保留原报告作为工具模型限制和板测待确认项。

111 个工程/源码/约束输入及根构建脚本与 attempt24 快照逐字节一致；[清单](MANIFEST.md) 列出输入大小，仅保存相对 M4 变化的 13 个输入。工程相对 M4 仅增加 CompileOrder 106–108 三个 M5 源条目。固定 bit 为 673856 字节，与 attempt24 逐字节一致。报告、验证日志及源码通过局部 .gitattributes 保留原始字节。初次封装检查沿用 M4 bit 大小和审计完全相同假设，在创建候选目录之前停止；修正为实际大小及上述具体差异后成功封装，未改变 RTL、约束或 bit。

## 历史失败与未验证项

attempt01–23 因工程源条目、负时序、布线冲突或工具内部 ERROR 被拒绝，失败证据留在 diagnostics/output；包括时序为正但包含 PHY-8103 ERROR 的构建。只交付 attempt24，详细失败及仿真测试台修正记录见 M5_TESTS。

M5 尚未上板、未建立 board 标签、未推送 M5；M1/M3 单独板测及 M2 用户目视仍待确认。占位音效不能证明旁白关键词同步，ffmpeg 不在 PATH，仅原生 WAV 路径实测。第二张卡、40 分钟稳定性、Flash 与冷启动计时属于 M6，未实施。请按 [板测步骤](BOARD_VALIDATION.md) 使用本目录固定 bit 验收；TD GUI 先重新加载磁盘工程再保存，避免旧工程覆盖新增源。
