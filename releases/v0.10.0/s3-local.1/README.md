# v0.10.0-s3-local.1：右上角 MM:SS 累计时间

基线为已板测通过的 v0.10.0-s2-board.1。候选 [demo.bit](demo.bit)，按 [上板步骤](BOARD_VALIDATION.md) 验证；S3 尚未板测，不能沿用 S2 的板测结论。

新增 timestamp_osd，共用 OSD 坐标和 5×7 字模。默认在 x=500..579、y=8..23 显示白色 MM:SS，无新增底条；从视频复位释放后每 60 个帧起始事件加一秒，99:59 后归零。BCD 逐位进位，不推导除法硬件，帧中途不变。状态 → 在线字幕 → 时间 → 原底条 → HDMI 音频，保留组合 RGB 零额外延迟。切图/AUTO/字幕更新不重启时间，复位清零。

顶层 TIMESTAMP_ENABLE 默认 1，受 OSD_ENABLE 总开关控制；关闭时 generate 分支只有旁路线。时间按帧数定义，不接 RTC、校时、日期和掉电保存，实际墙钟精度依赖视频帧率。

本地证据：

- 时间专项 `v010_s3_timestamp2`：真实 360,000 个帧事件覆盖完整 100 分钟计数周期、全部进位/回绕、复位、帧内稳定和关闭旁路；3,379,200 像素、3,168 字形像素，所有十进制数字及冒号显示检查，0 Error/Warning。没有强制写计数寄存器。
- 关闭模块独立综合 `v010_s3_disabled1`：0 LUT、0 寄存器、0 BRAM/DSP/PLL，仅 RGB 输入输出旁路；此专项不作为完整工程时序签核。
- 21 项回归 `v010_s3_regression1` 全部通过，各项 0 Error/Warning，包含原 UART 日志、播放控制、SD、启动/复位、HDMI 音频及视频对齐。
- 真实 FAT32/BMP/SDRAM/FIFO 联合仿真 `v010_s3_system2` 通过：57 个显示帧、22 次图片提交与 22 次音频提示，4 组 UART 配置帧提交；时间层 62 个帧事件、26,039,248 像素/消隐检查、19,732 字形像素，与状态/滚动/底条同时开启。0 Error，18 条既有 IP/模型及测试台可选端口警告。
- 完整 TD `v010_s3_attempt1`：Setup **+0.102 ns**、Hold **+0.019 ns**，STA 覆盖率 **99.96%**；11,748 LUT、6,637 寄存器，较 S2 -98/-8（全工程综合/物理优化后的净变化，并非时间模块自身资源为负）。4 BRAM、2 DSP、1 PLL 不变。

时序约束未修改。check_timing 分类与 S2 一致：no clock、invalid constraint、combinational loop、no path constraint、ignored exception 为 0；dummy node 4、PLL/clock buffer 1、no input delay 9、no output delay 16、abnormal input delay 1。保留 SDRAM ECO 位置调整及 ext_mem_clk_sft 到 SDRAM_CLK 单条局部布线警告，不声称零工具警告或板级时序已验证。

第一轮系统脚本遗漏 OSD_TIMESTAMP 宏，只验证了 S2 链路，不能作为 S3 联合验收。脚本已修正，并强制检查时间层观测和 4 组 UART 帧提交标记；第一轮输出保留 diagnostics/output/v010_s3_system1，不归档为 S3 通过证据。

生产变化仅 timestamp_osd、顶层连接/参数和 TD 工程文件。归档源码按用户计划保存相对 v0.9.1 的累计变更，未改文件引用该基线；本阶段基线为 S2 board.1。构建输入与固定 bit 的逐字节核对见 [清单](SOURCE_MANIFEST.md)。

阶段回退：[S2 已验收 bit](../s2-local.1/demo.bit)；总回退：[v0.9.1](../../v0.9.1/demo.bit)。S2 验收及 HEX 发送模式边界见 [板测记录](../S2_BOARD_RESULT.md)。S3 板测确认后建立 board 标签，再正式归档 v0.10.0，当前不合并 main。
