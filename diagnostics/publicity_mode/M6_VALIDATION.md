# M6 验证复现与范围

最终结果以[固定候选验证](../../releases/v0.18.0/m6-local.1/VALIDATION.md)及其JSON/原始日志为准。本阶段不改RTL/工程，不重新TD；M5原bit及111工程输入/根脚本逐字节复用，不继承M5对新素材的板测结论。

## PC与素材

仓库根目录执行，所有输出目录必须不存在：

```powershell
py -I -X utf8 diagnostics/publicity_mode/test_publicity_pack.py --output diagnostics/output/publicity_m6_pc_NEW
py -I -X utf8 diagnostics/publicity_mode/verify_m6.py --output diagnostics/output/publicity_m6_media_NEW
```

前者验证旧工具16项及旧M1输入/产物复现；后者验证实际四BMP全部像素、四PCM全部样本与固定输入一致，重打包/重画和完整整卡复现、负例变化范围。声音合成方式、固定输入及卡包见[内容README](../../tools/publicity/geohazard_release/README.md)。PC字节一致不能代替人工听审或实板完整播放。

## RTL重跑配方

本次RunName前缀为publicity_m6_final，重跑应换成新的前缀；下方使用publicity_m6_recheck避免覆盖原始证据。每次调用在新目录准备现有生产代码/测试台和厂商模型，未使用FastDebug。可在不同终端运行互不重名的套件；同一目录不可并发。

```powershell
& diagnostics/publicity_mode/run_m5.ps1 -RunName publicity_m6_recheck_m5_01 -Suite m5
& diagnostics/publicity_mode/run_m5.ps1 -RunName publicity_m6_recheck_m4_01 -Suite m4
& diagnostics/publicity_mode/run_m5.ps1 -RunName publicity_m6_recheck_unit_01 -Suite unit
& diagnostics/publicity_mode/run_m5.ps1 -RunName publicity_m6_recheck_voice_01 -Suite voice_top
& diagnostics/publicity_mode/run_m5.ps1 -RunName publicity_m6_recheck_pixels_01 -Suite pixels
& diagnostics/publicity_mode/run_m5.ps1 -RunName publicity_m6_recheck_status_01 -Suite status
foreach ($case in 0..3) {
  & diagnostics/publicity_mode/run_m5.ps1 -RunName "publicity_m6_recheck_mode${case}_01" -Suite mode -Case $case
}
& diagnostics/publicity_mode/run_m5.ps1 -RunName publicity_m6_recheck_legacy_01 -Suite legacy_top
& diagnostics/publicity_mode/run_m5.ps1 -RunName publicity_m6_recheck_system_01 -Suite system
& diagnostics/publicity_mode/run_m5.ps1 -RunName publicity_m6_recheck_preview_01 -Suite preview -Card flood_village
```

配方共49份仿真、13个独立编译目录。收集器collect_m6.py针对本次固定输出目录检查每项PASS、Errors:0及既有告警范围，审计完全部才复制证据；已有候选日志拒绝覆盖。复查时直接审计新日志，不能用新输出改写已打标签的local.1。

生产音频/像素/状态栏专项使用短PCM、合成BMP和外部SD/存储模型，最终输出比对有明确采样窗口；真实SDRAM整机/预览回归单独运行。实际M6长讲解约175秒，仅PC完成全样本比较，RTL未完整播放该讲解；实际整卡/HDMI/音频听感与持续运行交[板测](../../docs/宣传模式M6整机验收.md)。

M5原183份仿真/69份编译模型日志与TD27报告作为继承证据单列，不计入上述49/52。既有模型告警、STA未设IO delay及sd_miso例外不隐去；Setup +0.006ns属于原实现结果，不称高裕量。
