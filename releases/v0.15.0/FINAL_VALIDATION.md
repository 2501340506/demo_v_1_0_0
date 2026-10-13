# v0.15.0 最终验证（2026-10-13）

- 正式 demo.bit 复用 s2-local.1，662216 字节；与候选文件及 v0.15.0-s2-local.1 标签内 bit 逐字节一致。
- 生产源码及 TD 工程相对 v0.15.0-s2-local.1 标签无变化（git diff 为空），未重新构建或重复仿真。候选打包时 102 个工程输入与 attempt46 构建快照逐字节比较一致。
- attempt46 完整 TD：Setup +0.139ns、Hold +0.004ns，TNS 均为 0，无工具 ERROR；时序审计 12 类检查与 v0.14.0 s3-local.3 一致。
- 最终源码仿真：21 项基础回归、6 项调节专项、缩放与字节流、四宫格按键、生产顶层，以及真实 SDRAM 预览（165 帧）与完整系统（591 帧、481827 个 PCM 精确样本）；LUT 缩减各项旧新等价、变异与门级证据。52 份通过日志在 s2-local.1/validation。
- S2 用户确认“功能均正常”；S3 用户确认 Flash 下持续运行 20 分钟正常、完全断电冷启动通过。
- 已知限制：Hold 余量 4ps；UART BOOT 行为历史固定字符串；大图首次加载仍顺序读取完整 BMP。未做的 LUT 缩减项记录在 diagnostics/media_adjust/TIMING_STRUCTURE.md，作为后续备选。
- 回退 releases/v0.14.0/demo.bit。未跟踪用户素材与既有 worktree 保留。
