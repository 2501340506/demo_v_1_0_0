# v0.25 S1 LUT 减量记录

计划见 [A项目功能移植v0.25分阶段计划.md](../../docs/A项目功能移植v0.25分阶段计划.md) S1。基线为 v0.24.0（`releases/v0.24.0/s3-local.2`，构建 `lut24_s3fix_td01`，Seed47）：16926 LUT，10081 寄存器，53/2 BRAM，12 DSP，Setup +0.130 ns，Hold +0.030 ns。

所有构建都用 `diagnostics/bottom_waveform/run_td.ps1`，选项与 v0.24 相同，经 `diagnostics/lut24/invoke_legacy.ps1` 调用。

| 批次 | 构建 | Seed | LUT | 寄存器 | BRAM9k/32k | DSP | Setup | Hold | 结论 |
|---|---|---|---:|---:|---|---:|---:|---:|---|
| 基线 v0.24.0 | lut24_s3fix_td01 | 47 | 16926 | 10081 | 53/2 | 12 | +0.130 | +0.030 | — |
| 1 按键共享 1 ms tick | lut25_keys_td01 | 47 | 16761（−165） | 10010（−71） | 53/2 | 12 | +0.110 | +0.035 | 接受 |

## 批次 1：按键共享 1 ms tick

**改动**（参照 A 项目 v0.18 的 2da0507）：

- `user_source/hdl_source/SD/mode_key_control.v` 中所有按键计数改为按同一个 1 ms 预分频（`ms_tick`）计数：
  - 三个去抖改用新模块 `key_ms_debounce`；
  - KEY2 重扫长按 2 s；
  - 宣传模式与情景模式的 KEY4/KEY1 长按 1 s；
  - `adjust_key_gestures` 的 100 ms 窗口与 1 s KEY4 长按。
- 原来的计数从 1 起、到 N−1 止，比 N 拍少两拍。改用 tick 计数时用 `TICK_ADJ` 把上限抬高，使每段时长与原来相差不超过 1 ms。
- `CLK_FREQ_HZ=1000` 时每拍一个 tick 且 `TICK_ADJ=0`，计数与原来完全相同。
- 按键手势、复位接法、端口都不变。
- 菜单控制（`disaster_menu_control`）自带的三个 `key_press_debounce` 不在本批，仍用原模块。

**面积**（phy area）：

| 部分 | 基线 | 本批 |
|---|---:|---:|
| `mode_key_control` | 276 LE / 182 寄存器 | 222 LE / 129 寄存器 |
| 其中 `adjust_keys` | 127 LE | 75 LE |
| 其中三个去抖 | — | 共 26 LE |

整机 −165 LUT，比模块本身的减少更多，来自布局打包的变化。

**时序**：最差 Setup 路径是 `scan_state_reg` → `u_osd_status_cdc`，与本批无关。

**验证**：`diagnostics/lut_opt25/run_s1_keys.ps1`（输出 `diagnostics/output/lut25_keys2`）。
- 冻结的 v0.24.0 模块 `mode_key_control_v024.v` 与新模块逐拍对比：
  - 一拍一毫秒，宣传/情景/旧版三种配置各 200 个随机手势，全部输出逐拍一致；
  - 20 拍一毫秒，三种配置 × 种子 25/7/3 各 300 个手势（含抖动、模式/场景/忙变化、使能撤销），每个输出边沿都在 1 个 tick 内出现、顺序一致；
  - 4 个变异体全部被测出：去掉 `TICK_ADJ`、去抖少一个 tick、调节 KEY4 长按改 300 ms、长按 tick 数改 300。
- 定向测试（输出 `diagnostics/output/lut25_keys_*`）：
  - 通过：`media_adjust/run_unit.ps1`（6 项）、`tb_scene_keys`、`tb_m3_keys`、`publicity_mode/run_m3.ps1` 的 keys/identity/streamer 项。
  - `tb_scenario` 打印 PASS，但因 `scenario_fsm` 端口未连接有警告，脚本仍判失败。
- 已过时的测试台（v0.24 原版同样失败，与本批无关）：
  - `sd_recovery/tb_rescan_key.sv`、`image_scaling/tb_preview_keys.sv`：`.*` 连线缺少 scene/application 端口；
  - `publicity_mode/tb_m3_scan_bounds.sv`：连着 v0.24 S2 已删除的扫描器 `resource*_cluster` 端口；
  - `disaster_selector/run_mode_key_equivalence.ps1`：按 2000 Hz/100 MHz 逐拍比对计数器，已由本批 tick 对比测试取代。
- 未重跑：网表复位审计和 SD 引脚启动仿真。本批没有改任何复位，也没有改 SD 路径。
- 上板：通过（2026-10-22，用户确认 lut25_keys_td01 各按键功能正常）。
