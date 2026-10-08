# 构建与诊断归档

FAT32 v0.7.0 已结项：[验证入口](fat32/README.md) · [正式版与限制](../releases/v0.7.0/README.md)。下面的版本阶段描述保留为历史记录。

当前开发验证：[v0.5.4 UART与快速启动](uart_fastboot/README.md)，S1本地通过、待上板。既有[Flash与启动](flash_boot/README.md)测试继续复用。

v0.5.2 发布后证据补测：`single_pll/run_evidence.ps1`；[结果与范围](../releases/v0.5.2/evidence-2026-10-07/README.md)。完整帧行为测试通过，实际控制器刷新测试失败；脚本保留失败日志并返回错误，不代表全部通过。

活动验证见[stability](stability/README.md)；已完成阶段测试保留历史，新运行结果放 `output/`。

目录内容分为两类：

- 可复用并纳入版本控制：测试平台、运行脚本、固定测试素材，以及用于说明验证结论的精简证据。
- 本地生成且不纳入版本控制：`output/` 中的运行缓存和日志、`local_tools/` 中的本机工具、ModelSim 临时库及 TD 中间产物。

正式版本的 bit、验收记录和必要证据应进入 `releases/`；直接打开发布快照中的工程后产生的日志应移回 `diagnostics/output/`，不得作为发布内容继续累积。

```text
diagnostics/
  run_td_build.ps1        TD构建入口
  bmp_decoder/           BMP解码器专项运行入口
  flash_boot/            Flash与启动测试
  sd_recovery/           当前SD恢复测试
  single_pll/            单PLL与SDRAM专项测试
  stability/             稳定性回归、接口适配及固定证据
  test_assets/           固定测试素材
  history/
    v0.3.0/              可运行的版本回归脚本、testbench和Python参考
    sd_recovery/         延期SD问题的复现测试，仅存档
    2026-10-04/          早期阶段报告与构建对照
    2026-10-05/          旧本地运行结果压缩包及迁移清单
  output/                新运行缓存和日志（不入Git）
  local_tools/           本机诊断工具（不入Git）
```

- [v0.3.0测试说明](history/v0.3.0/README.md)
- [早期诊断记录](history/2026-10-04/README.md)
- [旧运行结果归档](history/2026-10-05/README.md)
- [SD问题复现存档](history/sd_recovery/README.md)，不表示启动修复
- [正式版本的固定验收证据](../releases/v0.3.0/v0.3.0-r2-s9-local.1/README.md)

从项目根目录构建：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_td_build.ps1 -BuildName manual_build
```

后续构建会更新TD运行目录，不得覆盖releases中的已交付文件。历史测试已适配新路径，仍读取当前生产RTL；复现某个旧版本的原始RTL应先检出相应Git标签，不能把历史脚本与任意后续RTL混用当作原始验收。
