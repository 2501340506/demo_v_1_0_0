# 验证范围与限制

全部为本地仿真与构建结果；板测尚未执行。日志在 `validation/<运行名>/`，`manifest.json` 列出运行清单。

## 等价测试（原模块与新模块逐拍比较，故意改错的变体均被检出）

- 扫描器 S1（`lut24_s1_scanner1`）：5 组参数×2 种子，原/新全部输出逐拍一致；覆盖 MBR 非首项匹配、BPB 各字段拒绝、镜像标志、范围/环/上限错误、几何复用、扇区错误和中途复位。
- 扫描器 S2（`lut24_s2_scanner_try2`）：S1 扫描器加原消费端选择 vs RAM 表扫描器，5 组参数×2 种子；行有效时比较行内容（图像/音频行各 10 万次以上，THUMB/VOI 行有覆盖）。S3 未改扫描器。
- 菜单后端（`lut24_s2_backend1`）：3 种子各 200 万拍；违反父目录约束的探针被检出，说明删除比较依赖生产约束（物理扫描必定 invalidate 缓存）。
- 数码管与图层旁带（`lut24_s1_panel_layer1`）：组合选页逐拍一致；跨域流水线只在翻页/值变化后 12 拍内不同；47 位旁带与原 62 位所用位、RGB 逐拍一致。
- S3 相关既有等价：BMP 头、解码器、文件流、音频控制、语音（`lut24_s3_reg1_*`），字幕单元。

## 回归（S3 RTL）

- FAT32 reader 42 例×字节间隔 2/0（`lut24_s3_reg1_reader_scale0`）。旧台架未接新端口的 TFMPC 告警为既有，其余告警为 0。
- 缩放读卡器（共用头校验）与 S2 RTL 对比（`lut24_s3_reader_scale_compare2`）：84 次运行结果逐行一致，82 次通过；例 24 在两者上都报“bad image succeeded”——该夹具按非缩放 4 簇上限设计，缩放流读取器上限为 16384，属既有夹具限制。
- 选择器控制器 case0–23 全部通过（`lut24_s3_reg3_ctrl*`），case19 为 25 MHz 并检查 AUTO；覆盖 BIN 加载、PCM 播放、缩放解码、菜单与宣传。
- 快速启动指标 case0/11/16（`lut24_s3_reg3_fast_metrics`）与 `v0.23.0/s2-local.1/validation/fast_metrics_current21` 逐行一致。
- directories 0–18、VFAT（`lut24_s2_reg1_*`）：扫描器 S3 未改。

## 构建审计（`reports/audit/`）

- `timing.sdc` 与仓库及 v0.23 诊断候选逐字节一致，`pin.adc` 与仓库一致；check_timing 五项均为 0；SW3 约束目标未变。
- 字库：从最终物理网表解码 17 块 BRAM INIT/INITP，5796 行×21 位与 `releases/v0.22.0/s1-local.1/font_rows.hex` 一致。
- 告警：综合 73=73、布局布线 7=7。两条 SYN-5011（未驱动的空闲 BRAM 端口引脚）位置迁移：旁带 BRAM `u_hazard/ramread1` 的两条消失，未改的 `hazard_layer_v3` 表 BRAM 的 `addrb[0]/bea[0]` 新增两条，同类告警，已审阅。
- 133 个源文件与提交源码逐字节一致（`reports/source_check.json`）。

## 未执行与限制

- `four_bank/run_system.ps1`：源文件表缺 `AL_MAP_LUT` 原语库，任何版本均在加载阶段失败；覆盖由整工程控制器用例承担。
- 7 个直接读取已删文件表端口的旧单元台架（tb_fat32_core、m5_scan、snd_scan、audio_scan、m3_scan_bounds、publicity_reader/scan）未改写，由 S2 等价台架替代。
- 真实 SDRAM 联合场景（v0.23 已记录的 combined19 未完成项）本轮未补。
- S1、S2 的 TD 构建均未达时序（见 `docs/LUT资源裁减v0.24-S1记录.md`、`-S2记录.md`），不交付。
- 本地通过不能替代上板；实体卡 FAT 布局、物理 SD 传输、显示与音频需板测确认。
