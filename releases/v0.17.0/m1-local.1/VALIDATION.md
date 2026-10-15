# M1 local.1 本地验证记录（2026-10-15）

状态：本地通过；板测尚未执行。功能基线 v0.16.0；完整构建 `mountain_scene_m1_attempt01`，固定候选 `v0.17.0-m1-local.1`。本记录不代表正式版发布或用户上板反馈。

## 专项与受影响回归

[validation/logs.json](validation/logs.json) 明确记录本次 144 份通过的仿真日志及必需 PASS 标记；编译记录另存，不计入 144。日志来自最终 RTL，旧输出没有代替本次验证。

| 范围 | 实际执行 | 日志数 |
|---|---|---:|
| 旧 decoder | 640×480、3×2 各 16 项；24/32bpp、行填充、末字节与 file_end 同拍、尾数据、表头错误、截断、上游中止/恢复 | 2 |
| RGBA decoder | 宽度 1–5 各 24/32bpp；可变 T、连续字节、背压稳定、最后像素排空、缺 A、compression=3 拒绝/恢复，共 13 项 | 1 |
| 最近邻 scaler | 10 尺寸及取消；每幅精确比对 307200 个 RGB/T 像素，含黑边 FF | 1 |
| BMP 字节流 | 旧 24bpp 5 尺寸、新专项 6 尺寸（其中 5 个 32bpp）；1:1、放大、缩小、奇数宽、1080×1920/1920×1080、扇区门控及背压 | 2 |
| FAT32 固定解码 | 42 布局/故障 × 24bpp gap=0/2，以及 42 个 32bpp gap=0 | 126 |
| FAT32 边界与缩放支路 | mode=1–5 五项；24/32bpp 各一项缩放支路，均检查输出低字节 | 7 |
| RGBA 真实 SDRAM | 四 bank，160×120/801×601/640×480/317×479；真实双时钟 FIFO、安路控制器及 command/DQ 模型，逐像素核对物理写入和读出 RGB/T、地址与完整帧 | 1 |
| PCM | tb_pcm_production、tb_pcm_preview_rescan 同批编译运行；精确音频比较、碎片循环、重扫/排空、失败重试及缺 BGM 等旧功能 | 2 |
| 缩略图/预览 | 160×120、801×601、1920×1080、1080×1920 混合尺寸；音频、前景失败/重试和缓存选择 | 1 |
| 完整 24bpp 系统 | 四 bank、缓存切换/自动轮播、重扫、超时/重试、SDRAM 刷新、OSD/UART/字幕/时间戳、转场及 PCM | 1 |

RGBA 物理系统完成 31 帧；PCM 两专项分别精确比较 9279/9280 个样本。预览系统完成 293 帧（其中 200 帧预览）、10 次提交及提示音、180720 次刷新；238405 个 PCM 样本逐项相等，4 个音频会话，无欠载/溢出。预览采用 MIXED_TEST=1，尺寸配置不同于基线固定图回归，不把帧数/耗时差异写成同配置性能结论。

完整系统完成 591 帧、14 次启动、10 次缓存完成、22 次提交/提示音、15 次缓存命中和 365203 次刷新；481827 个 PCM 样本精确比较，5 个会话，无欠载/溢出。2 次 AUTO 揭示、15 次手动淡变通过；OSD/时间戳检查 598 个帧边界、251159248 个像素/消隐输出，UART 四个串行命令阶段均在帧边界生效。

解码/缩放/FAT32 使用 `F:/quartus18.1/modelsim_ase/win32aloem` 的 ModelSim Intel FPGA Starter 10.5b 通过；长回归使用 `F:/modelsim/win64` 的 ModelSim SE-64 10.6e（PCM03、memory03、preview03、system02）。所有仿真 Errors=0，未知告警拒绝。受保护模型的 `vlog-2121` 未定宽常数、IP 可选端口 `vsim-3017/3722` 及 Starter 容量提示在原始记录中保留；历史 vopt 告警类别同旧脚本允许。完整系统编译另保留一条 `vlog-13288`（`Multiple macros defined in +define+ command line switch.`）：旧 runner 在同一个 +define+ 参数内定义多个宏，SE 给出参数格式提示，全部指定宏仍生效；打包器仅接受该准确文本。23 份编译日志及 TD 构建日志保留原格式；PowerShell 重定向的 UTF-16 日志按 BOM 解码检查，未修改原日志。不能将含已知告警的记录描述为“零告警”。

## TD 物理实现与输入对应

Tang Dynasty v6.2.168116，根目录 `E:/TD`，器件 EG4S20BG256。在独立诊断快照中完成综合、布局、布线和 bitgen；未覆盖用户 TD_project 或 best_result。配置为 HighFanoutOptimization、placement strategy 5、drHoldFix=on；约束、引脚、PLL/时钟不变。证据见 [reports](reports)。

| 指标 | v0.16.0（历史） | 本次最终报告 |
|---|---:|---:|
| LUT | 14190 | 14358（+168，73.26%） |
| 寄存器 | 8250 | 8274（+24） |
| BRAM9k | 54 | 56（+2，87.50%） |
| BRAM32k / DSP | 0 / 13 | 0 / 13 |
| Setup / Hold | +0.144 / +0.003ns | +0.111 / +0.003ns |
| Setup / Hold TNS | 0 / 0 | 0 / 0 |
| bit 字节数 | 662216 | 664544 |

最终面积以 demo_phy.area 为准；布线前日志的 14346 LUT 不是最终值。STA coverage 99.97%，慢/快角均检查。审计检查类别及路径异常汇总与 v0.16.0 s2-local.1 一致：无新增无效约束、无组合环、PLL 匹配；保留 3 类 dangling 节点、9 个输入/16 个输出未设延迟和 SD 输入延迟提示。没有放宽约束，也未声称解决基线审计提示。Hold 仅 3ps，需要实板确认。

全部 102 个实际工程输入（含 demo.al、RTL/IP、初始化和约束）与隔离构建快照逐字节一致。候选 bit、5 个相对 v0.16.0 变化的生产文件及复制证据均逐字节检查；未修改 user_source 输入引用 v0.16.0，demo.al 引用 plan.1 用户快照，见 MANIFEST.md。未使用文件哈希。

## 诊断素材、失败与验证边界

make_test_bmps.py 生成 640×480、160×120、801×601、317×479 四张 compression=0、40 字节 DIB、BGRA 自下而上的 BMP 和最近邻 RGB expected PNG，写后反向读取逐字节核对 RGB/T。T 为坐标图样，覆盖 0–255，用于 M1 诊断；没有实现 M2 场景/灾害参考工具。

早期 decoder01 暴露末字节与 file_end 同拍时旧计数问题；rgba01 暴露连续表头字节时校验寄存尚未完成导致首负载丢失，修复后使用 decoder03/rgba02 和最终 RTL 的回归。rgba_memory01 的测试台曾使用错误的 T 延迟，改为 32 位 video_delay 后使用 memory03。pcm01、preview01 和 memory01 属于主动停止的旧源码/旧测试台运行；最终 RTL 的 Starter pcm02、preview02、memory02、system01 因工具性能限速而主动停止，改用 SE 完成。上述输出保留在 diagnostics/output，未纳入本候选；scaler01 也未用作最终证据。不存在未解释的失败日志被作为通过证据。

SD 卡为扇区级服务模型；真实 SPI、电气接口、实际卡与 HDMI/板上行为仍待 [板测](BOARD_VALIDATION.md)。T 的仿真正确不等于 M3 灾害显示已实现。M1 不执行 M6 的 40 分钟验收；无新增板测结论、board 标签或远程推送。

## 复现入口

```powershell
& diagnostics/mountain_scene/run_m1.ps1 -Prefix mountain_m1_recheck
& diagnostics/mountain_scene/build_m1.ps1 -BuildName mountain_scene_m1_attempt02
& diagnostics/mountain_scene/run_legacy.ps1 -Suite audit -RunName mountain_scene_m1_attempt02
py -I diagnostics/mountain_scene/make_test_bmps.py diagnostics/output/mountain_m1_samples02
```

运行需选择未使用的输出名。本次打包采用 diagnostics/mountain_scene/m1_logs.json，指向本次实际目录；重测使用其他 Prefix 后须提供对应的新日志清单，不用旧日志代替新验证。packager 在仿真、时序、编译、审计和逐字节输入检查通过后才建立新候选目录，不覆盖已有候选。
