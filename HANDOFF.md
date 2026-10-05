# 当前交接记录

2026-10-05。分支`feature/flash-boot-v0.5.0`。**S3用户整体确认通过，进入S4，等待固定Flash候选最终长稳验收。所有本任务提交与标签仍仅本地，S5才统一上传。**

## 已完成

- 用户最新回复“确认通过，进入 S4”，按S3整体通过记录，结合既有BitWriter编程/校验成功日志确认S3完成；不补造测试次数、Flash后缀或跳线位置。
- 本地验收标签`v0.5.0-s3-board.1`；前交接保存在[HANDOFF_before_S4](docs/flash_boot/HANDOFF_before_S4.md)。
- 已准备[S4验收清单](docs/flash_boot/s4/BOARD_VALIDATION.md)，更新S3记录、活动计划、README、版本入口、CHANGELOG及验证状态。
- S4继续引用`releases/v0.5.0/v0.5.0-s2-local.1/demo.bit`，629624字节。不改RTL/工程/约束，不重建、不重复烧写、不重跑仿真。

## 当前卡点与下一步

无本地实施阻塞，等待用户完成实物长稳测试：10轮独立断电重启、10轮运行中复位、AUTO连续30分钟、100次有效翻图及MAN/AUTO模式切换。当前未取得S4通过结论，不建立S4 board或正式版本标签。

用户反馈问题则记录并定位；生成新bit须重新验证受影响阶段及Flash启动。用户确认S4后进入S5，沿用已验收bit逐字节核对正式产物，更新文档、历史归档，再合并main和统一推送本任务分支与标签。整体反馈仅按整体确认记录。

## 踩坑与边界

- 实际TD6.2工具叫BitWriter，不直接照抄课程旧Download/Hardware Setup界面。EG4当前界面可能只有MemorySize，不必找具体Flash型号框。
- 历史成功命令含-flashsize 128，而用户提供W25Q64是64Mbit；如实记录，后续重烧选实际64M。Flash ID日志只显示ef，不能推断容量或FV/JV等后缀。工具库不同后缀部分操作参数不同，不盲选。
- UI读取时列表曾出现0:EG4S20BG256，也显示No hardware；历史成功日志是操作证据，不把当前No hardware解释为烧写失败或已独立上电。
- 配置引脚按用户资料记录，不加业务SPI或改ADC；板卡启动模式未实物核实，不能猜跳线。
- S2保留原64个SDRAM接口与本轮旧内存3个负端点（最差−0.084ns），全局未收敛；SD底层初始化/免复位热插拔限制不变。S3固化成功不抹除时序边界。
- S2同参数重建需-HighFanoutOptimization -TimingOptimization ultra -PostPlaceOptimization high；本阶段直接使用固定bit，不重建。
- 用户releases/v0.3.0/demo.al原修改不提交；不批量删除，UTF-8写文档。没有推送或合并main。
