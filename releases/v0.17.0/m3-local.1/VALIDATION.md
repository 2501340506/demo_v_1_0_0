# M3 local.1 本地验证

日期2026-10-15；功能基线v0.16.0，输入M1 local.1和M2素材3535c0b。用户明确要求先执行M3，本地实现完成不视为M1板测或M2用户目视通过。M3板测待确认，未建立board标签、未推送。正式版仍为v0.16.0。

## 本地验证范围

生产实现：两拍hazard_layer、临时scene_demo_timing、top的32位video_delay与显示接线、demo.al两个新增源码项。T与RGB使用同一拍SDRAM数据，RGB和48位随行信号在图层统一延迟两拍；显示调节路径总计六拍。图层遵循M2精确RGB、完整和后右移、前沿差值0–5、避险点250、保留值/255旁路规则。

清单中的9份仿真日志全部通过，19份编译日志另存；打包器逐份检查PASS、Errors=0及已知告警，原始证据见 `validation/`。所有运行正常退出，结果如下。

| 项目 | 实际结果与检查范围 |
|---|---|
| hazard单位测试 | 24张M2原始expected PNG直接导出，不重算参考图；7393796次RGB/随行比较，覆盖所有T、前沿0–5/6、四种闪烁组合、旁路、复位；Errors0/Warnings0 |
| 临时帧时间源 | 1930帧：每两帧递增，239回绕，阶段提交不在帧内变化，首像素与后续一致，ready/preview/reset，四种快闪和1Hz慢闪；Errors0/Warnings0 |
| M3生产top | 414125像素、1392音频样本；四stage/T注入、同步坐标六拍对齐、亮度/对比度、预览/焦点/空格、转场、黑屏、静音；Errors0/Warnings43 |
| 旧生产top回归 | 336269像素、1148音频样本；原用例，仅将T固定FF、期望延迟4→6；Errors0/Warnings43 |
| 真实SDRAM与hazard | FAT32→缩放→FIFO→受保护控制器→command/DQ SDRAM→32位video_delay→hazard；四尺寸160×120/801×601/640×480/317×479，31完整帧，10137598有效像素/随行检查，首有效像素阶段与显示bank图片一致；Errors0/Warnings32 |
| PCM生产 | 9279个样本逐一匹配，4图、碎片循环、读中重扫、错误回退/重试、缺BGM、音频卡冷启动、短循环；Errors0/Warnings0 |
| PCM预览重扫 | 9280个样本逐一匹配，含预览返回重扫；Errors0/Warnings0 |
| 混合尺寸预览 | 293帧、200预览帧、10提交/提示音、180720刷新；238405个PCM样本、4会话，无欠载/溢出；失败前台保持预览、重试、超时缓存选择通过；Errors0/Warnings26 |
| 完整系统 | 591帧、14启动、10缓存完成、22提交/提示音、15命中、365203刷新；481827个PCM样本、5会话，无欠载/溢出；2次AUTO擦除、15次手动淡变、17黑帧；598帧边界、251159248像素/消隐检查、4阶段UART串行命令；Errors0/Warnings32 |

完整系统/预览为既有装配测试台，本身不包含生产top的新图层；新图层由专项、生产top与真实SDRAM链路独立覆盖。top测试注入已经解码的像素和音频，不声称其验证了SPI读卡。格式错误矩阵复用未改动的M1结论，未把旧运行混入本阶段重测清单。

## TD 构建与时序

最终使用 `mountain_scene_m3_attempt02`，Tang Dynasty v6.2.168116（E:/TD），HighFanoutOptimization、placement strategy5、timing optimization high、drHoldFix on。以布线后的 `demo_phy.area` 和 `final_timing.rpt` 为准：

| 项目 | M3 attempt02 | 相对M1 |
|---|---:|---:|
| LUT | 14520/19600，74.08% | +162 |
| 寄存器 | 8439 | +165 |
| BRAM9k / BRAM32k | 56 / 0 | 0 / 0 |
| DSP | 13 | 0 |
| Setup / Hold | +0.104ns / +0.011ns | 均为正 |
| Setup / Hold TNS | 0 / 0 | 无违例 |
| bit | 664544字节 | 同尺寸不代表内容相同 |

104个实际工程输入与构建快照逐字节相等；候选bit与本构建逐字节相等。仅保存相对M1变化的4个生产输入（top、两个scene文件、demo.al）；未变化输入引用M1。时序审计31条类别/异常汇总与M1相同，约束没有新增无效项/环路；保留既有缺I/O延迟等提示。Hold仅11ps，不能以仿真/时序通过替代板测。

## 告警与历史失败

ModelSim SE-64 10.6e（F:/modelsim/win64）。单位测试无告警；系统保留vopt2685/2718可选IP端口及2121受保护模型常数告警。top的43条告警与v0.16.0旧top相同，另含sys_pll_s3.v:89的load_reg宽度提示（vopt2241/vsim3015）。编译保留glbl重定义（vlog2275）、受保护常数（vlog2121）与旧runner多宏提示（准确vlog13288文本）。按具体类别/位置审核，不屏蔽未知告警；19份编译日志原样保留。

TD综合66条warning类行（M1为68条），物理4条（M1为3条）；诊断内容集合与M1相比无新增，物理阶段仅重复一次既有SDRAM初始位置调整提示。仍有历史UART false-path目标匹配提示、局部时钟路由提示、可选接口悬空等，未声称零告警。完整原文见构建日志；PowerShell UTF-16输出按BOM读取并原样保存。

早期失败保留于diagnostics/output，不作为验收证据：unit01测试台边界采样，unit02/03文件名补空格，unit04复位后旧side输入残留，memory01隐式前向声明。memory02通过后补充首像素阶段/bank断言，memory03因测试台数组声明位置编译失败，调整声明后的memory04通过。最终采用unit05和memory04。TD attempt01产生bit但Setup −0.212ns（SD缓存image_count→bank_map路径）、Hold +0.030ns，不交付；attempt02保持相同功能源码，只提高布局时序优化设置后收敛。

## 上板与回退

固定bit、M2场景包和板测步骤见本目录。用户尚未确认M1/M3板测或M2目视，不能建立board标签。按具体候选实际反馈记录；若板测异常保留local.1并生成递增候选。已验收整机回退仍用v0.16.0，M1 local.1只可作未验收的差异定位入口，不倒填M1板测结果。M4–M6未实施。
