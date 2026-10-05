# v0.5.0 Flash与启动验证

在项目根目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/flash_boot/run_baseline.ps1 -Stage s0
```

基线脚本复用当前稳定性七项解析器/控制专项、真实解析器异步缓冲三配置及八个旧入口（当前控制/缓冲版本）。输出到`diagnostics/output/flash_boot_s0`，固定证据在本目录evidence。不要并行执行会共用仿真工作库的旧入口。

S1仅改顶层PLL复位，新增专项验证模型必须实际响应reset并等待重新锁定；其他生产模块不变时复用本轮S0证据，不反复执行无关回归。ModelSim行为PLL/存储不证明实际冷启动，用户SRAM上板通过后才进入S2。
