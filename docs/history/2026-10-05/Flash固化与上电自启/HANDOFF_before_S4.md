# 当前交接记录

2026-10-05。feature/flash-boot-v0.5.0。**S2用户确认通过，S3进行中：已有S2 Flash编程/校验成功日志，待用户脱离下载器冷启动确认。未进入S4，全部本任务提交和标签仅本地，S5才统一上传。**

## 已完成

- 用户回复“确认通过，进入 S3”，按S2整体板级通过记录，不补造逐项次数/设备。建立本地v0.5.0-s2-board.1，沿用S2固定bit，629624字节；前交接见docs/flash_boot/HANDOFF_before_S3.md。
- 已读取本机TD官方SWUG110 BitWizard指南，确认Tools→BitWriter、bw.exe、Program Flash和Verify Flash流程。完成[S3指南](../../../flash_boot/S3_FLASH_GUIDE.md)与[验收记录](../../../flash_boot/s3/BOARD_VALIDATION.md)。
- 通过UI Automation只读检查当前打开BitWriter并保存信息栏[日志](../../../flash_boot/s3/bitwriter_observed.log)。其中最后一组S2固定路径对应program_spi、verify_spi及Downloading succeeded，状态PROGRAM_FLASH success。工具识别EG4S20BG256，下载器AL-LINK，转换频率5MHz。助手本轮没有点击Run、未重复烧写。
- S3不改RTL、ADC/SDC、工程、bit，不重跑仿真或TD；已核对候选bit与S2 local标签内容一致。
- 项目README、版本入口、CHANGELOG、验证状态、阶段计划已更新。S3仅程序/校验部分有日志，不标记整阶段通过，不建立S3 board标签，不结项归档。

## 待确认与下一步

用户按指南关闭板电源、移除下载器JTAG连接、正常供电重新上电，不运行下载，确认自动首图、编号及提示音/旋律。至少一次独立冷启动正常才算S3通过。此前S2“确认通过”不自动代表做过该操作。

已向用户询问实际工具识别/Flash后缀/启动设置，随后只读界面已解决FPGA和下载器信息，并发现已有编程校验成功。完整Flash后缀与跳线位置未提供；已成功编程不要求为补文档重复烧写。若独立启动成功则记录实际现状，无需猜或改跳线。

用户确认S3后沿用同一bit建立本地v0.5.0-s3-board.1，进入S4（10次断电、10次复位、30分钟AUTO、100次有效翻图）。S4结论到达后才S5发布、完成归档与统一推送。

## 踩坑与边界

- 实际TD6.2工具叫BitWriter，不直接照抄课程旧Download/Hardware Setup界面。EG4当前界面可能只有MemorySize，不必找具体Flash型号框。
- 历史成功命令含-flashsize 128，而用户提供W25Q64是64Mbit；如实记录，后续重烧选实际64M。Flash ID日志只显示ef，不能推断容量或FV/JV等后缀。工具库不同后缀部分操作参数不同，不盲选。
- UI读取时列表曾出现0:EG4S20BG256，也显示No hardware；历史成功日志是操作证据，不把当前No hardware解释为烧写失败或已独立上电。
- 配置引脚按用户资料记录，不加业务SPI或改ADC；板卡启动模式未实物核实，不能猜跳线。
- S2保留原64个SDRAM接口与本轮旧内存3个负端点（最差−0.084ns），全局未收敛；SD底层初始化/免复位热插拔限制不变。S3固化成功不抹除时序边界。
- S2同参数重建需-HighFanoutOptimization -TimingOptimization ultra -PostPlaceOptimization high；本阶段直接使用固定bit，不重建。
- 用户releases/v0.3.0/demo.al原修改不提交；不批量删除，UTF-8写文档。没有推送或合并main。
