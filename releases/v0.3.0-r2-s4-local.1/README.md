# R2 S4 视频坐标对齐上板候选

日期：2026-10-04。分支`feature/hdmi-audio-v0.3.0`，本地标签`v0.3.0-r2-s4-local.1`。**仿真及TD构建通过，待用户上板；全局时序未收敛。** 不推送，不进入S5。

## 修改

color_bar生成覆盖整行的坐标，有效首像素为0，末像素639，水平消隐继续640..799，垂直消隐行仍循环。经video_timing_data两级及video_delay的21级同步延迟，顶层video_x[9:0]与HS/VS/DE/RGB对齐。补齐video_timing_data第二级HS/VS/DE复位，避免复位期间不确定值。旧HDMI、音频、控制、数码管、TD清单与时序约束沿用原链路。

旧HDMI核尚不消费video_x；无消费者的坐标逻辑可被综合裁剪。本阶段坐标功能证据来自RTL仿真，板级用于确认现有显示链路无回退；实际新核心坐标路径的资源/时序需在后续接入后验证，不额外增加调试核强行保留。

## 仿真

ModelSim SE-64 10.6e，2026-10-04 22:56—22:57（Asia/Shanghai），编译和仿真均0 errors、0 warnings。

- 视频专项检查两个完整帧，复位后再检查一帧；每帧800×525周期，640×480有效像素及45条消隐行；独立VS锚定参考检查每拍坐标、HS/VS/DE，逐像素检查带行列标记的RGB，包括首末像素和消隐。
- 使用Git中的S1原始模块，仅重命名后并行仿真；流水线填充后视频、RGB、FIFO读使能及帧读请求逐拍相同。
- 六个控制测试及面板测试通过，包括图片请求、三键、AUTO、显示和保留的旧手势兼容单测。本阶段未修改异步帧缓存，既有异步缓冲证据沿用S1。
- FIFO读口采用同步行为模型，不代表物理SDRAM或完整HDMI协议验证。

复现：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_video_alignment.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_control_tests.ps1 -Prefix audio_r2_s4
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_mode_tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_td_build.ps1 -BuildName audio_r2_s4_local1
```

[视频编译](video_compile.log) · [视频测试](video_test.log) · [控制完整输出](control_compile_and_run.log) · [面板完整输出](panel_compile_and_run.log)

## 构建与限制

TD 6.2.168116，EG4S20BG256，top。固定[demo.bit](demo.bit)，629624字节，生成于2026-10-04 22:58:14（Asia/Shanghai），归档与生成文件逐字节一致。

| 指标 | S1 | S4 |
|---|---:|---:|
| 全局Setup WNS / TNS（ns） | −6.699 / −296.363 | −6.699 / −293.242 |
| 全局Hold WNS / TNS（ns） | +0.003 / 0 | +0.003 / 0 |
| 视频域同域Setup WNS（ns） | +28.695 | +27.772 |
| 控制域Setup WNS（ns） | −0.044 | +0.203 |
| STA覆盖率 | 95.87% | 95.85% |
| LUT / 寄存器 | 4229 / 3866 | 4157 / 3871 |
| BRAM / PLL | 20 / 3 | 20 / 3 |

[路径组比较](timing_comparison.md) · [完整时序](demo_pr.timing) · [资源](demo_phy.area) · [综合](build_syn_1.log) · [布局布线/bitgen](build_phy_1.log)。负裕量仍在SDRAM接口路径，没有新增负裕量路径组；不能把构建成功写成时序通过。TD仍有既有IP端口/位宽/初始化、SDRAM位置和局部时钟布线警告，未放宽约束。资源变化包含复位修改及综合优化，不能作为未来坐标消费者的资源估算。

## 上板检查

1. 下载本目录demo.bit，复位后确认首图、颜色和四边完整，无横向偏移、缺列或闪烁，原测试音正常。
2. 图片模式KEY1上一张、KEY2下一张，检查四图和首尾循环；图片编号与画面一致。
3. KEY4切换MAN/AUTO，确认自动翻图；四种拨码模式及数码管正常，非图片模式方向键不翻图。
4. 再复位确认恢复首图及MAN状态。反馈“S4通过”或具体现象。

如有回退，恢复`../v0.3.0-s1-local.1/demo.bit`并停在S4排查。按阶段计划，用户确认S4后才建立板级节点、推送已验收提交及S2前置节点，再开始S5。
