# LUT 资源裁减 S1–S3 本地候选

候选 `v0.24.0-s3-local.1`。基线 `v0.24.0-plan.1`（功能与 `v0.23.0-s2-diagnostic-board.1` 相同）；冻结源码提交 `9c87a41`。本轮只减资源，**不删除、不改变任何用户可见功能**，SD 卡资源无需更换。

## 使用

1. 烧录本目录固定的 [demo.bit](demo.bit)（675020 字节，与构建输出逐字节一致），不要用会被覆盖的 TD 运行目录文件。
2. 沿用当前卡，重插卡或 KEY3 复位。
3. 按基线方式检查：开机首图；四宫格菜单（SW3、KEY1/KEY2 选择、KEY4 确认、拨回取消）；宣传四页的字幕与语音、手动和 AUTO 切页；四个场景的四阶段与预警；参数调节；拔卡或坏卡时的数码管错误页（每 2 秒翻页）。

## 改动

| 阶段 | 内容 |
|---|---|
| S1 | 扫描器 MBR 只捕获首个 FAT32 分区；版图临时量原地复用；BPB 只校验字段改为逐字节标志。数码管在 SD 时钟域先选 16 位页再跨域。菜单后端删除 `cached_parent`。图层旁带 62→47 位 |
| S2 | 扫描器 19 组文件表（PIC/EDU/THUMB、BGM/SND/VOI）搬入两块 16×60 分布式 RAM，读卡器与音频选择改为按行号读取 |
| S3 | 缩放读卡器的图头预检与解码共用一个 BMP 头校验；PCM 与 BIN 共用一个 FAT32 文件流读取器 |

原模块名（`bmp24_decoder`、`fat32_pcm_stream`、`bin_to_bram_loader`）保留为“核心+自带解析器/读取器”的包装，其他使用者不变。`sources/` 只备份相对基线修改的 12 个生产文件和本轮工具/测试。

## 本地结果

完整 `lut24_s3_td03`（Seed47，HighAreaOptimization）：Setup +0.120ns、Hold +0.057ns，STNS/HTNS=0。

| | 基线 | 本候选 |
|---|---:|---:|
| LUT | 18183（92.77%） | 17097（87.23%） |
| 寄存器 | 12119 | 10035 |
| BRAM9k / BRAM32k | 53 / 2 | 53 / 2 |
| DSP | 13 | 12 |

同源码 Seed43（`lut24_s3_td04`）：Setup +0.191ns、Hold +0.024ns、17107 LUT，未交付。约束逐字节未变，字库 17 块 BRAM/5796 行×21 位从最终网表解码一致，告警已审阅，详见 [VALIDATION.md](VALIDATION.md)。

计划目标 ≤16500 LUT 尚未达到（差约 600），本候选用于先确认 S1–S3 功能。

## 复现与回退

从基线标签恢复工程，将 `sources/` 覆盖回原路径；构建配置为 `reproduce/demo.al`、`reports/settings.cfg`，命令见 `reproduce/diagnostics/bottom_waveform/run_td.ps1`（`-Seed 47 -TdRoot <TD安装目录>`）。

回退烧录 [v0.23.0 诊断固定 bit](../../v0.23.0/s2-diagnostic.1/demo.bit)（`v0.23.0-s2-diagnostic-board.1`）。当前无 board 标签，未正式发布、未合并 main。
