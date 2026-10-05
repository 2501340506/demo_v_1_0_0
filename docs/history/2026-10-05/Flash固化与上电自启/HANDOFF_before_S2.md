# 当前交接记录

2026-10-05。分支`feature/flash-boot-v0.5.0`。**S0完成；S1本地通过，固定候选待用户SRAM上板。S1用户确认前不得进入S2。所有本任务提交和标签仅本地，最终S5才统一上传。**

## 当前任务与已完成

- [分阶段计划](../../../Flash固化与上电自启分阶段修改计划.md)与[课程对照](../../../FLASH_BOOT_SOURCES.md)已落盘；README下载及验证状态已修正，正式版本仍为v0.4.0。
- S0七项稳定性、真实解析器异步交接三配置、八个既有入口通过，零错误零警告；固定证据diagnostics/flash_boot/evidence/s0。本地标签v0.5.0-plan.1，无新bit。
- S1生产RTL仅顶层两处PLL reset接~rst_n；reset_sync、其他模块、PLL配置、工程清单、ADC、SDC保持原样。构建脚本增加显式-HighFanoutOptimization开关，旧调用默认不变。
- S1最终真实顶层五轮专项通过：两种锁定顺序、两时钟树停钟恢复、按钮使PLL重新锁定、在途提交清空、五域三拍释放、静音与首图提示。正向编译/仿真零错误零警告。旧顶层负对照在未连接PLL按键复位处失败，属预期结果。
- TD最终flash_boot_s1_local5通过，place hfn_opt_effort=high。3951 LUT/2900寄存器/4 BRAM/4 DSP/2 PLL；SD+0.147ns、内存同域+0.266ns、像素→串行+6.222ns。全局Setup−6.565ns/TNS−250.840ns、Hold+0.004ns，原64个SDRAM接口负端点仍在，未全局收敛。
- [候选v0.5.0-s1-local.1](../../../../releases/v0.5.0/v0.5.0-s1-local.1/README.md)含629624字节固定bit，与最终运行产物逐字节一致，含源清单、工程/约束/构建设置快照、仿真及TD报告。未烧Flash、未上板、未推送。
- 前任务交接保存在[任务前快照](../../../flash_boot/HANDOFF_before_S0.md)。v0.5.0尚未结项，不做完成归档。

## 阻塞与下一步

唯一阶段门槛是用户完成[S1上板步骤](../../../../releases/v0.5.0/v0.5.0-s1-local.1/BOARD_VALIDATION.md)：SRAM下载固定bit，5轮复位后首图恢复、手动切图、AUTO及音频正常。等待实际反馈，不补造次数或设备。出现SD初始化卡住先对照v0.4.0，不自动扩大为底层协议修复。

确认通过后沿用固定bit，记录验收、建立本地v0.5.0-s1-board.1并进入S2（SDRAM就绪同步及扫描门控）。S3核实实际启动模式并固化W25Q64，S4最终长稳，S5发布/归档/统一推送。当前不推送、不合并main。

## 踩坑与边界

- 默认布局产生两个SD复位recovery负端点−0.273ns、扇出690。线网max_fanout、寄存器max_fanout/keep尝试最终均未改善，全部撤回；诊断证据保存于diagnostics/flash_boot/evidence/s1_build1至s1_build4。物理高扇出优化实际生效后两个新增端点消失，未放宽SDC。
- 同参数复现必须使用-HighFanoutOptimization；GUI打开工程快照后需手动将Phy/Place/hfn_opt_effort设high，快照默认仍medium。正式上板使用固定候选，不使用会覆盖的TD运行目录。
- PLL reset只接~rst_n，不能接含未锁定条件的reset_request，避免闭环；保留三拍释放。
- request是toggle，不能用电平1判断在途；专项已改检查ready=0。测试提交为注入事件，PLL/FIFO/存储行为模型不等于实际TF/Flash上板验证。
- 课程40/80/125MHz描述不一致，当前内存125MHz。W25Q64及配置引脚由用户确认，启动跳线留到S3核实；不新增业务Flash接口。
- 既有SD初始化、免复位热插拔和板级IO约束边界保留。TD存在既有警告类型，不宣称零警告。
- UTF-8读写及PowerShell到Python管道编码；rg通配模式用-g。用户releases/v0.3.0/demo.al原修改保留且不提交；不批量删除文件或目录。
