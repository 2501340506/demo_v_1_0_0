# S1 验证

本轮 45 份仿真日志及编译/模型日志逐份核验，实际清单在 validation/results.json。四类图层 192 帧/58982400 像素、1228800 扫描向量，旧图层/旁带随机 10000 像素通过。16 张图与移植包及卡逐字节一致。类型、失败保持及垂直消隐身份提交通过。

生产 top 双应用最终像素、TMDS/时序、状态栏、真实 PCM 宣传音频、旧场景与 M6 FONT/TEXT/HDMI，以及参数、阶段、速度、预警、预览、恢复和跨域握手通过。使用真实解码及 SDRAM/音频模型；实际电视、板级 SD/音频和持续运行待验收。

TD attempt02 当前 113 工程输入及根构建脚本与隔离快照逐字节一致。PlaceStrategy3/seed12/HighPlaceEffort/HighAreaOptimization；Setup/Hold 正，两项 TNS0。check_timing 无缺失时钟、无效约束、组合环。保留既有 dummy4、9 input/17 output 无 IO delay 及 sd_miso 21ns max 例外，STA 99.98%，不宣称全 IO 覆盖。

新增八条 SYN5011 为移植 palette ROM 未使用 addrb[0..6]/bea[0]，无新增 PHY 告警；见 reports/audit_review.json。attempt01 布线失败留在诊断，不是候选。bit、报告和变化源逐字节复制固定。
