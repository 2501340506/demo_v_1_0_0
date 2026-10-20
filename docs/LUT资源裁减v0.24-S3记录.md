# LUT 资源裁减 v0.24.0 S3 记录（共用头校验与文件流读取器，形成候选）

基线为 S2 中间提交 `568dbd8`。S3 源码提交 `9c87a41`，S1–S3 合并形成 `v0.24.0-s3-local.1`，见 [固定候选](../releases/v0.24.0/s3-local.1/README.md)。

## 改动

| 项 | 文件 | 内容 |
|---|---|---|
| 解码器拆分 | `SD/bmp24_decoder.v`、`SD/bmp_header_check.v` | `bmp24_decoder_core` 输出头解析输入 `header_feed`、接收 `header_result`；`bmp24_decoder` 保留原名原端口，内含自己的解析器。新增打包形式 `bmp_header_result_check` |
| 共用头校验 | `SD/bmp_scale_stream.v`、`SD/fat32_bmp_reader.v` | 缩放路径中一个解析器在 HEADER_WAIT 接收预检扇区字节、在 file_go 后接收解码字节；复位为解码器复位 \| file_start \| HEADER_RESET。预检结果只在 HEADER_CHECK（任何加载之前）使用，解码器只在 active 时解析，二者不重叠；参数（ALLOW_32、RANGE_DIMENSIONS=1）与原两个解析器相同。非缩放路径不变 |
| 读取器拆分 | `audio/fat32_pcm_stream.v`、`scene/bin_to_bram_loader.v`、`SD/fat32_file_streamer.v` | 两个核心输出读取器请求总线、接收响应总线；原模块名保留为“核心+自带读取器”。新增总线形式 `fat32_source_streamer` |
| 共用读取器 | `SD/sd_card_bmp.v` | 场景与音频同时启用时，两个核心共用一个读取器（PCM 参数）。归属取寄存后的 `response_bin`，没有扫描状态译码进入读取器异步复位；BIN 的 file_start 至少晚 SC_BIN_START 两拍，归属切换时两侧均空闲（BIN 期间 audio_session 为 0、PCM 读取器在 START/READ 外保持复位）。各核心只在自己归属时看到 busy/done/valid，与原独立读取器空闲/复位时一致 |

BIN 原读取器的专用参数在其约束下无效：文件 ≤4096 字节时访问上限 8 不可达，13 位与 32 位大小给出相同偏移，`data_permit=1` 时数据门控无作用，因此无需计划中的 BIN 12 位写地址计数器（共用读取器仍提供字节偏移）。图像读取器与 BGM 同时运行，未合并。

## 验证

见候选 [VALIDATION.md](../releases/v0.24.0/s3-local.1/VALIDATION.md)：BMP 头/解码器/文件流/音频控制/语音等价及字幕单元通过；FAT32 reader 42 例×gap2/0；缩放读卡器与 S2 RTL 84 次结果逐行一致（例 24 为既有夹具限制）；控制器 case0–23 全部通过；快速启动指标与 v0.23 逐行一致。

## TD 构建

| 构建 | Seed | Setup | Hold | LUT | 寄存器 | DSP |
|---|---|---|---|---|---|---|
| 基线 | 47 | +0.039 | +0.073 | 18183 | 12119 | 13 |
| lut24_s3_td01/02 | 47/43 | — | — | 17097/17107 | 10035/10045 | 12 |
| **lut24_s3_td03** | 47 | **+0.120** | **+0.057** | **17097** | 10035 | 12 |
| lut24_s3_td04 | 43 | +0.191 | +0.024 | 17107 | 10045 | 12 |

td01/02 在布线写盘时因 D 盘空间耗尽中止（不是设计失败）；td03/td04 为同源码重新构建，均无 ERROR、STNS/HTNS=0。交付 td03。BRAM 53/2 不变，DSP 少 1（共用头校验的乘法器）。

## 磁盘空间

每次控制器用例或快速启动指标运行都会重新生成 24 个 FAT32 卡镜像（约 4.9 GB/次，两张 2 GB 稀疏镜像）。本会话累积约 76 GB 导致 D 盘写满；经用户允许，逐个路径删除 `diagnostics/output/lut24_*` 下 1625 个可再生的 `selector*.img/_bytes/_lba/_meta.hex`，保留全部日志与指标。此后 `run_s1/s2/s3_regression.ps1` 在每次运行后调用 `remove_selector_fixtures.ps1` 只删除该运行目录中这些文件。

## 结论与剩余

LUT −1086（92.77%→87.23%），寄存器 −2084，时序余量好于基线。距 ≤16500 仍差约 600；S4 后备项（media_adjust_cdc 合并、hash8 共用、streamer 内部冗余）预计合计 −200~−450，可能仍不足。先上板确认 S1–S3 功能，再决定是否继续 S4 或调整目标。
