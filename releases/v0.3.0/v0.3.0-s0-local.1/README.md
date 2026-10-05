# v0.3.0-s0-local.1 — HDMI音频升级工程基线

状态：**本地验证及用户上板验收通过。** 日期：2026-10-04。

用户反馈：“S0通过”。板级标签：`v0.3.0-s0-board.1`；固定bitstream沿用本目录文件，不重新构建。原本地标签保留；本次记录验收后推送S0，进入S1。

上传状态：两次GitHub直连推送分别连接重置和443连接失败，未成功上传；本机既有代理端口也未响应。验收与标签已保存在本地；网络恢复后仅推送S0节点，待上板S1不得随当前分支提前推送。

分支：`feature/hdmi-audio-v0.3.0`。本地标签：`v0.3.0-s0-local.1`。这是S0候选，不是最终v0.3.0，也不是板级通过标签。

## 本次修改

- 补回工作区TD工程中缺失的switch_mode_control、seg7_panel、key_press_debounce、mode_key_control四个源文件条目，恢复为原有完整清单。
- 新增[TD构建脚本](../../../diagnostics/run_td_build.ps1)，从demo.al刷新syn_1/phy_1工程，使用明确的绝对源文件路径。
- 建立[音频阶段计划](../../../docs/HDMI音频分阶段修改计划.md)并保存[原交接快照](../../../docs/history/2026-10-04/HDMI音频升级/HANDOFF_before_S0.md)。
- 本次没有修改RTL、引脚、时序约束或测试逻辑，声音仍为原I2S测试音；正弦音和独立EDID尚未实施。

## 固定产物与构建

请下载本目录的[demo.bit](demo.bit)，不要使用会随构建更新的运行目录文件。

- 器件EG4S20BG256，顶层top；TD 6.2.168116。
- 构建开始：2026-10-04 20:08:31；bitstream生成：20:09:36（北京时间）。
- bitstream：629624字节；保存后与本次生成文件逐字节比对一致。
- 在仓库根目录执行：`powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_td_build.ps1 -BuildName audio_s0_local1`。
- [综合日志](build_syn_1.log)、[布局布线及bitgen日志](build_phy_1.log)，包含Generate bitstream completely记录。
- demo.al、syn_1.prj、phy_1.prj及两份settings.cfg为本次构建清单快照，仅供查证；复现使用仓库工程和脚本，快照不作为可移植项目入口。

## 验证结果与限制

| 项目 | 本次结果 |
|---|---|
| TD综合、布局布线、bitgen | 通过 |
| ModelSim拨码/面板专项 | PASS；编译、仿真均0 errors、0 warnings |
| Setup WNS / TNS | −6.699ns / −295.899ns |
| Hold WNS / TNS | +0.003ns / 0ns |
| STA覆盖率 | 95.86% |
| LUT / 寄存器 | 4190 / 3867 |
| BRAM / PLL | 20 / 3 |
| 用户上板 | 2026-10-04用户确认“S0通过” |

[专项仿真日志](mode_panel.log)、[时序状态](demo_phy.ts)、[完整时序报告](demo_pr.timing)、[资源报告](demo_phy.area)。仿真命令：`powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/history/v0.3.0/run_mode_tests.ps1`。

最差Setup、Hold及TNS与v0.2.0记录一致，不能推断所有路径完全相同。时序尚未收敛。完整图片集成、异步双缓冲及模式变化与AUTO到期同拍回归属于S1，本次未宣称通过。

TD仍报告已有的IP端口未连接/未驱动、位宽和参数警告，media_policy与seg7_panel编译顺序编号重复，RAM初始化忽略；布局存在U3/sdram指定位置不可用和1条时钟使用局部布线资源警告。S0仅记录，不改变原硬件行为；ModelSim零警告不代表TD零警告。

## 用户上板检查

1. 下载本目录demo.bit，复位后确认首图正常显示、原测试音正常。
2. SW2/SW1=00时KEY1上一张、KEY2下一张，检查首尾循环和图片颜色/边缘。
3. KEY4切换MAN/AUTO，确认轮播正常、长按不连发，编号位小数点正确。
4. 切换01/10/11，确认模式显示1/2/3、方向键不产生新请求；回00后可以正常翻图。
5. 重新复位，确认恢复MAN且图片、声音正常。

S0已获得用户通过反馈，以上清单保留为验收范围说明；用户未提供逐项测量数据或压力测试时长。后续阶段继续独立验收，不能以S0通过替代。
