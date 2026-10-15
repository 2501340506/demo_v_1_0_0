# M4 验证入口

生产基线为 `v0.17.0-m3-local.1`；板测回退为 `v0.16.0`。全部在原项目目录运行，输出必须使用新名称，失败输出保留。

```powershell
& diagnostics/mountain_scene/run_m4_unit.ps1 -RunName mountain_m4_unit03
& diagnostics/mountain_scene/run_m4_top.ps1 -RunName mountain_m4_top01
& diagnostics/mountain_scene/run_m4_top.ps1 -Legacy -RunName mountain_m4_legacy_top01
& diagnostics/mountain_scene/run_m4_pcm.ps1 -RunName mountain_m4_scenario_pcm02
& diagnostics/mountain_scene/run_legacy.ps1 -Suite pcm -RunName mountain_m4_pcm01
& diagnostics/mountain_scene/run_legacy.ps1 -Suite reader -RunName mountain_m4_reader01
& diagnostics/mountain_scene/run_legacy.ps1 -Suite reader32 -RunName mountain_m4_reader32_01 -Cases 0,1,2,3 -ScaleTest 1
& diagnostics/mountain_scene/run_legacy.ps1 -Suite decoder -RunName mountain_m4_decoder01
& diagnostics/mountain_scene/run_legacy.ps1 -Suite scaler -RunName mountain_m4_scaler01
& diagnostics/mountain_scene/run_legacy.ps1 -Suite preview -RunName mountain_m4_preview01 -Audio -Failures
& diagnostics/mountain_scene/run_legacy.ps1 -Suite system -RunName mountain_m4_system01
py -I diagnostics/mountain_scene/test_scene_pack.py
py -I diagnostics/mountain_scene/test_scene_audio.py
```

调节六项回归使用 `diagnostics/media_adjust/run_unit.ps1` 的原测试矩阵，替换本机 ModelSim 路径为 `F:/modelsim/win64` 并使用新输出目录。`tb_adjust.sv` 新增 fade 端口绑零，普通调音量仍按256步长验证。

`tb_scenario_pcm` 使用生产扫描器、SD 服务、文件流、播放器、主音量及 HDMI 桥；以扇区字节接口注入 FAT32 数据（不验证物理 SD 电气/时序），逐个核对所选文件、样本与增益。覆盖碎片簇、两字节短循环、缺失 SND3 回退 BGM、四阶段/回环/预警/速度、排空换段、退出、重扫和无音频帧计时。生产 top 专项检查完整接线和帧内状态保持，旧系统长回归覆盖真实 SDRAM 与既有功能。

完整 TD 构建和约束审计：

```powershell
& diagnostics/mountain_scene/build_m4.ps1 -BuildName mountain_scene_m4_attempt04 -PlacementStrategy 7
& diagnostics/mountain_scene/run_legacy.ps1 -Suite audit -RunName mountain_scene_m4_attempt04
py -I diagnostics/mountain_scene/package_m4.py mountain_scene_m4_attempt04
```

上列名称为本次运行入口，已有目录禁止重用；最终合格构建与实测结果以 [候选验证记录](../../releases/v0.17.0/m4-local.1/VALIDATION.md) 为准。打包须检查正 Setup/Hold、完整无 ERROR 构建、LUT≤16660、工程输入逐字节一致、68份仿真和编译日志、约束审计及工具专项。新增告警必须核实，不能扩大忽略范围绕过失败。
