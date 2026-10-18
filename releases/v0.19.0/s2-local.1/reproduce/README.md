# TD35 复现入口

在 `v0.19.0-s2-local.1` 的原工程根目录运行，使用新输出名，不覆盖已有诊断构建。ModelSim 为 F:/modelsim/win64，TD 为 E:/TD（v6.2.168116）。固定 bit 来自 disaster_s2_td_attempt35；板测直接使用本候选 demo.bit。

```powershell
diagnostics/mountain_scene/build_m5.ps1 -BuildName disaster_s2_reproduce01 `
  -PlacementStrategy 1 -PlacementSeed 59 -TimingOptimization ultra `
  -PlaceHoldFix -HighAreaOptimization -HighRouteEffort -HighPlaceEffort `
  -PostRouteOptimization -PostPlaceOptimization high -PackMode more_lut_pair
```

根 runner 与本目录副本一致；完整实际选项见 ../reports/phy_1_settings.cfg。SD/视频/存储/HDMI时钟分别为100/25/40/125MHz，未为通过构建放宽时钟。必须重新检查实际 final_timing.rpt、资源、无 ERROR 和 bitgen，不能只看退出码。

本阶段相对 S1 的34个生产文件位于 ../sources；其余输入从 S1 标签引用，工程全部118个输入清单见 ../MANIFEST.md。选定仿真/编译日志清单及证据见 ../validation，专项脚本、覆盖范围和历史快照边界见工程 diagnostics/disaster_selector/S2_VALIDATION.md。不重复执行一次性集成/归档脚本来复现 RTL。
