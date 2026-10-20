# LUT 资源裁减 v0.24.0 分阶段修改计划

## 范围与基线

- 基线：`v0.23.0-s2-diagnostic-board.1`（`6c8e294`，固定 bit `releases/v0.23.0/s2-diagnostic.1/demo.bit`）。分支 `feature/lut-reduction` 从 `main`（`cc0ea05`）建立，`main` 相对基线标签只多了文档和诊断提交，`user_source` 与 `TD_project` 逐行无差异。
- 基线资源（page_error_diag_td01，Seed47）：18183 / 19600 LUT（92.77%），12119 寄存器，53/64 BRAM9k，2/16 BRAM32k，13/29 DSP。sd_card_clk Setup +0.039ns（Fmax 100.392 MHz），Hold +0.073ns，STNS/HTNS=0。
- 目标：物理 LUT ≤16500（约 84%），**不删除、不改变任何用户可见功能**。
- 不改 SDC，不新增 false_path/multicycle，不合并流水级。已有恒等 LUT 和 keep 寄存器均针对实测 Hold/Removal 失败加入，保留；只删除已证实无用的。

## 资源热点（基线 demo_phy.area）

在本流程中，几乎每个寄存器都占一个物理 LUT（reg only 仅 55 个；扫描器综合后 1621 LUT，布局后 2982 LUT）。因此主要手段是减少寄存器，以及把寄存器表搬进 RAM。

| 模块 | LE | 主要原因 |
|---|---:|---|
| fat32_volume_scanner | 3094（寄存器 2554） | 约 20 组 cluster+size 文件表（约 1392 位寄存器）、MBR 4×32、版图临时量、BPB 字段 |
| fat32_file_streamer ×3 | 约 1600 | 图像、PCM、BIN 各一份；PCM 与 BIN 由 bin_owner 互斥 |
| bmp_header_check ×2 | 315 + 309 | preflight 与 decoder 参数相同，且不同时工作 |
| disaster_menu_backend | 447 | 128 位 clusters 副本、cached_parent 等 32 位副本 |
| 顶层 sd_debug | 约 192 寄存器 | 64 位跨域三级，数码管每次只显示 16 位 |
| disaster_layer 旁带 | 15 个无效恒等 LUT | SIDE_WIDTH 中综合已裁掉的位 |

## 阶段

### S1 低风险寄存器清理（预计 -450 ~ -700）

1. 扫描器 MBR：`mbr_lba[0:3]` 加 4:1 优先级选择，改为直接捕获首个匹配分区的 LBA（类型字节先于 LBA 字节到达，结果等价）。
2. 扫描器版图临时量 `data_sectors / partition_reserved / fat_span / cluster_offset` 改为原地计算，`cluster_count` 直接由减法装载，另加 `data_zero` 标志。
3. BPB 中只做校验的字段（`bytes_per_sector / root_entries / fat16 / fat_count / flags`）改为逐字节判定标志。
4. 顶层 sd_debug：在 SD 时钟域先按页选出 16 位再跨域，数码管内容不变。
5. 菜单后端删除 `cached_parent` 及 32 位比较（物理扫描必定 invalidate），`directory` 改为 2 位源选择加组合 mux。
6. disaster_layer 收窄 SIDE_WIDTH，去掉 15 个无效恒等 LUT。

验证：新增扫描器等价测试（覆盖 MBR、版图、BPB），`run_backend.ps1`、layer 等价测试、数码管页切换仿真、`fat32/run_reader.ps1`、`disaster_selector/run_s2.ps1`，完整 TD。

### S2 扫描器文件表搬进 RAM（预计 -1000 ~ -1300）

1. 图像表（resource0..3 / edu / thumb，9 项）和音频及字库表（snd / voi / audio / font / text，11 项）改为两块 16×60 分布式 RAM（零读延迟）；有效位保留为寄存器，`scan_start` 时只清有效位。
2. 19 个 `entry_accept` 加 19 个 `entry_commit` 合并为 5 位写地址加写使能。
3. 消费端（`fat32_bmp_reader.v` 的 9:1 mux、`sd_card_bmp.v` 的音频 mux、`bin_to_bram_loader` 的选择）改为按索引读 RAM。
4. 目录簇四份拷贝去掉中间级，backend 中 128 位 clusters 副本改为直接读取。
5. 若分布式 RAM 推断失败或时序变差，改用 2 块 BRAM9k，由 reader 的 `SELECT_RANGE` 状态吸收 1 拍读延迟。

当前最差路径 `scan_found_total → name_match → thumb_selected_reg` 经过扫描器，本阶段后必须复查。

验证：扫描器等价测试扩展到表内容与有效位，`run_reader.ps1`、`run_directories.ps1`、`run_lfn.ps1`、`run_s2.ps1`、`run_fast_metrics.ps1`、audio/voice/stream 等价测试、`four_bank/run_system.ps1`，完整 TD。

### S3 合并 BMP 头校验与共用 streamer（预计 -650 ~ -750；若 S1+S2 已达标只做第 1 项）

1. 共用一个 bmp_header_check：上移到 `fat32_bmp_reader`，按 HEADER_WAIT / READ_FILE 切换输入，reset 为 `HEADER_RESET | file_start`，头部结果经 `bmp_scale_stream` 下传 decoder。约 -270 LUT，另省 1 DSP。
2. PCM 与 BIN 共用一个 fat32_file_streamer：reset 为 `!(pcm_running || bin_owner)`，2:1 选择 `first_cluster / file_size / file_start / data_permit`，BIN 加载器自行计数 12 位写地址。图像 streamer 与 BGM 同时运行，不合并。

验证：header/decoder/stream/audio_control/voice 等价测试，`run_reader.ps1`，`publicity_mode/run_m3/m4/m5`，`narration_subtitles/run_unit.ps1`，mountain_scene 回归，完整 TD。

### S4 后备项（S1–S3 实测未达 ≤16500 时按序取用）

- 4 个 `media_adjust_cdc` 合并为一个邮箱并去掉 `pending`（-100 ~ -150）。
- `hazard_layer_v3` 中 8 个 hash8 共用线性部分（-80 ~ -150，与 `tools/mountain_port/hazard_v3.py` 逐位比对）。
- streamer 内部冗余：FAT 项只保留一份、`cluster_offset` 原地计算。

本轮不做：full/thumb 写入引擎合并、删除通用恒等 LUT、删除 legacy 图层或其他功能。

## 构建与验收

- TD 构建统一用 `diagnostics/bottom_waveform/run_td.ps1`（必须带 `-HighAreaOptimization`，seed 43/47），输出放 `diagnostics/output/lut24_sN_tdNN`。构建间存在 ±100–150 LUT 噪声，只以完整 TD 的物理报告为准。
- 每阶段门槛：Setup>0、Hold>0、STNS/HTNS=0，无 ERROR，Slice ≤90%，物理 LUT 比上一阶段下降；字库 ROM 物理初始化审计、约束逐字节比对、告警审阅通过，无新增告警签名。
- 等价验证沿用 `diagnostics/lut_opt/` 模式：`*_reference.v` 保存原模块，`tb_*_equivalence.sv` 逐拍比较，并用故意改错的变体证明测试有效。
- 失败构建保留在本地诊断输出，不交付；修复递增 local 编号。
- 上板验收项：开机首图、四宫格菜单、宣传四页（字幕+音频）、四场景四阶段及预警、AUTO、参数调节、数码管错误页。

## 标签

- `v0.24.0-plan.1`：本计划与基线。
- `v0.24.0-sN-local.N`：第 N 阶段本地验证候选（固定于 `releases/v0.24.0/sN-local.N/`）。
- `v0.24.0-sN-board.N`：用户确认对应候选上板通过。
- `v0.24.0`：全部阶段结项。

## 回退

任一阶段失败回退上一阶段 local 标签；整体回退 `v0.23.0-s2-diagnostic-board.1`。
