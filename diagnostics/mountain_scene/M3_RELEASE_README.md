# v0.17.0 M3 local.1：灾害图层候选

本候选在SDRAM读出后、亮度/对比度之前加入灾害图层。使用M2示意村卡，可看到裂缝增长、沟谷覆盖、撤离路线及高地避险点闪烁。24bpp图片和缩放黑边的T=255不着色；缩略图模式旁路。M3临时时间源按每两帧推进一步，0–239循环，切图和退出预览后重置；尚未接入M4音频驱动FSM。

- 分支：`feature/mountain-escape-classroom`；标签：`v0.17.0-m3-local.1`。正式版仍为v0.16.0。
- 上板只用本目录 [demo.bit](demo.bit)，664544字节，与TD attempt02逐字节一致。
- 资源：14520 LUT（74.08%）、8439寄存器、56 BRAM9k、0 BRAM32k、13 DSP。相对M1增加162 LUT、165寄存器，BRAM/DSP不变；相对v0.16.0增加330 LUT、189寄存器、2 BRAM9k。
- 时序：Setup +0.104ns、Hold +0.011ns，TNS均0；104个实际工程输入逐字节核对，时序审计类别/异常汇总与M1一致。
- 验证：[VALIDATION.md](VALIDATION.md)、[MANIFEST.md](MANIFEST.md)、原始仿真和构建报告。
- 板测：[BOARD_VALIDATION.md](BOARD_VALIDATION.md)；场景图与参考图位于 [board_samples](board_samples)，只把PIC1–4.BMP复制到FAT32卡根目录，换卡后复位。

输入基线为 `v0.17.0-m1-local.1`（像素通路）及3535c0b（M2工具/素材）。本阶段仅保存相对M1变化的top、两个scene模块及demo.al，其他工程输入通过M1引用。两级图层流水同时延迟RGB和同步/坐标/转场/预览状态；T通过32位video_delay与RGB同拍到达。

M1板测及M2用户目视仍无确认反馈。本次按用户后续“执行M3”指令先推进本地实现，**不代表M1或M3板测通过**；未建立board标签、未推送。已板测整机回退仍为 [v0.16.0 bit](../../v0.16.0/demo.bit)，不是尚未验收的M1。用户确认具体候选后再记录实际板测范围与推送，不倒填其他候选的结论。

已知限制：SD专项为扇区服务模型，仿真不能替代真实卡/板/HDMI测试；Hold余量11ps，保留基线I/O延迟约束提示；受保护IP、可选端口、PLL模型宽度、glbl重定义等旧工具告警如实保留。M3临时源可由 `SCENE_DEMO_ENABLE` 关闭，关闭后固定两拍流水仍保留；M4–M6未实施。若板测失败，保留本候选，修复后建立递增local候选。
