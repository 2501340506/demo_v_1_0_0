# v0.16.0 LUT 优化记录

基线 v0.15.0（attempt46）：物理 15402 LUT / 8551 寄存器 / 4284+4308 Slice / 54 BRAM9K / 15 DSP，综合 14764 LUT，Setup +0.139ns、Hold +0.004ns。所有构建固定 HighFanoutOptimization/strategy5/opt_timing high/post_place_opt high，约束不变（diagnostics/media_adjust/run_td.ps1）。

## 测量噪声

输入不变时 TD 结果确定；任何输入变化会使未改动模块的综合/物理 LUT 波动 ±100～150（attempt01：scanner −43、streamer +24、HDMI bridge +74 等，源码均未改）。bridge 物理层次中约 875 LUT 是被扁平化进来的上游视频通路逻辑。因此单批收益小于噪声时按累计结果判断，不以单批 ±100 内的变化定取舍。

| 构建 | 内容 | 物理 LUT | 综合 LUT | 寄存器 | MSlice/LSlice | DSP | Setup / Hold ns | 结论 |
|---|---|---:|---:|---:|---|---:|---|---|
| lut_opt_attempt01 | 批1 | 15478 | 14748 | 8550 | — | 14 | +0.211 / +0.014 | 单批在噪声内，暂不定，与批2/3合并判断 |
| lut_opt_attempt02 | 批1–3 | 15072 | 14357 | 8490 | 4200/4201 | 13 | +0.109 / +0.004 | 保留：−330 物理、−407 综合、−2 DSP |

## 批1：提示音固定增益、亮度对比度饱和

- 乘法改 DSP 一项取消：门级报告显示全部乘法已在 DSP（转场 12 LUT、亮度对比度 113 LUT 无 LUT 乘法）。
- pcm_media_tone（FIXED_VOLUME=128）：FIFO 存 {enable, phase[19:16]} 5 位，读出后查常数表（sine×128>>>8，按原 floor 舍入），删去增益乘法与不可能触发的钳位，释放 1 DSP。端口音量模式保留原路径。
- brightness_contrast_adjust：centered 与 saturated 的加法改为位判断（product[17:14] 同号即在范围内，结果为 {~p[14],p[13:7]}）。
- 验证：lut_opt_b1_equiv1 亮度对比度红通道 2^24 组合穷举 + 40 万周期随机/5 次复位逐周期等价；提示音 5 组（128/255/77/0/端口音量）控制逐周期、样本在 valid 时等价（下游仅在 valid 采样），564 万样本；两个变异体检出。lut_opt_b1_unit1 调节 6 项、lut_opt_b1_hdmi_s9 HDMI/提示音/CDC 及包参考检查通过。

## 批2：静态帧长与地址

- frame_fifo_write：删 write_len 两级同步与锁存（所有使用者长度静态且为 BURST_SIZE 倍数），write_cnt 计突发数，into_burst 首项与第183行三操作数比较恒真删除；翻转地址一个加法器选步长；wr_x 收窄为 $clog2(FRAME_WIDTH)。
- frame_fifo_read：删 read_len 同步与锁存，read_cnt 计突发数，与 ceil(read_len/BURST) 比较。media_frame_reader：expected 寄存器改用静态 read_len。
- thumbnail_address：行号先选，row*5 一次，按 6/7 位移位；基址 8 项常数表。
- 验证：lut_opt_b2_equiv5 500 万周期，4 组写入（生产全图/缩略图、1024、BURST256 不翻转）逐周期等价并完成帧与取消；2 组读取链（旧 media_frame_reader→frame_fifo_read→thumbnail_address 对新）2041 帧、预览 1029 帧，覆盖欠载；thumbnail_address 8 组参数完整遍历 307200 地址；3 个变异体检出。11 条警告为 FIFO IP 未接端口类，新旧实例相同。

## 批3：有界计数与比较

- sd_card_cmd wait_count 按较大超时收窄；sd_card_sec_read_write timer 按 INIT_CYCLES 收窄（S_ERR 终态）、recover_count 10 位；pcm_stream_player phase 除以 8000 公因数；fat32_pcm_stream 回放比较 10 位（回放仅在 size≤512 进入）；scanner LAYOUT_CHECK 复用 LAYOUT_SUB 借位。
- 验证：lut_opt_b3_equiv2 400 万周期随机输入逐周期等价（452 次响应超时、186 次令牌超时、5 次初始化失败、12 次恢复、34.6 万回放字节、11 次复位），4 个变异体检出；lut_opt_b3_scanner1 scanner 对 v0.15.0 GAP=0/1/5 逐周期等价。

## S1 回归

- lut_opt_s1_regression1：21 项基础回归全部通过。

- lut_opt_s1_reader1：42 项 FAT32 读取（ByteGap=0）通过；lut_opt_s1_paths1 生产 SDRAM 帧路径、lut_opt_s1_loader1 双写入、lut_opt_s1_memory1 缩略图物理存储通过。
- lut_opt_s1_scaler1 缩放 2 项、lut_opt_s1_top1 生产顶层（336271 像素/1148 样本，44 条 PLL 模型/未接端口警告同 v0.15.0）、lut_opt_s1_production1 生产 PCM、lut_opt_s1_preview_keys1 四宫格按键通过。
- lut_opt_s1_preview2 真实 SDRAM 预览（165 帧/60 预览/10 提交/105578 刷新，26 条警告）与 lut_opt_s1_system2 完整系统（591 帧/22 提交/365203 刷新/17 淡变，32 条警告），统计与 v0.15.0 s2c_preview1/s2c_system1 逐项相同。首次运行（preview1/system1）因测试台层次引用已删除的 write_len_latch 装载失败，改为引用静态 write_len 端口后重跑，不计为 RTL 失败。
- lut_opt_gate1：亮度对比度与音量独立综合门级 9216 组 RGB 向量、11 档音量通过；警告为厂商原语未接端口类。
- single_pll/run_refresh_fix.ps1 历史脚本文件列表缺少后续新增模块，装载失败，与本次改动无关，未计入；SDRAM 刷新由 paths/预览/完整系统覆盖。
- 时序审计（lut_opt_attempt02/timing_audit）：14 类检查与 v0.15.0 一致，dangling 节点 4→3（被优化掉的寄存器），无时钟/组合环/无效约束均为 0。

## S1 候选

- releases/v0.16.0/s1-local.1：attempt02 bit，102 个输入逐字节一致，11 个改动输入，91 份通过日志。待板测。
