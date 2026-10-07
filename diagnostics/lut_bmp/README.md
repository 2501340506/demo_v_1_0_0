# v0.5.3 BMP LUT 优化复现

生产 RTL 仅改 `bmp_read.v`。TD 在独立输出目录构建，使用归档的单 PLL 工程清单，不修改用户 GUI 工程。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/lut_bmp/run_td.ps1 -BuildName v053_reproduce
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/lut_bmp/run_td.ps1 -BuildName v053_baseline_reproduce -Baseline
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/flash_boot/run_baseline.ps1 -Stage v053_reproduce
```

每次使用新的 BuildName，原有输出保留。TD 参数固定为 high-fanout high、timing ultra、post-place high，使用默认 seed。ModelSim 入口包含七套 BMP 专项、三组真实解析器异步交接及八个既有回归入口；逐项检查 PASS、Errors 和 Warnings，不只看进程退出码。

当前工作区的 GUI 工程遗漏 `sys_pll_s3.v`，因此直接构建会报 black box。归档清单引用的是已验收单 PLL 源码，不改变时钟设计。
