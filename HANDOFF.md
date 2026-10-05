# 当前交接记录

2026-10-05。分支feature/flash-boot-v0.5.0。S0基线完成，下一步S1；S1上板确认前不得进入S2。所有本任务提交、标签暂不推送。

## 已完成

- 课程及配套六文件对照、[阶段计划](docs/Flash固化与上电自启分阶段修改计划.md)和[课程说明](docs/FLASH_BOOT_SOURCES.md)已落盘。
- 七项稳定性、真实异步交接三配置、八个既有入口通过；固定证据见diagnostics/flash_boot/evidence/s0。本阶段没有新RTL/bit。
- 修正README当前版本与下载指向，建立本地开发分支；前一任务交接见[任务前快照](docs/flash_boot/HANDOFF_before_S0.md)。

## 阻塞与下一步

S0无阻塞。提交S0并建立v0.5.0-plan.1，再实施PLL外部复位接线、S1复位专项和TD构建。固定候选后等待用户5轮复位、切图、AUTO及音频确认，不提前做S2，不上传。

## 踩坑与边界

- PLL reset只接~rst_n，不能接包含未锁定的reset_request；五域三拍释放保留。
- 课程40/80/125MHz描述不一致，当前内存125MHz，不整套替换。
- 64个SDRAM接口时序负端点仍保留，SD初始化与免复位热插拔延期。
- 中文文件及PowerShell到Python管道使用UTF-8；rg使用-g传入通配模式。
- ModelSim行为PLL/存储不代替上板；压力测试遵守请求合并/挂起语义。
- 用户releases/v0.3.0/demo.al修改原样保留，不混入本任务提交。不批量删除，固定候选不能被TD运行输出覆盖。
