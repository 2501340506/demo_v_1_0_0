# v0.30.0 — 开机加速正式版

基线 v0.29.0。这一版只改了一处：FPGA 上电后从 Flash 读取位流的时钟，从 TD 默认的 2.5 MHz 改成 16 MHz。RTL、布局布线、功能、按键、卡都没变。

正式文件：[demo.bit](demo.bit)，677358 字节。这个 bit 直接复用已经上板通过的 [s1-local.1](s1-local.1/README.md)，没有重新构建，两份逐字节一致。来源：v0.29.0 Seed 5 的布线库（`diagnostics/output/v29_td_s5`），只重新执行 `bitgen -g {mclk_freq_div:16MHz}`。

**必须烧 Flash**（BitWriter → Program Flash 并校验）。用 JTAG 下载到 SRAM 不经过 Flash 加载，体现不出这项改动。卡不用换。

## 结论：开机慢主要在显示器

| 阶段 | 时间 | 来源 |
|---|---|---|
| FPGA 从 Flash 加载 | 约 2.2 s → 约 0.34 s | 按位流大小和时钟计算，未实测 |
| 复位释放 → 开始读第一张图（SD 初始化、FAT32 挂载、表头） | 12 ms | 板上实测（诊断 bit，1 次） |
| 复位释放 → 第一帧输出到 HDMI | 941 ms | 板上实测（诊断 bit，1 次） |
| 显示器识别 HDMI 信号 | 未计时，占大头 | 用户确认 |

- FPGA 在加载完成、PLL 锁定后就一直输出 HDMI 信号。显示器识别信号和读图同时进行。
- 用户确认启动慢主要是显示器的问题；换一台质量更好、尺寸更大的显示器，时间反而更长。
- 所以这次加载提速了，但用户感觉不到变化。固件里能继续优化的空间都比显示器这一段小：SD 多块连读最多省约 0.25 s，首图逐行显示最多提前约 0.9 s。这两项没有做。

## 改动

- 位流配置：`mclk_freq_div` 2.5 MHz → 16 MHz。
  - 和 v0.29.0 的 bit 相比，只有文件开头的配置命令不一样，帧数据完全相同。
  - 没有选 29/36 MHz：再提高只能多省约 0.15 s，板上 Flash 走线的余量也更小。
- 构建脚本：
  - [run_td_build.ps1](../../diagnostics/run_td_build.ps1) 新增 `-MclkFreq` 参数，默认 16MHz。以后完整构建会自动用 16 MHz；传 `-MclkFreq default` 恢复 TD 默认值。
  - 新增 [run_bitgen.ps1](../../diagnostics/fast_boot/run_bitgen.ps1)，可以对已经布线的库只重跑 bitgen。
- 诊断工具：新增 [boot_time_seg.v](../../diagnostics/fast_boot/boot_time_seg.v)，用数码管显示毫秒计时，配有测试台 [tb_boot_time_seg.v](../../diagnostics/fast_boot/tb_boot_time_seg.v)。只在诊断构建里用，不进正式版。

## 资源与时序

和 v0.29.0 完全相同：17623 LUT（89.91%）、10281 寄存器、55 BRAM9K，Setup +0.164 ns / Hold +0.110 ns。

## 验证

- 核实了 EG4 的参数，见 [mclk_probe.txt](s1-local.1/validation/mclk_probe.txt)：
  - 参数名是 `mclk_freq_div`，可选值为 2.5、5、7.5、10、12、14.5、16、29、36 MHz；
  - 不设参数时就是 2.5 MHz；
  - 用 `set_param` 设置不生效。
- 用 Seed 5 布线库按默认参数重新生成 bit，和 v0.29.0 的发布 bit 除 Date 行外逐字节一致。
- 上板通过（2026-10-24）：烧 Flash 后冷启动，用户反馈"板测正常"。
- 诊断 bit（Seed 11，只放在本地 `diagnostics/output/fb30_diag_bit/`）上板读数：A = 12 ms，b = 941 ms。

## 限制

- Flash 加载时间是算出来的，没有实测。
- 诊断读数只有 1 次。
- `run_td_build.ps1` 的 `-MclkFreq` 已经在诊断构建中完整跑过（10 次构建）；正式 bit 用的是单独调用 bitgen 的方式生成的。
- SD 时钟域的时序余量仍然很小，这一点和 v0.29 相同。

## 回退

对 [v0.29.0 demo.bit](../v0.29.0/demo.bit) 执行 Program Flash 并校验。
