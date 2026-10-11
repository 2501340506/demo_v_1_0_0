# S2：AUTO 黑底水平揭示

基线 v0.11.0-s1-board.1，用户于 2026-10-11 确认“功能均正常”。S1 原 bit 不重建，作为阶段回退。

## 改动

控制域在播放器请求被缓存实际接受时锁存 AUTO 来源，不能在转场开始时看当前 AUTO 开关或待处理按键猜来源。协调器接受已就绪显示事务时再次锁存来源位，与 request toggle 同时发出，保持到 done 返回；像素域在请求同步后采样这个稳定数据。首图/重扫首图继续旁路。

手动：16 帧淡出 → 黑场提交 → 16 帧淡入。AUTO：同样淡出和提交，恢复阶段每帧增加 40 列，左侧显示原亮度新图，右侧为黑；最后完整显示 640 列。wipe_active 和 level 在像素域帧边界更新，OSD 仍在效果之后叠加。没有额外 SDRAM 读取、没有旧图背景混合。

## 验证入口

从项目根目录执行，重复运行使用新名字以保留证据：

```powershell
powershell -ExecutionPolicy Bypass -File diagnostics/transitions/run_wipe.ps1 -RunName transition_s2_wipe1
powershell -ExecutionPolicy Bypass -File diagnostics/transitions/run_unit.ps1 -RunName transition_s2_fade1
powershell -ExecutionPolicy Bypass -File diagnostics/transitions/run_player.ps1 -RunName transition_s2_player1
powershell -ExecutionPolicy Bypass -File diagnostics/four_bank/run_regression.ps1 -RunName transition_s2_regression1
powershell -ExecutionPolicy Bypass -File diagnostics/transitions/run_system.ps1 -RunName transition_s2_full1
powershell -ExecutionPolicy Bypass -File diagnostics/osd/run_td.ps1 -BuildName transition_s2_attempt1 -TimingOptimization high
```

wipe 专项覆盖 95,200 次像素检查：进度 0..16、横坐标 0..799、有效区与消隐、AUTO→手动→AUTO、请求接受后输入来源变化不能影响当前效果、黑场保持、最后一列。fade 专项继续验证原亮度端点/复位/旁路；player 专项继续验证方向 pending 和 AUTO 完整计时间隔。

full1 显式启用效果、全部 OSD/UART/时间与真实 SDRAM，独立捕获播放器接受事件的来源；检查实际 wipe_active 与来源一致、亮度/遮罩只按帧更新，逐像素核对遮罩、原 reader 数据和 OSD 合成。要求至少 2 次 AUTO 揭示、10 次手动淡入，保留重扫、失败重试及超时后缓存切图场景。最终通过状态以日志及候选说明为准。

完整 TD 必须通过实际 routed Setup/Hold，约束审计与源码快照核对后才固定候选。S2 尚未板测，不继承 S1 的硬件通过结论。
