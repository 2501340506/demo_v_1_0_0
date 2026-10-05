# v0.3.0-s1-local.1 — 控制回归补齐与AUTO到期修复

日期：2026-10-04。分支：`feature/hdmi-audio-v0.3.0`。本地标签：`v0.3.0-s1-local.1`。

**状态：功能回归、TD构建及用户上板验收通过，时序未收敛。** 用户于2026-10-04反馈“S1通过”，板级标签`v0.3.0-s1-board.1`；固定产物不变。S2按计划开始，不以板级通过替代时序收敛结论。

## 问题与修改

模式切换恰逢AUTO计时到期时，原逻辑只在时序块清零计数器，组合自动请求仍有效，可能在同一时钟沿被接受并翻图。现增加mode与mode_seen一致条件，在该接受沿前屏蔽自动请求；AUTO开关保持，随后等待完整间隔再翻图，已挂起的手动请求继续执行。

首次构建发现控制域时序退化，目标图片选择串入了available等请求有效性条件。改为直接根据挂起方向计算target_image，仅在load_request被接受时消费；有效请求的目标和优先级不变。两项RTL修复分别本地提交，没有更改时钟、约束或SDRAM实现。

旧图片测试已适配当前KEY1上一张、KEY2下一张、KEY4切换MAN/AUTO及mode接口；删去当前集成中的旧长短按/组合键场景，原双键路由与手势模块仍保留独立兼容单测。旧手势测试中播放控制器的mode明确接0，避免悬空输入。

## 仿真证据

- [修复前失败](expiry_before_fix.log)：在S0原RTL上，新播放控制测试报`mode change must suppress expiry before acceptance`。
- [图片集成](tb_picture_requests.log)：14组PASS，覆盖首图失败重试、方向请求合并与优先级、四图循环、连续加载、错误图头恢复、延迟SDRAM完成、方向长按不连发、非图片模式限制、KEY4、同拍事件竞争及延迟显示交接。
- [播放控制专项](tb_media_player_control.log)检查请求被接受前的模式/到期冲突；图片集成再使用自然计时到期验证没有实际加载，并等待完整间隔后恢复AUTO。
- [三键](tb_mode_key_control.log)、[显示](tb_media_display_control.log)、[面板](mode_panel.log)通过；[旧双键路由](tb_dual_key_event_router.log)和[旧手势](tb_key_gesture_control.log)仅代表保留模块兼容单测。
- 三组异步缓冲均通过：PIX_HALF/SOURCE_GAP为17/2、19/16、23/64，分别读取21、75、219帧，各加载18次；均无旧缓冲写入、无混合帧。日志：[17/2](buffer_handoff_17_2.log)、[19/16](buffer_handoff_19_16.log)、[23/64](buffer_handoff_23_64.log)。
- 共六个控制测试、一个面板测试、三组异步缓冲运行；编译和仿真均0 errors、0 warnings。上面的修复前失败日志是预期对照，不属于通过集合。

复现命令（仓库根目录，PowerShell）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/history/v0.3.0/run_control_tests.ps1 -Prefix audio_s1_final
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/history/v0.3.0/run_mode_tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/history/v0.3.0/run_buffer_handoff.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_td_build.ps1 -BuildName audio_s1_final
```

控制与缓冲编译/运行完整输出：[控制](control_compile_and_run.log)、[缓冲](handoff_compile_and_run.log)。图片测试使用真实应用控制和BMP解析、模拟SD扇区及写应答；异步测试模拟FIFO/SDRAM数据口，不代表物理SDRAM、SPI电气或完整HDMI协议验证。

## 构建与时序

固定上板文件：[demo.bit](demo.bit)，629624字节；与2026-10-04 20:30:47生成的文件逐字节比对一致。构建开始20:29:36，均为北京时间。器件EG4S20BG256、顶层top；TD 6.2.168116、ModelSim 10.6e。

[综合日志](build_syn_1.log)、[布局布线和bitgen日志](build_phy_1.log)、[时序状态](demo_phy.ts)、[完整时序](demo_pr.timing)、[资源](demo_phy.area)。本目录demo.al、两份prj及settings.cfg是清单快照，复现使用仓库脚本。

| 指标 | S0 | S1最终构建 |
|---|---|---|
| 全局Setup WNS / TNS | −6.699 / −295.899ns | −6.699 / −296.363ns |
| 全局Hold WNS / TNS | +0.003 / 0ns | +0.003 / 0ns |
| sd_card_clk域Setup WNS | +0.093ns | −0.044ns |
| STA覆盖率 | 95.86% | 95.87% |
| LUT / 寄存器 | 4190 / 3867 | 4229 / 3866 |
| BRAM / PLL | 20 / 3 | 20 / 3 |

**不宣称时序收敛或时序无回退。** S1首次构建控制域−0.677ns的目标选择路径已缩短，最终仍有1条−0.044ns违例：BMP状态到load_sector寄存器使能，6级逻辑、数据延迟9.764ns，其中连线7.347ns。相对S0是新增控制域违例，不能混称旧SDRAM问题；本轮记录并交付功能验收，不扩大为整个读取链路改造。全局旧内存相关负余量也仍存在。首次定位报告见[历史记录](../../../diagnostics/history/2026-10-04/audio_s1_first_build/README.md)。

TD继续有IP端口/位宽/初始化、重复编译顺序、SDRAM位置及局部时钟布线等警告，未放宽约束掩盖问题。

## 用户上板检查

1. 下载本目录demo.bit，复位后确认首图、原测试音和模式显示正常。
2. 00模式KEY1上一张、KEY2下一张，首尾循环；方向键长按只触发一次。快速交替按键后画面和编号一致。
3. KEY4启用AUTO，等待翻图；在约3秒间隔将到时改变SW1/SW2，确认模式改变后重新等待约3秒再加载（总间隔含加载时间）。可多试几次，精确同拍由仿真覆盖，无需人工精确卡时钟。
4. 01/10/11模式方向键不产生新请求，KEY4仍能切换MAN/AUTO；恢复00后正常翻图。
5. 加载期间切回MAN不打断当前加载；复位后恢复MAN。确认图片和原声音没有异常。

请反馈“S1通过”或异常现象。S1修改了RTL，因此按计划等待本阶段上板确认后才推进S2；S0通过不能替代。

## 上传状态

用户已确认S0，板级标签`v0.3.0-s0-board.1`已在本地建立；两次GitHub推送因连接重置/443不可达失败，本机已有代理端口未响应。当前S0、S1均未确认上传成功，未合并main。

网络恢复但S1仍待上板时，只能推送S0节点，不能直接推送当前分支最新提交：

```powershell
git push origin 'refs/tags/v0.3.0-s0-board.1^{}:refs/heads/feature/hdmi-audio-v0.3.0' refs/tags/v0.3.0-s0-local.1 refs/tags/v0.3.0-s0-board.1
```
