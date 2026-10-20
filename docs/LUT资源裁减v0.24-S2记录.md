# LUT 资源裁减 v0.24.0 S2 记录（文件表搬入 RAM，未形成候选）

基线为 S1 中间提交 `f2daa88`。S1+S2 合并构建仍未达时序，S2 作为已验证中间提交保留，不建 local 标签。

## 改动

| 项 | 文件 | 内容 |
|---|---|---|
| 文件表 | `SD/fat32_volume_scanner.v` | 19 组 cluster+size 寄存器改为两块 16×60 分布式 RAM（零读延迟）：图像表 0..3 PIC、4..7 EDU、8 THUMB；音频表 0 BGM、4..7 SND、8..11 VOI。行存 cluster[27:0]（高 4 位恒 0）与 size。有效位仍为寄存器，`scan_start` 只清有效位；FONT/TEXT 仍为寄存器（BIN 加载器独立使用） |
| 写口 | 同上 | 19 个 `entry_commit` 改为每表一个提交及种类/2 位索引；名称互斥，每个目录项至多写一行。EDU/VOI 元数据检查失败时不写行，`voi_invalid` 语义不变 |
| 图像读取 | `SD/fat32_bmp_reader.v` | 原 THUMB/EDU/PIC 9:1 mux 改为 4 位行号 `{active_publicity,slot}` 或 8，SELECT/LOAD_SELECT 锁存时序不变；删除 `pic/edu/voi/snd` 128 位端口 |
| 音频读取 | `SD/sd_card_bmp.v` | VOI/SND/BGM 选择改为 4 位行号，`fat32_pcm_stream` 与 `pcm_stream_player` 的输入仍为同一组合值，二者在 IDLE/起播时锁存 |
| 菜单 directory | `scene/disaster_menu_backend.v` | 恢复 S1 前的寄存 `directory`（td02 显示组合源选择把读卡器就绪译码接到扫描器目录锁存的使能前）；`cached_parent` 删除保持 |

计划第 4 项不适用：每次场景扫描在 `scan_start` 清零扫描器目录槽并重新填充，后端必须保留父目录的 4 个场景簇快照。`scan_found_cluster/size` 无读者，综合已裁掉。分布式 RAM 推断成功（独立综合扫描器+原读出 mux：2535 LUT/1970 寄存器 → 2136/880；完整构建 sd_card_clk 域 DRAM LUT 32→152），未启用 BRAM 后备方案。

## 验证（本地）

- `diagnostics/lut24/run_scanner_s2.ps1`（`lut24_s2_scanner_try2`）：参考为 S1 扫描器外接原消费端 mux（`scanner_s1_indexed.v`），台架由 `make_scanner_s2_bench.py` 从 S1 台架生成，激励与覆盖门槛相同；每拍随机行号，行有效时比较行内容，其余输出逐拍比较。5 组参数×2 种子全部一致，图像/音频行比较各 10 万次以上，THUMB/VOI 行均覆盖；3 个变体（THUMB 写到 PIC1、VOI 写入 SND 半区、EDU 覆盖 PIC）均被检出。
- 菜单后端恢复寄存 directory 后 `run_menu_backend_s1.ps1`（`lut24_s2_backend1`）3 种子一致，约束探针与 3 个变体检出。
- `run_s2_regression.ps1`（`lut24_s2_reg1`）：FAT32 reader 42 例×gap2/0、directories 0–18、VFAT、audio_control/voice/stream 等价、控制器 case0/16/18/19（25 MHz、AUTO）通过。
- 快速启动指标（`lut24_s2_fast_metrics2`）：旧脚手架缺少 `ae76043` 后控制器台架新增的 `sector_slot` 初始化，首读即报错；补一行后 case0/11/16 通过，指标与 `releases/v0.23.0/s2-local.1/validation/fast_metrics_current21` 逐行一致。
- 未执行：`four_bank/run_system.ps1` 源文件表缺 `AL_MAP_LUT` 原语库，任何版本均在加载阶段失败，其覆盖由整工程控制器用例承担；7 个直接读取已删表端口的旧单元台架（tb_fat32_core、m5_scan、snd_scan、audio_scan、m3_scan_bounds、publicity_reader/scan）由新等价台架替代，未改写。`tb_directories`、`tb_fat32_reader` 仅改空端口连接。

## TD 构建（均未达时序，不交付）

| 构建 | Seed | Setup | Hold | LUT | 寄存器 | 最差路径 |
|---|---|---|---|---|---|---|
| 基线 | 47 | +0.039 | +0.073 | 18183 | 12119 | — |
| lut24_s2_td01 | 47 | −0.099 | +0.112 | 17625 | 10538 | scale buffer→decoder CE（未改） |
| lut24_s2_td02 | 43 | −0.723 | +0.057 | 17611 | 10536 | 读卡器 state→后端组合 directory→扫描器目录锁存（S1 引入，已修） |
| lut24_s2_td03 | 47 | −0.091 | +0.112 | 17534 | 10556 | audio_session→扇区适配器 idle_cycles CE（未改） |
| lut24_s2_td04 | 43 | −0.634 | +0.076 | 17557 | 10564 | 应用 target→宣传语音 auto_armed（未改） |

BRAM 53/2、DSP 13 不变，均无 ERROR。修复后失败路径随种子变化且在未改模块，净延迟占 70–84%。LUT 相对基线 −626~−649，距目标 16500 仍差约 1050。
