# M3 local.1 本地验证

完整范围、模型边界和历史失败见[M3验证记录](../../../diagnostics/publicity_mode/M3_VALIDATION.md)。本候选等待板测，仿真不能替代SD卡物理链路和HDMI整机验证。

- 155份最终PASS日志、33份编译/厂商/PLL/加密日志逐项核验，无ERROR/FATAL；已知模型和top测试台watchdog常量告警保留。17项专项、108项scanner/reader回归、20项unit及两项bin_loader间隔补测、四项双村top、RGBA/预览/长系统和最终生产top均通过。
- 最新生产top07：7016112 HDMI时序检查、338602宣传像素、634652情景像素、546静音PCM样本；实际reader/scaler与307200源像素。外部SD运输/存储握手/raw像素由模型替代。真SDRAM系统591帧/481827精确PCM、预览293帧/238405 PCM；这些旧路径测试显式关闭PUBLICITY，不称一次仿真覆盖全部组合。
- TD publicity_m3_td_attempt14，strategy7/high/HighAreaOptimization：15785 LUT、10202寄存器、56 BRAM9k、2 BRAM32k、13 DSP。Setup +0.097ns/Hold +0.024ns，STNS/HTNS0，STA覆盖99.97%，无ERROR且完整bitgen，bit673856字节。
- 时序审计汇总与M6一致；保留两块BRAM32k dob[9] dummy模型节点和既有I/O/PLL约束诊断。综合/布线告警规范化后与M6集合无增减，不称全审计零诊断；原报告见[check_timing](reports/check_timing.txt)及[告警比较](reports/warning_delta.json)。
- 111个工程输入及根构建脚本与TD快照逐字节一致；仅备份相对硬件M6实际变化的11个生产输入，未改输入引用M6标签，M2差异另列[MANIFEST](MANIFEST.md)。bit、证据和变化源码复制后逐字节核验，无文件哈希。用户个人记录909字节与初始副本一致，不纳入提交。

冻结日志位于validation/，最终时序/面积及构建配置位于reports/。复现步骤见[M3验证](../../../diagnostics/publicity_mode/M3_VALIDATION.md)，一律使用新RunName/BuildName，Python用py -I -X utf8；不得覆盖本候选或历史输出。
