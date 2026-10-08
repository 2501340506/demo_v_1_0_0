# BMP 2.11 S3 本地候选

版本：v0.6.0-bmp211-s3-local.1。日期：2026-10-08。本地验证通过，等待 S4 用户上板；未上传 GitHub，不建立 S3 board 标签。

## 变更

生产 bmp_read 固定调用 bmp24_decoder，删除旧解析分支、RGB 组装及重复像素计数。新增 bmp_header_check，统一扫描与解码的头字段采集、格式、长度和像素范围校验。bmp_read 保留 SD 扇区扫描、候选跨度、读取调度、短扇区检查、超时及 SDRAM 写请求握手；帧完整性及成功事件由 decoder 产生。

独立模块支持 24/32 位正高度未压缩 BMP；生产 ALLOW_32=0，维持只显示 24 位，32 位候选快跳。外部端口不变。正常 load_done 比 S2 晚一个时钟，错误脉冲及像素时序保持；显示交换仍由原有 SDRAM/跨域流程确认。

## 验证

- ModelSim：640×480 与 3×2 各 16 场景（共 32），包含 RGB/坐标、填充、尾部字节、坏头、两种长度不足、输入截断、上游错误及重载。正常大图 307200 像素。
- 7 类稳定性专项、5 组 S2/S3 对照、8 个整机回归入口通过；异步帧交接、重扫恢复、暂停续扫和 v0.5.4 旧生产对照通过。ModelSim 最终日志 0 error、0 warning。
- TD 独立综合及完整综合、布局布线、时序、bitgen 通过。最终构建 diagnostics/output/decoder_s3_attempt3；Setup +0.111 ns、Hold +0.024 ns，STA 99.93%。6379 LUT、4122 寄存器、4 BRAM、4 DSP、1 PLL。
- 相比 S2：LUT +19、寄存器 +24，其他资源不变；Setup 从 +0.096 改善到 +0.111 ns，Hold 从 +0.037 降至 +0.024 ns，仍为正。保留厂商 PLL/SDRAM 和物理流程警告，不声称 TD 零警告。约束未放宽。

## 产物与复现

使用本目录 [demo.bit](demo.bit)，不要使用 TD best_result 或 attempt1/2。UART 启动行沿用 BOOT v0.5.4-s3-local.2，不能据此区分候选，须按 bit 路径选择。

sources 仅保存三个改动 RTL；project/demo.al 对它们引用本包，未改动模块与约束引用仓库，因此需要配套仓库版本。顶层 TD_project 是用户工作区，未覆盖；新构建使用本包 project/demo.al 或 diagnostics/bmp_decoder/run_td.ps1。

复现入口：diagnostics/bmp_decoder/run_sim.ps1、run_ab.py、run_synthesis.ps1、run_td.ps1；diagnostics/stability/run_stability.ps1（7 Suite）、run_regression.ps1。日志见 simulation，物理报告见 timing。

回退：[S2 已上板候选](../s2-local.1/demo.bit)。S2 用户确认仅显示好图，其他功能通过；未补造逐项次数或长稳时长。

## 限制与下一步

原始连续扇区流没有真实文件 EOF。若物理文件截短但头部仍声称完整长度，后续扇区可被当作像素；本次结构拆分不解决 FAT 文件边界。测试使用已修正头部长度的 05_truncated_24bit.bmp。

2.11 结构拆分已落地，板测尚待确认；2.12 image 层、8 位错误码、独立恢复 FSM、fast_boot_gate、参数持久化、Flash/OSD 扩展不在本次范围。

按 [BOARD_VALIDATION.md](BOARD_VALIDATION.md) 上板；通过后再建 board 标签并进入 S5 最终回归和历史归档。GitHub 上传仍需单独明确授权。