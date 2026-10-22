# v0.25 S1 LUT 减量记录

计划见 [A项目功能移植v0.25分阶段计划.md](../../docs/A项目功能移植v0.25分阶段计划.md) S1。基线为 v0.24.0（`releases/v0.24.0/s3-local.2`，构建 `lut24_s3fix_td01`，Seed47）：16926 LUT，10081 寄存器，53/2 BRAM，12 DSP，Setup +0.130 ns，Hold +0.030 ns。

所有构建都用 `diagnostics/bottom_waveform/run_td.ps1`，选项与 v0.24 相同，经 `diagnostics/lut24/invoke_legacy.ps1` 调用。

| 批次 | 构建 | Seed | LUT | 寄存器 | BRAM9k/32k | DSP | Setup | Hold | 结论 |
|---|---|---|---:|---:|---|---:|---:|---:|---|
| 基线 v0.24.0 | lut24_s3fix_td01 | 47 | 16926 | 10081 | 53/2 | 12 | +0.130 | +0.030 | — |
| 1 按键共享 1 ms tick | lut25_keys_td01 | 47 | 16761（−165） | 10010（−71） | 53/2 | 12 | +0.110 | +0.035 | 接受 |
| 2 hazard 只算一次斑点 hash | lut25_hazard_td01 | 47 | 16841（+80） | 10011 | 53/2 | 12 | +0.173 | +0.003 | 拒绝，已撤回 |
| 3 PCM `loop_count` 1 bit | — | — | — | — | — | — | — | — | 不做：v0.24 网表中已被综合剪掉 |
| 4 寄存 `error_flag` | — | — | — | — | — | — | — | — | 不做：本项目无对应长路径 |

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

## 批次 2：hazard 噪声 hash 共享（拒绝）

**移植内容**：A 项目 7bdf910 的三项改动，应用到 `scene/hazard_layer_v3.v`。改前的本项目文件与 A 改前版本只差 `hash8` 写法：v0.24 S2 已把 `hash8` 写成按位常数相加，避免占 DSP。
1. 四个噪声角点共用 `a*73+b*151`（`hash8s`），乘法改为逐位常数相加，保持不进 DSP；
2. 扬尘/洪水斑点先选输入，再只算一次 `hash8`；
3. `nsx`/`nsy` 的桶形移位改为固定移位。

**仿真**：全部改动与冻结的 v0.24 模块逐拍逐位一致（`lut25_hazard_equiv1`：2 个种子，2690 万拍，C1 寄存项也比对，3 个变异体全部测出）。

**单独综合**（`run_standalone_synthesis.ps1`，gate area）：

| 版本 | LUT | DSP |
|---|---:|---:|
| v0.24 原版 | 1540 | 4 |
| 三项全做 | 1627 | 4 |
| 只做 2（斑点 hash 只算一次） | 1526 | 4 |
| 只做 3（固定移位） | 1605 | 4 |
| 2 + 3 | 1572 | 4 |

固定移位和角点共享都会增加 LUT。原因可能是 TD 对原来的移位和乘法已经优化得很好，改写后的选择逻辑反而更大。所以整机只试了第 2 项：
- 仿真：`lut25_hazard_equiv3`，2 个种子，另外 65536 组 `hash8` 输入逐值一致，2 个变异体测出。
- 整机 `lut25_hazard_td01`：16841 LUT，比批次 1 多 80；图层本身 1649 → 1667 LE；Hold 余量 +0.035 → +0.003 ns。

结论：无收益，Hold 余量变小，撤回。`user_source` 与批次 1 一致。

## 批次 3：PCM 循环计数改 1 bit（不做）

- 本项目 `fat32_pcm_stream` 的 `loop_count` 输出在 `sd_card_bmp.v` 中悬空（`.loop_count()`）。
- v0.24 物理网表 `lut24_s3fix_td01/timing_audit/physical_audit.v` 里没有任何 `loop_count` 寄存器，只有一个借了它名字的回放回绕比较网络（源码第 111 行）。
- 所以本项目已经不在为它付 LUT。A 的收益来自它拿这个计数器做旁白完成判断。
- S3 需要的“已播完”信号另行设计，可复用宣传模式的 `done`/`done_id` 机制。

## 批次 4：寄存的 `error_flag`（不做）

- A 改这一项，是为了截断 error_code → cache_failed 的 10 级 LUT 时序失败路径。
- 本项目 `audio_stream_error` 只有三处使用，都只判断是否非零：`audio_available_q`（已经先寄存）、`scenario_audio_control` 的 FIRST 态、`publicity_voice_control` 的状态。没有接到 cache 控制。
- 当前最差 Setup 路径是 `scan_state` → `u_osd_status_cdc`，不在音频路径上。
- 预计收益只有几个 LUT，在构建噪声以内，不做。

## S1 小结

- 交付批次 1：16926 → 16761 LUT（−165），已上板通过（`ac5eff4`）。
- A 的另外三项在本项目都没有收益：本项目已有等价优化，或者 TD 映射结果不同。
- 离 S5 的 17250 LUT 门槛还有约 490 LUT 余量。

## S3：旁白播完才 AUTO 换阶段（与 S1 批次无关的 RTL 改动）

逻辑改动很小（`pass_done` 一位标志、`narration_hold`、`scenario_fsm` 的 AUTO 条件）；详情见 `releases/v0.25.0/s3-local.1/README.md`。构建基线为批次 1（16761 LUT）。

| 构建 | Seed | LUT | 寄存器 | Setup | Hold | 结论 |
|---|---:|---:|---:|---:|---:|---|
| lut25_narration_td01 | 47 | 16774 | 10000 | −0.386 | +0.011 | 不交付：最差路径在 FAT32 扫描器内部（`max_cluster` → `directory_lo_le`），与本改动无关 |
| lut25_narration_td_s43 | 43 | 16793 | 10023 | +0.108 | +0.019 | 候选 s3-local.1 |
| lut25_narration_td_s53 | 53 | 16750 | 10012 | +0.156 | +0.011 | 候选 s3-local.2 |

LUT 随布局波动约 ±40（与 v0.24 S4 记录的 ±100–150 同量级），本改动本身预计只有几个 LUT，批次 1 之后仍留约 450 LUT 余量给 S5。

复位审计：v0.24 出过问题的 `sd_card_cmd_m0/rst` 和 `bmp_read_m0/rst` 在两个候选里仍是寄存器驱动（`.q`），共享头校验的复位与 v0.24 一样由 LUT 驱动（该网络在 v0.24 已存在并通过板测）。其余网络的差异来自 TD 插入的保持缓冲和 RAM 复位引脚，随布局变化。

## S5：场景进度条、告警色块、图例

`scene_text_overlay` 加了 `t_now` 和 `BAR_ENABLE`/`LEGEND_ENABLE` 两个参数。基线为 S3 候选（16750–16793 LUT）。

| 构建 | Seed | LUT | 寄存器 | Setup | Hold | 结论 |
|---|---:|---:|---:|---:|---:|---|
| lut25_hud_td_s47 | 47 | 16962 | 10033 | +0.055 | +0.019 | 候选 s5-local.1 |
| lut25_hud_td_s43 | 43 | 16896 | 10033 | −0.107 | — | 不交付：最差路径 `terminal_frame` → `u_cache_control/foreground_image`（SD 时钟域） |
| lut25_hud_td_s53 | 53 | 16889 | 10041 | −0.517 | — | 不交付：最差路径缩放器状态 → 解码器 `payload_bytes`（SD 时钟域） |

- 叠加层本身 261 → 455 LUT（+194），整机比 S3 候选多约 200，在计划上限 17250 之内（余量约 290）。
- 三个种子的最差路径都在 SD 时钟域，没有一条在新增的视频时钟域逻辑里；只有 Seed 47 通过，Setup 余量 +0.055 ns，偏小，所以只交付这一个 bit。
- 没有再关图例或进度条：LUT 在上限以内，时序问题不在这部分。
- 复位审计：`sd_card_cmd_m0/rst`、`bmp_read_m0/rst` 仍是寄存器驱动，共享头校验的复位与 v0.24 一样由 LUT 驱动。

验证见 `releases/v0.25.0/s5-local.1/README.md`：独立模型逐像素比对（14 段新卡、10 段 S2 卡、旧卡）、关闭新功能时与冻结的 S3 叠加层逐拍一致（438 万拍）、11 个变异体全部测出、SD 引脚级启动不变。

### S5 第二版：HUD 移到右上角，关闭累计时间（`TIMESTAMP_ENABLE=0`）

| 构建 | Seed | LUT | 寄存器 | Setup | Hold | 结论 |
|---|---:|---:|---:|---:|---:|---|
| lut25_hud2_td_s43 | 43 | 16845 | 10025 | +0.151 | +0.011 | 候选 s5-local.2 |
| lut25_hud2_td_s47 | 47 | 16860 | 10014 | +0.160 | +0.003 | 候选 s5-local.3 |
| lut25_hud2_td_s53 | 53 | 16867 | 10029 | +0.105 | +0.003 | 时序通过，不单独打包（Hold 余量同样只有 +0.003） |

- 比第一版（16962）少约 100 LUT；三个种子全部时序通过，最差路径都在 SD 时钟域的菜单后端、读卡器和写缓冲，不在叠加层。
- 累计时间在所有模式下都有（宣讲、相册、场景），所以是整体关闭，没有只在场景里隐藏。
- 关键复位驱动（`sd_card_cmd_m0/rst`、`bmp_read_m0/rst` 为寄存器驱动，共享头校验为 LUT 驱动）两个候选都与 v0.24 相同。

### S5 第三版：OSD 照参考项目版式重做，隐藏页码标签

右上角半暗面板（告警色块、标题、进度条）、白字图例和字幕压在半暗的底条上；`publicity_status_overlay` 的 `SHOW_PAGE=0`。叠加层面积比上一版大。

| 构建 | Seed | LUT | Setup | Hold | 结论 |
|---|---:|---:|---:|---:|---|
| lut25_hud3_td_s29 | 29 | 16979 | +0.131 | +0.022 | 候选 s5-local.4 |
| lut25_hud3_td_s7 | 7 | 17009 | +0.057 | +0.011 | 候选 s5-local.5 |
| lut25_hud3_td_s13 | 13 | 17054 | +0.046 | +0.019 | 时序通过，不单独打包 |
| lut25_hud3_td_s43 | 43 | 17005 | −0.017 | — | 不交付：最差路径 `parser_rst_q` → `app_status_cdc/held` |
| lut25_hud3_td_s53 | 53 | 16988 | −0.115 | — | 不交付：最差路径 `busy` → `frame_events/frame_seen` |
| lut25_hud3_td_s59 | 59 | 17020 | −0.347 | — | 不交付 |
| lut25_hud3_td_s61 | 61 | 17014 | −0.185 | — | 不交付 |
| lut25_hud3_td_s47 | 47 | （16980） | — | — | 不交付：布线阶段 TD 报“增量布线失败”（PHY-8023/RUN-8102），没有出 bit |

- 比上一版（16845）多约 130–200 LUT，仍在计划上限 17250 以内（余量约 240–270）。
- 8 个种子里 3 个通过；失败的最差路径都在 SD 时钟域，不在新增的显示部分。
- 关键复位驱动（`sd_card_cmd_m0/rst`、`bmp_read_m0/rst` 为寄存器驱动，共享头校验为 LUT 驱动）两个候选都与 v0.24 相同。
- 22 个变异体全部测出；与旧叠加层的逐拍对比已撤掉（版式是有意改的）。

### S5 第四版：与参考项目逐像素一致

对照 A 的 `tools/scenes/landslide_village/out/osd/*.png` 逐像素比较后修了三处：字幕用整段旁白（段长 5→8 位）、预警语改为底部滚动（去掉中央 2 倍字的缩放逻辑）、场景和宣讲模式隐藏左上角状态行。去掉缩放后 LUT 比第三版少约 230。

| 构建 | Seed | LUT | Setup | Hold | 结论 |
|---|---:|---:|---:|---:|---|
| lut25_hud6_td_s13 | 13 | 16765 | +0.168 | +0.011 | 候选 s5-local.6 |
| lut25_hud6_td_s29 | 29 | 16754 | +0.056 | +0.035 | 候选 s5-local.7 |
| lut25_hud6_td_s3 | 3 | 16740 | +0.107 | +0.004 | 时序通过，不单独打包 |
| lut25_hud6_td_s7 | 7 | 16835 | +0.050 | +0.019 | 时序通过，不单独打包 |
| lut25_hud6_td_s17 | 17 | 16790 | −0.120 | — | 不交付 |

另有一轮（`lut25_hud5_*`）在红框颜色改成 `ff2020` 之前启动，已停掉作废。
