# v0.11.0 S1 验证入口

生产默认 TRANSITION_ENABLE=1，独立 sd_card_bmp 默认 0。每侧 16 个真实视频帧，像素域 level 0..16；OSD 在转场之后叠加。控制域收到目标 bank 就绪后发 start toggle，像素域到黑后返回 black toggle，原适配器才发读端提交。真实 reader ack 不延迟；原音频 CDC 的 media_update 使像素状态机开始等待下一帧淡入。done toggle 释放整个事务。

## 复现命令

每次使用新的输出名，保留旧结果。以下从项目根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File diagnostics/transitions/run_unit.ps1 -RunName transition_s1_unit1
powershell -ExecutionPolicy Bypass -File diagnostics/transitions/run_player.ps1 -RunName transition_s1_player1
powershell -ExecutionPolicy Bypass -File diagnostics/four_bank/run_regression.ps1 -RunName transition_s1_regression1
powershell -ExecutionPolicy Bypass -File diagnostics/four_bank/run_system.ps1 -RunName transition_cache_bypass1
powershell -ExecutionPolicy Bypass -File diagnostics/transitions/run_system.ps1 -RunName transition_s1_full2
powershell -ExecutionPolicy Bypass -File diagnostics/osd/run_td.ps1 -BuildName transition_s1_attempt2 -TimingOptimization high
powershell -ExecutionPolicy Bypass -File diagnostics/four_bank/audit_timing.ps1 -BuildName transition_s1_attempt2
```

## 证据范围

- unit：独立异步控制器+生产像素模块，3 次实际握手，延迟提交、复位后再次启动、旁路、首图不转场，27,648 个 RGB 结果核对；进度只在帧边界变化。
- player：真实播放器+转场协调器，读端确认用协议模型；验证忙时 next/previous 各一项、同方向合并、相对已提交图号计算、AUTO 停止计数及重新等待完整间隔，5 次提交。此项不代替真实 SDRAM 验证。
- regression：原 21 项控制、音频、SD、启动、缓存和视频对齐测试。
- bypass：关闭转场的完整 FAT32/BMP、FIFO、SDRAM 控制器与 DQ 模型，57 帧、22 次提交/提示音；它只证明关闭模式保持旧行为。
- full2：显式启用 16 帧转场与状态/滚动/时间/底条/UART，原始 reader RGB 和最终转场 RGB 分别逐像素检查；另核对许可只在黑场、忙时不接受新前台请求、重扫不穿过活动转场、独立亮度参考、音频提交数量。使用真实 SDRAM，SPI 引脚层由回归单独覆盖。
- TD：全工程综合、布局布线、约束检查及 bit；生成 bit 与时序通过是不同条件。候选包装前比较所有工程输入与构建快照的实际字节。

## 已遇失败与修正

- 前序提交仅做编译检查，错误地把 permit 接在 cache_display_ack；实际读 bank 仍提前切换。现改为许可控制请求，真实确认直接返回。原多位亮度跨域已去掉，进度只在像素域维护。
- transition_cache_system1 缺新模块编译；system2 未连新端口且发现像素与缓存所述 bank 不一致。均不是通过证据。
- transition_s1_full1 的旧测试等待已在淡入前发生的 load_start；修正为启用效果时等待缓存完成，full1 由本任务主动停止，保留输出。full2 为修正后的完整用例。
- transition_s1_attempt1 生成 bit，但 Setup −0.087 ns / Hold +0.030 ns；违例在 UART 字幕解析到配置寄存器，视频转场路径有余量。该输出不交付。attempt2 只调整布局优化选项，不放宽时序约束，结果以实际报告为准。
- 课程与旧测试中的默认“米醋…”字幕已被用户后续提交替换；本次使用当前“胆子肥嘟嘟的”及扩展字模。

当前执行状态以根 HANDOFF 和实际运行日志为准；本文件描述覆盖范围，不把运行中的测试或 TD 写为已通过。
