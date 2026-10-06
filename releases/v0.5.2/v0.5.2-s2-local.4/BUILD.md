# local.4 构建与验证

顶层 top，EG4S20BG256，TD 6.2.1，双 PLL。原 SD 100 MHz、SDRAM 125 MHz、像素 25 MHz、串行 125 MHz 不变，SDC/ADC 不变。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/sd_recovery/run_tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/stability/run_regression.ps1 -Stage v052_s2_local4_final
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/sd_recovery/run_handoff.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_td_build.ps1 -BuildName v052_s2_local4_final -HighFanoutOptimization -TimingOptimization ultra -PostPlaceOptimization high
```

专项引脚模型用独立整帧多项式除法核对 CRC7，检查 CMD0=95、CMD8=87、CMD59(1)=83 以及变化扇区地址的 CMD17。覆盖 CMD59 成功才就绪、拒绝后释放接口和重新初始化成功、正确/错误数据 CRC16。512 字节数据仍为 `(i*37+11)&255`，独立已知 CRC16 为 D594；模型不随 FPGA 局部复位自动复位。

首次构建出现三条 SD 内部负端点（最差 −0.239 ns），位于播放请求来源判定路径，未交付。接受加载请求时，已有 next/previous pending 能区分手动与 AUTO；使用这两个标志替代重复组合计算的 auto_load_request，逻辑等价。修改后重新运行既有回归、保图和 TD。中间报告与 bit 保留于 `diagnostics/output/v052_local4_rejected_timing/`。

附 demo.al 为工程快照，相对路径以 TD_project 为基准。本版未扩展写卡，生产写卡入口仍绑零。候选只在本地保存，等待 SRAM 实测；仿真不能证明卡返回 0000 的成因。

最终结果：四个专项、八个既有回归入口、三组异步保图配置全部通过，每组保图 8 次提交、0 冲突、0 混帧。TD 最终构建完成，内部路径无负端点，详见 TIMING.md。bit 为 629624 字节，与最终构建输出逐字节核对一致；原始日志随 simulation/ 保存。对应本地标签 `v0.5.2-s2-local.4`，未上传。
