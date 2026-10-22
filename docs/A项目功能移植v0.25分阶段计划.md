# A 项目功能移植 v0.25.0 分阶段计划

## 范围与基线

- **参考项目 A**：`anlogic_program/demo_v_0_0`，最终为 v0.19.0：14489 LUT，DSP 24，BRAM9k 30，BRAM32k 2。
- **A 与本项目的关系**：两者都从 `1818adc`（v0.16.0，2026-10-14）分叉，之后各自实现了山区避险课堂 M1–M6。双方的 SD 读卡器、`fat32_volume_scanner`、`top_tf_hdmi_audio`、`scenario_fsm`、`hazard_layer` 都已独立重写，**不做 git 合并**，按功能把 A 的实现改写到本项目的现有架构上。
- **本项目基线**：v0.24.0（`dd05d41`）。16926 / 19600 LUT（86.36%），10081 寄存器，53/64 BRAM9k，2/16 BRAM32k，12/29 DSP，Setup +0.130 ns，Hold +0.030 ns。
- **目标**：
  - 补齐下表 A 有而本项目缺的功能。
  - 最终物理 LUT ≤17250（约 88%），Setup 和 Hold 为正。
  - 宣传模式、SW3 菜单、开机加速和旧卡兼容的行为不变。
- **执行顺序**：用户确认全部要做，场景 OSD 放最后，即 S1 → S2 → S3 → S4 → S5 → S6。

## 差异核对

| A 的功能 | 本项目现状 | 处理 |
|---|---|---|
| 四张灾害卡的真人旁白：`tools/scene_audio.py`，36 个 MiniMax 录音 wav | `mountain_port` 只有 BMP；s2-card.1 的 SND 只有提示音和报警 | S2 移植 |
| `scene.yaml` 的 village、warning 和各阶段 title/legend/narration | `tools/mountain_port/scenes/*/scene.yaml` 每张卡少 22–24 行 | S2 合并 |
| `make_scene_pack.py` 的 `--audio`/`--text` | `mountain_port/make_scene_pack.py` 删掉了这两项（约 18 行差异） | S2 恢复 |
| 共享 1 ms tick：`mode_key_control` 486→209 LUT（2da0507） | 每个按键各有计数器 | S1 |
| hazard 噪声 `hash8s` 共享和固定移位，−91 LUT −2 DSP（7bdf910） | `hazard_layer_v3.v` 是这次提交之前的版本 | S1（有风险，见 S1-2） |
| `fat32_pcm_stream` 的 `LOOP_BITS=1`（dd7ab26） | `loop_count` 32 位 | S1 |
| 寄存的 `error_flag`（006e28a） | 无 | S1 |
| 旁白播完才 AUTO 换阶段（`narration_done`） | `scenario_fsm.v` 只看 `terminal_frame` | S3 |
| 标注工具 `annotate_scene.py` 和 `build_annotate_exe.py` | 无 | S4 |
| `docs/场景标注工具使用说明.md`、`docs/滑坡卡制作教程.md` 及 20 张图 | 无 | S4 |
| `scene_osd.v` 的 t 进度条、E0–E7 图例色块、告警色块 | `scene_text_overlay.v` 只有标题、字幕、村名和预警 | S5 |

### 不移植

| A 的内容 | 原因 |
|---|---|
| `hazard_test_source.v` | 本项目已有 `scene_demo_timing.v`，并已被 `scenario_fsm` 取代 |
| `scene_kind_cdc.v` | 本项目用 BMP 头类型加 `scenario_frame` 和 `disaster_layer` |
| 像素域 `scenario_fsm` | 本项目的 SD 域 FSM 功能更全，包括菜单和宣传模式 |
| v0.19 去音频环 | 环已改成宣传模式的底部 PCM 波形，仍在使用 |
| UART 裁剪、32bpp alpha 链路 | 本项目已有 |

## 阶段

### S1 LUT 减量（先腾出空间，预计 −300 ~ −500）

每项单独做一批，先跑完整 TD，再记入 `diagnostics/lut_opt25/LUT_RECORD.md`。不省 LUT 或时序变差的批次判为拒绝。旧版冻结为 `diagnostics/lut_opt25/*_v024.v`，用逐拍对比测试台验证。

1. **按键共享 1 ms tick**
   - 把 `SD/mode_key_control.v` 中 `key_press_debounce` 和 `adjust_key_gestures` 的计数器改为按一个共享 ms tick 计数。参照 A 的 `ms_tick`、`key_ms_debounce`、`TICK_ADJ`。
   - 只换计时实现，现有手势不变：KEY1 长按调速度，KEY2 长按 2 s 重扫，KEY4 长按切换应用，SW3 菜单。
   - 验证：移植 A 的 `tb_keys_tick`，旧版与新版逐拍对比。
2. **hazard 噪声 hash 共享**
   - 把 A 7bdf910 的四角共享 `a*73+b*151`、hash 只算一次、桶形移位改固定移位应用到 `scene/hazard_layer_v3.v`。
   - v0.24 S4 曾试过“hash8 共用线性部分”，结果只是把逻辑挪进了 DSP。所以本批以 TD 实测为准，没有收益就拒绝。
   - 验证：`disaster_selector` 的 `tb_m3v3_sweep`、`tb_m3v3_card`，再加 A 的 `tb_hazard_equiv`，与 `tools/mountain_port/hazard_v3.py` 逐位一致。
3. **PCM 循环计数改 1 bit**
   - 先 grep `loop_count` 的所有使用者，确认只需要“至少播完一次”。
   - 再给 `audio/fat32_pcm_stream.v` 加 `LOOP_BITS` 参数并设为 1。这个标志供 S3 使用。
4. **寄存的 `error_flag`**：按 A 006e28a，去掉 error_code→cache_failed 的长组合路径。
5. **每个候选都要跑**：`run_sd_pin_boot.ps1` 和 `reset_of_module.py` 复位审计。原因：v0.24 S3 出过异步复位毛刺。

### S2 情景卡旁白和分阶段文字（纯 PC 侧，0 LUT）

1. 把 A `tools/scenes/{landslide,debris,flood,quake}_village/scene.yaml` 中的 village、warning 和各阶段 title、legend、narration 合并进 `tools/mountain_port/scenes/*/scene.yaml`。`prepare_*.py` 和 `hazard_v3.py` 两边逐行相同。
2. A 的 `voice/*.wav` 拷到 `tools/mountain_port/scenes/*/voice/`。
3. **移植 `scene_audio.py`**：A 的 `tools/scene_audio.py` 移到 `tools/mountain_port/scene_audio.py`。
   - 每句旁白放在采样点 t×1600 处，裁剪后归一化到约 −1 dBFS。
   - 需要把 `tools/make_audio_corpus.py` 的 ffmpeg 转换抽成 `convert()`。
   - SND4 为“报警提示音 + 撤离旁白”，预警下循环播放。
4. 恢复 `tools/mountain_port/make_scene_pack.py` 的 `--audio`/`--text` 输出。
5. **适配 TEXT v1 限制**（`tools/scene_text.py`：10 段，每段 ≤31 字，字库 ≤128 字形）
   - 每阶段字幕由 yaml 的 `subtitle` 给出精简旁白。
   - 预警语按村名定制。
   - 放宽 `complete_card_resources.py` 中 `validate_text` 对 `'立即撤离'` 的断言，并让 `card_resources.json` 从 yaml 取文字。
   - 编码前检查字数和字形数，超限直接报错，不写文件。
   - 实施（2026-10-22）：字幕改由新脚本 `tools/mountain_port/make_card_narration.py` 从 yaml 读取并检查；`complete_card_resources.py` 及 `card_resources.json` 保留原样，用于复现 v0.19 包。
6. **产出卡**：`releases/v0.25.0/s2-card.1`。四个 `情景模式/*_village` 目录的 FONT/TEXT/SND1–4 都要更新。PIC 和 THUMB.BMP 逐字节不变，不覆盖已有输出。

验证：
- 回读每个 BMP 并核对。
- `validate_text` 解码比对。
- 脚本检查每个 SND 的时长和旁白起点是否与 t×1600 对齐。
- 全部旁白听一遍。

### S3 旁白播完才 AUTO 换阶段（小改 RTL）

- 用 S1-3 的 1 bit 已播完标志，加 `scenario_audio_control` 的 session 号排除旧会话。
- 经 `SD/sd_card_bmp.v` 接到 `scene/scenario_fsm.v`，接法参照宣传模式 `publicity_voice_control` 的 `done`/`done_id`。
- AUTO 推进条件改为 `terminal_frame && (narration_done || 本阶段无 SND)`。无 SND 时仍按帧计时。
- 预警、手动 KEY2、SW3 菜单、宣传模式的行为都不变。

验证：参照 A 的 `tb_m4_fsm`/`tb_m5_fsm` 补 scenario_fsm 测试台，覆盖三种情况：旁白比 t=239 长、旁白比 t=239 短、没有文件。重跑 `mountain_scene`、`disaster_selector` 和 `publicity_mode` 回归，再跑完整 TD。

### S4 标注工具和制卡教程（纯 PC 侧）

1. A 的 `tools/annotate_scene.py`、`tools/build_annotate_exe.py` 移到 `tools/mountain_port/`，import 改成指向 `mountain_port` 下的 `hazard_v3` 和 `make_scene_pack`。
2. “生成”按钮要出完整卡文件集：先调 `make_scene_pack --gif --text --audio`，再调 `tools/make_menu_thumbnails.py` 生成 THUMB.BMP。
3. 在 `tools/scene_requirements.txt` 加 pyinstaller。exe 不进 git。
4. **文档**：从 A 拷入 `docs/场景标注工具使用说明.md`、`docs/滑坡卡制作教程.md`、`docs/images/landslide_tutorial/*.jpg`，路径和命令改成本项目的，最后补一步“放入 `情景模式/<名>_village` 后用 SW3 菜单选择”。

验证：在 Windows 上按教程从头做一张滑坡卡，用 SW3 选中后在板上播放。

实施（2026-10-22）：
- 工具放在 `tools/mountain_port/annotate_scene.py`（import 本项目的 `hazard_v3`、`make_scene_pack`）。“保存并生成场景包”按卡文字和旁白是否填全，自动带上 `--text`、`--audio`（`--gif` 照旧）；THUMB.BMP 由 `make_scene_pack` 生成 PIC1 时一并写出，所以不必另外调 `make_menu_thumbnails`。
- 新增 文件 → 卡文字与旁白…（填村名、预警语、标题、字幕，检查和生成用同一套函数）和 文件 → 安装到 SD 卡…（按灾害类型放进四个固定文件夹，先备份被覆盖和过期的文件，写后读回，PIC 头与文件夹不符则拒绝）。无窗口形式：`annotate_scene.py --install-card`。
- `scene_text.py` 加了 `repo_root()`（exe 从自带的 `osd_font_cn_16x16.v` 取字模）和宋体查找（`simsun.ttc` 找不到时给出明确报错），已有输出逐字节不变。
- `build_annotate_exe.py` 打包 exe（约 31 MB，不入库）；exe 生成的 11 个文件与 Python 版逐字节一致。
- 文档：`docs/场景标注工具使用说明.md`、`docs/滑坡卡制作教程.md`、`docs/images/landslide_tutorial/`（20 张图）、`tools/mountain_port/scenes/README.md` 新增“阶段音频”“场景文字”两节，路径改为本项目，并说明 SW3 菜单四个固定格子。
- 测试：`diagnostics/annotate_tool/test_annotate_tool.py`（卡文字检查、安装的备份与拒绝、窗口对话框，`ANNOTATE_SLOW=1` 时从窗口完整生成一次）。
- 没做：教程里“从头做一张滑坡卡”的人工操作，需要有人在窗口里按步骤点一遍。

### S5 场景 OSD 增强（最后做，有 LUT 门槛）

1. **新显示项**：在 `scene/scene_text_overlay.v` 中加入 A `scene_osd.v` 的三项：
   - t 进度条：1 px 对应一个 t，共 240 px；
   - 告警色块；
   - 图例：每阶段一段，含 E0–E7 色块，颜色取 `hazard_v3` 调色板。
   - 位置要避开现有的标题、y=112 村名、y=416 字幕和居中预警。
2. **TEXT.BIN 向后兼容扩展**：头部段数 0x0a 或 0x0e 都接受，多出的 4 段是图例；旧卡不显示图例。`scene_text.py` 加 `legends` 字段，并编码 E0–E7。
3. **开关和接受门槛**：用参数 `SCENE_OSD_EXTRA` 逐项开关。整机 ≤17250 LUT 且时序为正才接受。超出时先关图例保留进度条，还不够就设 0 发布。

验证：overlay 测试台覆盖 10 段和 14 段两种 TEXT.BIN，再跑完整 TD 并上板。

### S6 集成、板测、发布 v0.25.0

- 更新 `README.md`、`CHANGELOG.md`、`HANDOFF.md`、`releases/v0.25.0/{README,MANIFEST,BOARD_VALIDATION}.md`。
- 板测清单：
  - 四张灾害卡的旁白都能听到，字幕与阶段一致；
  - AUTO 等旁白播完才换阶段；
  - 预警下 SND4 循环、红框闪烁；
  - SW3 菜单和缩略图正常；
  - 宣传模式（VOI、波形、字幕）不受影响；
  - 旧卡兼容；
  - 冷启动出图时间；
  - 进度条和图例（S5）。

## 执行状态（2026-10-22 结项）

| 阶段 | 结果 |
|---|---|
| S1 | 批次 1 按键 1 ms 计时交付（−165 LUT，板测通过）；批次 2 hazard hash 共享实测 +80 LUT，撤回；批次 3、4 在本项目无对应开销，不做 |
| S2 | 交付 s2-card.1；S5 时字幕改成整段旁白（s5-card.2），与 A 的卡 56 段逐点一致 |
| S3 | 交付；s3-local.1/.2 板测通过 |
| S4 | 交付；工具测试通过，教程未由人按步骤完整走过 |
| S5 | 经 5 版候选完成：版式照 A 重做，真实 RTL 渲染与 A 的四张示意图逐像素一致；按用户要求隐藏页码标签和累计时间；修复换场景后图例缺字。最终 16796 LUT，在上限 17250 以内 |
| S6 | 用户板测清单全部通过，冷启动 5 s；发布 v0.25.0 |

与计划不同之处：
- S5 没有用参数逐项关闭功能，LUT 一直在上限以内。
- 字幕不再限制 15 字，而是像 A 一样用整段旁白（每段最多 255 字），需要新固件。
- 预警样式从“画面正中红字”改为 A 的“底部滚动预警语”。
- 额外去掉了场景和宣讲模式里的左上角状态行（A 也是这样）。
