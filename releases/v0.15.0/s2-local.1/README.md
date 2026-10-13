# v0.15.0 S2 local.1 候选

- 基线：v0.14.0；总回退 releases/v0.14.0/demo.bit。分支 feature/brightness-contrast-volume，源码提交 2cc5b57，构建 diagnostics/output/adjust_s2_attempt46（HighFanoutOptimization、PlacementStrategy 5，约束/时钟/引脚未改）。
- 上板文件：本目录 demo.bit（662216字节，与构建产物逐字节一致）。
- 功能：亮度、对比度、总音量调节（S2功能接入）。为解除布线拥塞，在功能不变前提下做LUT缩减：圆环高度分布式RAM、视频延迟BRAM环、提示音常数增益、字幕逐字节校验、UART文本ROM、数码管计数器收窄。
- 资源/时序：15402 LUT（attempt40为16966）、54 BRAM9K、15 DSP；Setup +0.139ns、Hold +0.004ns。Hold余量很薄，以板测为准。
- 验证：见 S2_VALIDATION.md 与 validation/（52份通过日志）；reports/ 含最终时序、面积、构建日志与时序审计；sources/ 为相对v0.14.0变化的24个生产输入；MANIFEST.md 列出全部102个输入。
- 已知限制：仅本地仿真与TD通过，未上板；UART BOOT行为历史固定字符串，不代表bit版本；持续运行、Flash、完全断电冷启动属S3。
- 板测：按 BOARD_VALIDATION.md 1–12项，请反馈候选名及实际通过/异常项。
