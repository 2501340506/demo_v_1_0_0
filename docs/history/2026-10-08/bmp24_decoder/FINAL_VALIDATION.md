# 最终验证

最终复测：独立 decoder 640×480 和 3×2 各 16 场景通过；baseline、headers、scan、pixels、timeout、recovery、timeout_control 全部通过；系统回归 8 项全部通过。ModelSim 最终日志 0 errors、0 warnings。日志保存在本目录 simulation。

S3 已有 5 组新旧对照、旧生产对照、异步帧交接、重扫恢复、暂停续扫通过，证据见 releases/v0.6.0-bmp211/s3-local.1/simulation。最终源码与 S3 local 标签一致，bit 与标签内文件逐字节一致，未重复构建相同源码。

完整 TD 原结果：Setup +0.111 ns、Hold +0.024 ns、STA 99.93%；6379 LUT、4122 寄存器、4 BRAM、4 DSP、1 PLL。原厂商/IP 警告保留。报告见候选 timing 目录。

板测：用户确认步骤一好图功能正常、步骤二只显示好的 24 位图、步骤三功能正常；第四项为说明。记录总体通过，不虚构时长和次数。

2.11 本地闭环完成。GitHub 尚未上传，待用户明确授权。回退 S2 board.1 原 bit 保留。