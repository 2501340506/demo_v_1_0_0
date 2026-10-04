# 当前交接记录

更新日期：2026-10-04

## 模式选择阶段4已完成

- 当前任务：按批准的四阶段方案增加拨码模式、新按键映射和模式显示。每阶段上板确认后再继续；加载请求挂起机制保持远程基线行为。
- 已完成：新增 `switch_mode_control`，50MHz域同步SW2/SW1并整体稳定20ms后更新；模式显示在 `seg_data_4`；顶层及约束登记SW1=C8、SW2=C7、KEY4=C1；TD工程登记新模块。
- 已完成验证：阶段1板级验收通过；阶段2 `tb_mode_key_control`及新播放控制器RTL编译通过，0 errors、0 warnings。
- 范围：阶段2已将KEY1/KEY2/KEY4接入新控制器：00模式方向翻图，其他模式屏蔽新方向事件，KEY4单击切换AUTO。旧长短按和组合入口已移除；播放控制器的挂起机制、SDRAM及HDMI音视频未改。
- TD结果：综合、布局布线和bitgen完成；`TD_project/demo_Runs/phy_1/demo.bit`为本阶段产物，629624字节。Setup WNS −6.699ns、TNS −294.291ns；Hold WNS +0.003ns、TNS 0ns。LUT 4349、寄存器3937、BRAM 20、PLL 3。
- 阶段2板级验收已通过。阶段3增加模式变化重置AUTO计时，保留AUTO状态和已有挂起请求；`tb_media_player_control`通过，0 errors、0 warnings。
- TD结果：阶段3产物正在生成/复用当前工程运行；上板前需确认 `phy_1/demo.bit` 更新时间和bitgen日志。阶段3等待用户上板验收。
- 阶段3板级验收已通过；阶段4完成最终回归、文档和交接。用户已确认四模式AUTO、模式切换重新计时、忙时挂起和切回MAN行为正常。
- 最终产物：`TD_project/demo_Runs/phy_1/demo.bit`，629624字节；bitgen成功。最终验收记录见 `diagnostics/MODE_FINAL_ACCEPTANCE.md`。
- 构建证据：syn_1和phy_1目录的 `build_mode_stage1.log`；最终 `demo_phy.ts`、`demo_phy.area`。保留既有时序未收敛、SDRAM位置调整和局部时钟布线警告，另有原工程media_policy/seg7_panel编译顺序重复提示。
- 下一步：当前方案范围已完成。若继续开发，另行规划B/C图像处理、OSD或缩放；不得默认改变已验收的加载挂起机制。
- 踩坑：TD命令行读取运行目录的 `demo.prj`，新增源文件必须同步运行文件清单；刷新脚本应使用明确的仓库绝对路径，不能把运行目录当仓库根。本次首次刷新路径错误已纠正后重新构建。
- 后续需求仅记录：B初值0、范围−128..127；C初值128、范围0..256、至少9位。OSD、B/C处理和缩放不在本轮实现。

以下为基线历史交接记录。

## 当前状态

项目当前固定基线为 **v0.1.8**。四阶段已完成仿真、TD 构建和用户板级功能验收；后续 RTL、仿真、TD 与时序优化工作暂停。

- 分支：`demo010-0_1_1`
- 标签：`v0.1.8`，不改写
- `main`：未合并
- 上板文件：`releases/v0.1.8/demo.bit`
- 归档入口：[docs/ARCHIVE_INDEX.md](../../ARCHIVE_INDEX.md)

## 证据边界

控制回归和缓冲交接行为模型均已通过。`baseline_*.log` 仅用于旧控制器问题对照，不是当前版本失败结果。板级结论来自用户验收；Setup WNS -6.699 ns、Hold WNS +0.003 ns，时序尚未收敛。行为模型不覆盖厂商 IP 内部时序、真实亚稳态和完整电气行为。

## 当前工作区

以下文件按用户要求保留原状，不纳入文档整理：

- `TD_project/demo.al`
- `TD_project/demo_Runs/best_result/demo.bit`
- `TD_project/demo_Runs/best_result/demo_phy.ts`

本次仅更新交接文档，未运行 RTL/ModelSim/TD，未移动发布目录或改写标签。

## 后续入口

恢复工作时，以 `releases/v0.1.8/`、`diagnostics/README.md` 和 `docs/ARCHIVE_INDEX.md` 为入口，另行提出修改计划。上一版交接记录见 [HANDOFF_2026-10-04.md](HANDOFF_2026-10-04.md)，本次归档副本见 [HANDOFF_2026-10-04_02.md](HANDOFF_2026-10-04_02.md)。

## 2026-10-04 — seg7_panel 面板模块化

- 新增 `user_source/hdl_source/SD/seg7_panel.v`，统一数码管译码、组合提示、轮播小数点和 6 位扫描显示策略。
- 顶层 `top_tf_hdmi_audio.v` 改为实例化 `seg7_panel`；`seg_scan.v` 增加可选 `CLK_FREQ`/`SCAN_FREQ` 参数，默认行为保持不变。
- TD 工程已登记新 HDL 文件；课程文档第 2.8 节已改为基于当前 v0.1.8 的真实 6 位面板说明。
- 尚未完成板级重构后的重新综合和上板验收；下一步运行 Verilog 编译/控制回归，再执行 TD 构建。

## 后续验收约束

- 本机已安装 ModelSim 和 TD，可继续执行 HDL 仿真、综合、布局布线和 bitstream 生成。
- `seg7_panel` 重构后的功能必须先经过用户上板验收，重点确认位选顺序、段码极性、图片编号、组合提示和自动轮播小数点。
- 在用户明确确认上板通过前，不上传 GitHub、不发布新版本。

## 2026-10-04 — ModelSim/TD 验证结果

- ModelSim `diagnostics/history/v0.3.0/run_control_tests.ps1`：6 个控制顶层全部通过，编译 0 errors、0 warnings；图片请求、组合键、播放控制、显示策略和手势回归均通过。
- ModelSim 单独编译 `seg_decoder.v`、`seg_scan.v`、`seg7_panel.v`：0 errors、0 warnings。
- TD 6.2 综合、布局布线和 bitgen 完成，产物为 `TD_project/demo_Runs/phy_1/demo.bit`。
- 本次最终时序：Setup WNS -6.699 ns，Hold WNS +0.011 ns；保留既有时序未收敛情况。用户已完成板级验收并确认通过；v0.1.9 已归档并上传 GitHub。

