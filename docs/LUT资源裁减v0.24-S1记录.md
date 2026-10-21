# LUT 资源裁减 v0.24.0 S1 记录（寄存器清理，未形成候选）

基线 `v0.24.0-plan.1`（`3382706`）。用户选择方案一：S1 RTL 与测试作为已验证中间提交保留，不建 local 标签，与 S2 合并后以 `v0.24.0-s2-local.1` 统一构建判定。

## 改动

| 项 | 文件 | 内容 |
|---|---|---|
| MBR | `SD/fat32_volume_scanner.v` | `mbr_lba[0:3]`+`mbr_match` 改为 32 位 `mbr_lba` + `mbr_found/mbr_take`，只捕获首个 0B/0C 分区 |
| 版图临时量 | 同上 | 删除 `data_sectors/partition_reserved/fat_span/cluster_offset`：`overhead` 先存 FAT 跨度、后存根簇偏移；`cluster_count` 先存 partition+reserved、再由减法装载。REUSE_GEOMETRY 路径只读 `cluster_count/data_borrow`，不受影响 |
| data_zero | 同上 | 未新增：数据扇区为 0 时移位后簇数必为 0，原 `data_sectors==0` 判断冗余，直接删除 |
| BPB | 同上 | `bytes_per_sector/root_entries/fat16/fat_count/flags` 改为 10 个逐字节标志；镜像判定在字节 40 使用同一扇区字节 16 的 FAT 数 |
| 数码管 | `top_tf_hdmi_audio.v`、`SD/seg7_panel.v` | 页号两级同步进 SD 域，选出 16 位后再经原半周期级和两级面板寄存器；`seg7_panel` 输入改为 `debug_word`，输出 `debug_page` |
| 菜单后端 | `scene/disaster_menu_backend.v` | 删除 `cached_parent` 及 32 位比较；`directory` 改为 2 位源选择组合输出 |
| 旁带 | `top_tf_hdmi_audio.v` | `disaster_layer`/`brightness_contrast_adjust` SIDE_WIDTH 62→47，只传后级使用的描述符位 24..8 |

前提核对（菜单后端）：`scene_parent` 只在物理扫描接受（同拍 `invalidate`）和其 SC_SCAN 完成时变化；菜单进入要求 `safe_menu_idle`（含 `scan_state==SC_IDLE && !scan_request`），扫描接受要求 `!menu_owner`。残余：`media_frame_cache_control` 的 QUIESCE→SCAN_ISSUE 不受 pause 门控，理论上扫描接受可与可见 enter 同拍；该情形原设计已存在读卡器争用，`cached_parent` 删除在该拍仍等价，只有 `directory` 取实时父目录而非锁存值。

## 验证（本地）

- `diagnostics/lut24/run_scanner_s1.ps1`（`lut24_s1_scanner1`）：5 组参数×2 种子，每组 400 次扫描，原/新扫描器全部输出（含 sector_lba）逐拍一致；覆盖 MBR 非首项匹配、BPB 各字段拒绝、镜像标志、范围/环/上限错误、几何复用、扇区错误与中途复位。3 个改错变体（取末个分区、镜像忽略 FAT 数、根偏移少移一位）均被检出。
- `run_menu_backend_s1.ps1`（`lut24_s1_backend1`）：3 种子各 200 万拍，除 directory 外输出逐拍一致，directory 在 scan_start 至 scan_done 窗口一致；违反父目录约束的探针及 3 个变体均被检出。
- `run_panel_layer_s1.ps1`（`lut24_s1_panel_layer1`）：组合选页与原面板逐拍一致；跨域流水线仅在页/值变化后 12 拍内不同；旁带 47 位与原 62 位所用位、RGB 逐拍一致；变体均被检出。
- 回归 `run_s1_regression.ps1`（`lut24_s1_reg3`）：FAT32 reader 42 例×gap2/0（旧 bench 未接新端口的 TFMPC 告警为既有，其他告警为 0）、directories 0–18、VFAT、控制器 case0/16/18/19（25 MHz、AUTO）全部通过；另 disaster_selector `run_backend`、`run_layer_equivalence` 通过；mountain m5 loader/ui 通过，m5 scan 功能 PASS、既有未接端口告警。

## TD 构建（均失败，不交付）

| 构建 | Seed | Setup | Hold | LUT | 寄存器 |
|---|---|---|---|---|---|
| 基线 page_error_diag_td01 | 47 | +0.039 | +0.073 | 18183 | 12119 |
| lut24_s1_td01 | 47 | +0.026 | −0.011（scaler `raw_pipe_rgb`→BRAM `dia`） | 18162 | 11609 |
| lut24_s1_td02 | 43 | −2.455（53 端点，语音/显示控制，84% 布线延迟） | −0.011 | 18194 | 11609 |

BRAM 53/2、DSP 13 不变。失败路径均在未改模块。

## 结论

寄存器 −510，但综合后逻辑 LUT 15673→15682 基本不变；布局后改动模块合计约 −350 LE（扫描器 −245、后端 −73、图层 −29、面板 −6），被未改模块 ±50–150 的布局波动抵消。计划中“几乎每个寄存器占一个物理 LUT”的估算不成立：只减寄存器不能达到 ≤16500，后续以减少逻辑（宽 mux、重复模块）为主。

## 工具环境

本会话 ModelSim/TD 位于 `d:/`，旧脚本中的 `v_5f55`、`v_c075` 卷名和 `py` 启动器不可用。`run_td.ps1` 新增 `-TdRoot` 参数（默认值保持旧值）；旧脚本经 `diagnostics/lut24/invoke_legacy.ps1` 运行改路径的临时副本。
