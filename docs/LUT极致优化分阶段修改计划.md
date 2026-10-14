# v0.16.0 LUT 极致优化（功能不变）分阶段修改计划

状态：S0 计划已确认（2026-10-14），基线 main fdae2c2 / v0.15.0，分支 feature/lut-optimization，标签 v0.16.0-plan.1。S1 board.1 通过（15072 LUT）；S2 local.1 已固定待板测（14190 LUT）；“乘法改 DSP”经门级报告核实已在 DSP，取消。

## Context

v0.15.0 已发布（main fdae2c2），全设计 15402 LUT / 8551 寄存器 / 54 BRAM9K / 15 DSP，Slice 87.72%，Setup +0.139ns、Hold 仅 +0.004ns。v0.15.0 S2 已证明：Slice>90% 时 TD 跳过 Hold 修复，LUT 余量直接决定能否收敛及后续功能还能加多少。目标：在用户可见功能不变的前提下尽可能降低全设计物理 LUT，为后续需求留出空间并扩大时序余量。

用户确认的边界：
- **等价边界：放宽到可见行为。** 画面、音频、HDMI 符号合规、UART 文本、数码管、按键手感保持不变；允许内部握手多拍、按键计时 ±1ms、调整测试台中非生产契约（如 scanner 重扫保留元数据）。
- **节奏：分 3 阶段，每阶段一个 local 候选上板。**
- 判据始终是**完整 TD 物理全设计 LUT**（批3教训：局部降≠全局降；物理层次被扁平化，如 bridge 名下约 830 LUT 实为上游视频合成/BCH）。

## Git / 标签 / 目录（遵循 执行规则.md）

- 原目录建 `feature/lut-optimization`（基于 main / v0.15.0），不另建 worktree；保留用户未跟踪素材（tools/PIC*、Qhc.wav、board_samples、问题小记录.txt 修改）不入提交。
- 计划落盘 `docs/LUT极致优化分阶段修改计划.md`，标签 `v0.16.0-plan.1`。
- 候选 `v0.16.0-sN-local.N`，板测通过 `v0.16.0-sN-board.N`，结项 `v0.16.0`。
- 等价测试放 `diagnostics/lut_opt/`（沿用 `diagnostics/lut_reduction/` 的 `*_ref.v` + `tb_*_equiv.sv` + `run_*.ps1` 模式）；构建输出 `diagnostics/output/lut_opt_attemptNN`；结构与数据记录 `diagnostics/lut_opt/LUT_RECORD.md`。
- 提交前缀 `perf:`（RTL）、`test:`（等价台）、`docs:`、`release:`、`board:`。

## 每批通用流程（每批 = 一次完整 TD）

1. 冻结旧模块为 `*_ref.v`；写旧新并行逐周期等价台（随机激励 + 复位 + 背压），并做一个故意变异体证明台能检出。放宽项改为“可见输出等价”（像素/PCM/HDMI 符号/UART 字节流）。
2. 跑直接相关专项 + 受影响回归。
3. 完整 TD：`diagnostics/run_td_build.ps1 -HighFanoutOptimization -PlacementStrategy 5`，约束/时钟/引脚不变。
4. 保留判据：全设计物理 LUT 下降、Slice 不明显上升、Setup/Hold 非负（负则定点修或撤回）。综合日志核实 RAM/DSP 实际映射；新 ROM 做门级初值验证（同 lut_uart_rom_gate1）。
5. 不达标则恢复该批源码，被拒源码存 `diagnostics/output/<attempt>/rejected`，记录在 LUT_RECORD.md。

## S1 低风险逐周期等价（预计 -500 ～ -700）

- **批1 乘法/常数（DSP 有 14 个空闲）**
  - `video_transition_pixels.v`：3 个组合 8×5 乘法强制映射 DSP（25MHz，余量足）。
  - `adjust/brightness_contrast_adjust.v`：6 个乘法只用了 3 DSP，另一组强制 DSP。
  - `audio/pcm_media_tone.v`（FIXED_VOLUME=128）：乘 128 改移位、删去不可能触发的钳位，FIFO 存相位与使能，读出后查正弦表（释放 1 DSP）。参考 `diagnostics/lut_reduction/pcm_media_tone_ref.v`。
- **批2 常数长度与地址**
  - `SD/frame_fifo_write.v`、`SD/frame_fifo_read.v`、`SD/media_frame_loader.v`、`SD/media_frame_reader.v`：顶层 `write_len/read_len` 恒为 FRAME_PIXELS（全图/缩略图>>2），改为参数；write_cnt 以 burst 计数（13 位），删去恒真的三操作数比较；地址 ±1/−1279 双加法器合为一个；wr_x 收窄到 10 位。
  - `SD/thumbnail_address.v`：两套 y*640/y*320 与 bank*K 共享一条移位加通路，bank 基址查 4 项表。
- **批3 位宽与冗余比较**
  - `sd_card_cmd`（wait_count 25 位、byte_cnt 10 位）、`sd_card_sec_read_write`（timer、recover_count）、`fat32_bmp_reader`（ack_wait）、`pcm_stream_player`（phase 25 位、单加法器）、`fat32_pcm_stream`（size≤512 寄存标志、replay 10 位比较）、scanner（total_sectors 比较用减法借位）、`bmp_header_check`（dimensions_ok 高位零+11 位比较；确认 skip_format 死逻辑已被裁掉，未裁则删除）、`bmp24_decoder`（row_payload/row_last 13 位、pixel_y 改递减计数）、`image_scale_nearest`（sw*480/sh*640 改 13 位比较、inside 改边沿置位寄存标志）。
- **S1 门槛**：最终源码重跑 v0.15.0 S2 的 21 项基础回归、调节专项、缩放、四宫格按键、生产顶层、真实 SDRAM 预览与完整系统；时序审计；102 个工程输入逐字节核对；固定 `releases/v0.16.0/s1-local.1`（只备份改动文件），标签后交板测（清单沿用 v0.15.0 BOARD_VALIDATION 1–12 项）。

## S2 中风险结构改写，可见行为不变（预计 -900 ～ -1300）

- **批4 HDMI 音频包 BCH**（`hdmi_audio/hdmi_audio_sample_packetizer.v`、`hdmi_bch8.v`）：4 个 56 位并行 BCH（约 466 LUT）改为每收集一个采样时用 1 个共享 BCH 算出该子包 ECC 并寄存（子包＝单采样，逐周期等价）；若综合收益不足，再改为载荷期每拍 2 位串行累加。同时利用 frame base 恒为 4 的倍数，简化 channel status 位判断。验证：新建 HDMI 符号流旧新逐拍比较台（以 `diagnostics/history/v0.3.0/tb_hdmi_packets.sv` 为基础）。
- **批5 TMDS/包调度**：`hdmi_tmds_channel_encoder.v` 的 8b→q_m 与 1 计数改 256×13 BRAM 查表（3 BRAM9K），用 bridge 前级寄存值寻址，替代 rgb_q；ACR/InfoFrame 常数包按像素索引 ROM 化，scheduler 288 位选择只留音频包。分两次 TD 以便单独取舍。
- **批6 FAT 簇→LBA**：scanner 导出 `data_base = data_start_lba − (2<<shift)` 与 `cluster_shift`，删 reader/streamer 里的 4 个减法器和 spc_shift 副本；5 处 32 位桶形移位改为逐拍移 1 位（请求晚 0–7 拍，req/busy 握手吸收）；`sd_card_bmp.v` 的 4×64 位图片表副本改为 found→resource 2 位映射，复用 reader 已有选择器。补“音乐播放中加载大图不欠载”专项。
- **批7 杂项**：`osd/subtitle_frame_commit.v` 两个 124/125 位比较合为随 held 携带的 1 位标志；`seg7_panel` 单译码器（先核实批5是否已做）；`pcm_stream_player` 8×16 FIFO 改分布式 RAM；`uart_event_logger` snapshot 改从 queue_read 取字段。
- **S2 门槛**：同 S1，另加 HDMI 符号流比较、真实 PCM 播放与 BGM+图片并发回归；固定 `s2-local.1` 板测（重点：HDMI 音频、EDID 显示器兼容、长时间播放）。

## S3 放宽到可见行为（预计 -400 ～ -900，逐项取舍）

- **批8** `SD/mode_key_control.v`：3 个消抖、hold/held 计数共用 1ms 预分频节拍（计时 ±1ms）；按键专项改为按时间窗断言。
- **批9** scanner：取消 scan_start 对 320 位 cluster/size 的同步清零（生产每次扫描前均有复位，消费者只在 valid/found 下读取），同步修改 `tb_audio_scan` 该断言；与 MBR 单项 LBA 捕获合批重新评估。
- **批10** 字库 BRAM 化：`osd_font_cn_16x16`、`osd_font_5x7` 合入 1 个 512×18 BRAM，scroll/adjust/status/timestamp 共享（双口），提前一拍寻址；先证明各 OSD 的 pixel_x 在 de 内逐拍递增，再以像素转储逐帧比较。
- **批11（评估项，各自单独 TD）**：①解码器复用 preflight 头检查结果，去掉第二个 bmp_header_check（约 -400，前提：同一文件运行期间不变）；②全图/缩略图两个 frame_fifo_write 合为分时引擎（约 -150～-200，burst 交错改变，需真实 SDRAM 双 writer 逐像素验证）。达不到全局下降或时序变负即放弃。
- **S3 门槛**：同 S2 + 按键手感板测、全部 OSD 显示核对；固定 `s3-local.1` 板测，之后做 Flash 持续 20 分钟与完全断电冷启动。

## 不做

- 合并图片与音频 streamer（BGM 与加载图片并发）；删除 sd_debug/数码管/UART 调试内容（可见行为）；改时钟、引脚、约束；字幕提交 dirty 标志（握手时机）。

## 结项

S3 板测与 Flash/冷启动通过后复用该候选原 bit 发布 `v0.16.0`（逐字节核对、不重建），更新 README/CHANGELOG/HANDOFF/VALIDATION_STATUS，归档 `docs/history/<日期>/lut-optimization/`，合并 main 并推送分支与本任务标签。

## 风险

- Hold 余量仅 4ps：LUT 下降通常改善，但每批都需复核；attempt44/45 曾在路由 Hold 修复阶段 TD 崩溃，若复现，记录并以小网表变化绕开。
- 估算均为读码手算，未综合；阶段合计目标约 -1800 ～ -2900 LUT（约 12–19%），以实测为准。
- ModelSim：`d:/modelsim/win64`；TD 6.2.1：`d:/TD/anlogic/TD6.2.1`。tb_pcm_preview_rescan 需与 tb_pcm_production 同批编译；Git Bash 需临时加 Python313 到 PATH。
