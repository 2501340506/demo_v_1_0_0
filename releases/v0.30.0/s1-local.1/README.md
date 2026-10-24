# v0.30.0 S1 候选 1：Flash 加载时钟 2.5 → 16 MHz

基线 v0.29.0（Seed 5）。分支 `feature/fast-boot`。**板测通过**（2026-10-24，烧 Flash 冷启动，用户反馈“板测正常”，但“感觉并没有快多少，跟之前的速度一样”；没有计时数据）。[计划](../../../docs/开机加速v0.30分阶段计划.md)。

## 要换的文件

- 把 [demo.bit](demo.bit) **烧进 Flash**（BitWriter → Program Flash，64Mbit，起始地址 0x000000，勾选或补做 Verify，步骤同 [S3_FLASH_GUIDE](../../../docs/flash_boot/S3_FLASH_GUIDE.md)）。
- 只用 JTAG 下载到 SRAM 测不出差别：SRAM 下载不经过 Flash 加载这一步。
- TF 卡不用换。

## 改动

- 只重新生成位流：用 v0.29.0 Seed 5 的布线库（`diagnostics/output/v29_td_s5/.../demo_pr.db`）执行 `bitgen -g {mclk_freq_div:16MHz}`。RTL、综合、布局布线都没变。
- 原因：TD 在 EG4 上不设参数时，Flash 加载时钟默认为 2.5 MHz。位流 677,348 B 约 5.42 Mbit，x1 加载约 2.2 s；改成 16 MHz 后约 0.34 s，预计上电到出图快约 1.8 s。
- 选 16 MHz 的原因：再提高到 29/36 MHz 只能再省约 0.15 s，板上 Flash 走线的余量更小。
- 新增 [diagnostics/fast_boot/run_bitgen.ps1](sources/diagnostics/fast_boot/run_bitgen.ps1)：对已布线的库只重跑 bitgen。
- [diagnostics/run_td_build.ps1](sources/diagnostics/run_td_build.ps1) 加了 `-MclkFreq`，默认 16MHz，在 TD 跑完后调用上面的脚本重新生成 `demo.bit`；`-MclkFreq default` 回到 TD 默认。这样做是因为 `set_param bitgen mclk_freq_div` 实测不起作用。

## 验证

- **EG4 参数核实**，见 [validation/mclk_probe.txt](validation/mclk_probe.txt)：
  - 参数名是 `mclk_freq_div`；PH1 的 `mclk_freq`、`boot_mode` 在 EG4 上报参数无效。
  - 可选值为 2.5、5、7.5、10、12、14.5、16、29、36 MHz。
  - 不带参数生成的 bit，和 2.5MHz 生成的除 Date 行外完全相同，所以默认值就是 2.5 MHz。
  - `-compress` 在 EG4 上没有生成压缩文件；没有 x4 参数可用。
- **与 v0.29.0 的差别**，见 [validation/diff_vs_v0.29.txt](validation/diff_vs_v0.29.txt)：
  - 用同一个 Seed 5 布线库按默认参数重新 bitgen，结果和 `releases/v0.29.0/demo.bit` 除 Date 行外逐字节一致。
  - 本候选（677,358 B）和 v0.29.0（677,348 B）相比，差别只在文件开头的配置命令：控制寄存器 `0xC2` 的分频位和它的 CRC、新增的一条 10 字节 `0xF5` 命令，以及文件头的两行 CRC 说明。之后的帧数据完全相同。
  - 所以逻辑、时序、资源都和 v0.29.0 一样：17623 LUT，Setup +0.164 / Hold +0.110 ns。
- bitgen 日志：[validation/bitgen_16MHz.log](validation/bitgen_16MHz.log)，无 ERROR。
- **没有做的**：
  - RTL 没变，没有重跑仿真回归。
  - `run_td_build.ps1` 的新选项还没有经过一次完整构建（这次只单独调用了 `run_bitgen.ps1`）。
  - 加载时间是按位流大小和时钟算出来的，没有实测。

## 板测结果

- 2026-10-24：用户用 Flash 烧写，屏幕上电后直接出画面。功能正常；主观感觉启动速度和 v0.29.0 一样，没有计时。
- 与预计的约 1.8 s 不符，原因未查明。下一步用数码管计时诊断 bit 分段测量（不发布）。

## 上板要看的

1. 烧 Flash 并校验通过。
2. 拔掉下载器，断电再上电，至少 10 次，每次都正常出第一张图、有声音。
3. 有条件的话，用手机录像，分别计时 v0.29.0 和本候选从上电到出图的时间（各 3 次）。没有计时也可以，只反馈是否正常。
4. 抽查翻页、AUTO、宣讲、SW4 面板（逻辑没有改，确认一下就行）。

## 回退

对 [v0.29.0 demo.bit](../../v0.29.0/demo.bit) 做 Program Flash 加校验。如果出现偶发不启动或花屏，降到 10 MHz 出 s1-local.2。
