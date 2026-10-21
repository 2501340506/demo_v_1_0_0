# v0.24.0-s3-local.1 板测反馈与定位（2026-10-21）

## 用户反馈

- 烧录 `releases/v0.24.0/s3-local.1/demo.bit`：屏幕 `ERR:05`；数码管循环显示 `00001F`、`00002F`、`00003F`、`3b000F`。
- 上电约 6–8 秒后出现；每次都这样。
- 同卡同板烧录之前的代码（v0.23 诊断 bit）正常。

## 解码

| 显示 | 含义 |
|---|---|
| 数码管末位 `F` | `sticky_error==2`：扫描失败（SC_INIT 见到 `sd_init_failed`） |
| 屏幕 `ERR:05` | 扫描失败后应用控制进入 ERROR |
| 第 0 页 `3b00` | `sd_debug[15:0]={2'b00,cmd[45:40],cmd_response}`：最后一条命令 CMD59（0x3b），应答寄存器为 00（可能沿用 CMD16 的 00） |
| 第 1–3 页 `0000` | `read_debug` 为 0：从未执行 CMD17 读扇区 |

6–8 秒与 `INIT_TIMEOUT_MS=2000`、`INIT_RETRIES=3`（共 4 次尝试）一致：SD 初始化在 CMD59 附近无法完成，失败后调试值冻结。故障在 FAT32/图片读取之前，与卡内文件无关。

## 本地核对

- SD 驱动 `sd_card_top.v`、`sd_card_cmd.v`、`sd_card_sec_read_write.v`、`spi_master.v` 及 `timing.sdc`、`pin.adc` 与 `v0.24.0-plan.1` 逐字节相同。
- 新增引脚级启动仿真 `diagnostics/lut24/run_sd_pin_boot.ps1`（生产参数、100 MHz、真实 SPI 驱动不 force，卡模型按协议应答并带 CRC16 提供选择器夹具扇区），`lut24_sd_pin_boot2`：v0.23（plan 标签）与 S3 均 8 条命令后初始化完成、10 次读扇区、扫描成功、最终 `sd_debug=0200c124c1241100`，完全一致。
- td03 SCLK/MOSI/nCS 输出路径（IO 寄存器）裕量与 v0.23 相同（+17.313/+8.879/+0.380 ns）；MISO 输入 Setup +5.206 ns / Hold +1.539 ns（v0.23：+6.000/+0.963），采样寄存器物理位置不同。

结论：逻辑与静态时序均不能解释板上失败，表现与 v0.23 期间“同源码不同布局、板上结果不同”同类；根因尚未查明，不凭相关性改约束。

## Seed43 对照结果（s3-diagnostic.1）

不能正常启动；屏幕 ERR:05，数码管开机即只显示 `0E`（`sticky_error==1`：扫描成功但找到 0 张图），多次复位稳定复现。同一源码两个布局失败在不同位置，说明是布局依赖、静态时序和仿真都不覆盖的设计问题。

## 根因候选与修复

td04 最终网表复位审计（`diagnostics/lut24/reset_drivers.py`、`reset_of_module.py`）：

- SD 命令模块/SPI 主机的复位 `protocol_rst = rst || sd_init_failed || (state==S_RECOVER)` 由 LUT 驱动。初始化 CMD41(00100)→CMD16(10010) 中间态 10100 即 S_RECOVER(20)，译码毛刺会部分复位命令模块，之后 CMD59 不再得到应答，2 秒×4 次后初始化失败——对应 td03 的 6–8 秒、`3b00`。
- 读卡器/扫描器复位 `parser_rst = rst || scan_state==SC_RESET` 由 LUT 驱动。SC_SCAN(0011)→SC_DECIDE(1001) 中间态 0001 即 SC_RESET，毛刺清除扫描器有效位——对应 td04 的 0 张图 `0E`。
- 两处译码 v0.23 已有；v0.23“同源码不同布局、板上结果不同”的历史现象与此机制一致。

修复 `ef0eaaf`：三处异步复位改为寄存器直接驱动（含 S3 共用图头解析器复位）。修复后两个种子均时序通过，网表复核 SD 命令模块/SPI 主机复位全部来自寄存器。分别固定为 `s3-local.2`（Seed47）、`s3-local.3`（Seed43）。根因待两者板测确认。

## 下一步

用户同意烧录同源码、Seed43 的 `releases/v0.24.0/s3-diagnostic.1/demo.bit` 做 A/B。`s3-local.1` 不建 board 标签，保留原样。
