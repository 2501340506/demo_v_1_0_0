# M3 灾害图层实现与验证入口

基线为M1像素通路 `v0.17.0-m1-local.1`，M2素材为3535c0b，功能基线与已板测整机回退仍为v0.16.0。用户在M1板测和M2目视尚未反馈时明确要求执行M3，因此先完成本地实现，不推定前序板测通过，也不建立board标签。

## 生产改动

- `scene/hazard_layer.v`：M2参考模型v1的两拍实现，支持0–239到达时刻、250避险点、保留编码/255旁路、缩略图旁路。完整加法后右移，每通道保留9/10位中间和，无新增DSP或RAM。48位同步/坐标/预览描述/转场/有效状态与RGB同延迟。
- `scene/scene_demo_timing.v`：仅M3使用。像素域复用media_commit_cdc输出，首有效像素选择当帧阶段/时间，随后保持；每两帧t+1，239循环至0，切图/退出预览重置。快相位模240、步长8/16/24/32，慢相位步长4；约60Hz时快闪2/4/6/8Hz，慢闪1Hz。
- `top_tf_hdmi_audio.v`：video_delay改为32位以保持RGB/T对齐，灾害层插在亮度/对比度前。`SCENE_DEMO_ENABLE=1` 为M3默认，可设0关闭临时源；关闭后仍保留固定两拍流水。M4替换为音频样本驱动FSM。
- `TD_project/demo.al`：只增加两个scene源码条目，保留用户原工程内容。没有覆盖best_result或旧候选。

## 可重复运行入口

在仓库根目录使用新输出目录：

```powershell
& diagnostics/mountain_scene/run_m3_unit.ps1 -RunName mountain_m3_unit_new
& diagnostics/mountain_scene/run_m3_top.ps1 -RunName mountain_m3_top_new
& diagnostics/mountain_scene/run_legacy.ps1 -Suite hazard_system -RunName mountain_m3_memory_new
& diagnostics/mountain_scene/run_legacy.ps1 -Suite pcm -RunName mountain_m3_pcm_new
& diagnostics/mountain_scene/run_legacy.ps1 -Suite preview -RunName mountain_m3_preview_new -Mixed 1 -Audio -Failures
& diagnostics/mountain_scene/run_legacy.ps1 -Suite system -RunName mountain_m3_system_new
& diagnostics/mountain_scene/build_m3.ps1 -BuildName mountain_scene_m3_new
& diagnostics/mountain_scene/run_legacy.ps1 -Suite audit -RunName mountain_scene_m3_new
```

工具为ModelSim SE-64 10.6e（F:/modelsim/win64）、TD v6.2（E:/TD）。Python用 `py -I`。构建输入快照只在diagnostics/output；打包前须检查完整报告、更新m3_logs.json为实际通过的运行，再用package_m3.py核对和固定候选。打包器拒绝非正Setup/Hold、未完成日志、未知告警和工程输入不一致。

## 覆盖与实际限制

单位测试直接读取已固定的M2 BMP和24张expected PNG，导出原始像素后输入RTL，**不在导出时重算expected**。另用独立标量运算覆盖所有256个T、0/5/6/120/239、四种快慢相位、旁路和复位；每拍核对随行信号两拍延迟。

生产顶层测试复用旧调节/音频注入边界，增加T、四阶段与保留编码；核对新增两拍后的RGB、hs/vs/de/x，覆盖调节、预览焦点/空格、黑屏、转场和静音。真实SDRAM测试经过FAT32、缩放、FIFO、受保护控制器、command/DQ存储模型和32位video_delay后再比较灾害层。两者互补，顶层注入测试不能单独替代存储链路验证。

完整系统和预览测试沿用既有装配台，验证旧缓存/转场/OSD/UART/PCM行为；它们本身不实例化生产top的新灾害层，灾害层接线由上述顶层和SDRAM专项覆盖。未修改BMP加载和缩放RTL，因此复用M1的格式故障矩阵，M3重新运行受影响整合路径与PCM预览重扫；未将旧日志伪装为M3重测。

保留已知IP可选端口及受保护模型告警；生产顶层的PLL load_reg宽度提示和glbl重定义提示与旧顶层仿真相同。打包器按具体类别/位置审核，原日志不清洗。PowerShell产生的UTF-16日志按BOM读取。

早期调试失败保留在diagnostics/output：unit01是测试台在first_active尚未撤销时采样“下一状态”；unit02/03是ModelSim字符串补空格导致打不开向量；unit04是测试台复位后留了旧side输入。memory01为测试台信号前向隐式声明和显式声明重复。修正测试台后unit05及memory02通过，不能引用失败运行作为验收。

TD attempt01功能源码与首轮仿真一致，bitgen结束但Setup −0.212ns、Hold +0.030ns，14574 LUT/56 BRAM9k/13 DSP；违例为SD缓存image_count到bank_map路径。该次不作为候选；保留报告，后续调整布局时序优化设置，以最终通过报告为准。完整候选的实际资源、运行统计和板测状态另记录于release的VALIDATION。

attempt02保持相同功能源码，使用HighFanoutOptimization、placement strategy5、timing optimization high、drHoldFix on。最终14520 LUT、8439寄存器、56 BRAM9k、0 BRAM32k、13 DSP，Setup +0.104ns、Hold +0.011ns，TNS均0；104个工程输入与当前源码逐字节一致，bit为664544字节；时序审计类别和异常汇总与M1相同。只有全套日志完成审核后才打包。
