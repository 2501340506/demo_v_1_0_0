# 当前验证状态

更新：2026-10-04。用户已确认S0通过，板级标签`v0.3.0-s0-board.1`。S0上传因GitHub网络连接失败受阻；本地继续S1回归和修复。当前`v0.3.0-s1-local.1`尚待用户上板，S2—S9未开始。[S1产物与证据](../releases/v0.3.0-s1-local.1/README.md)。

S1最终TD综合、布局布线和bitgen通过。Setup WNS −6.699ns、TNS −296.363ns；Hold WNS +0.003ns、TNS 0ns；STA覆盖95.87%。LUT 4229、寄存器3866、BRAM 20、PLL 3。时序未收敛；100MHz控制域仍有1条−0.044ns违例，相对S0的+0.093ns有退化，已单列在候选说明中，不能归为旧SDRAM问题。

本次ModelSim 10.6e测试编译/仿真均0 errors、0 warnings，修复前失败用例单独留作对照，不计入通过集合。

- `run_control_tests.ps1 -Prefix audio_s1_final`：六个测试顶层通过。图片集成已适配三键与mode，14组场景通过；播放控制、三键、显示专项通过。双键路由和旧长短按手势为保留模块兼容单测，不是当前板级交互。
- `run_mode_tests.ps1`：拨码及面板通过。
- `run_buffer_handoff.ps1`：17/2、19/16、23/64三组异步时钟/源速率场景通过，均0次旧缓冲写入、0混合帧。
- 模式变化与AUTO到期同拍：新测试在S0 RTL上失败，修复后专项和图片集成通过；集成同时确认重新等待完整间隔后恢复AUTO。

S1测试补齐了原交接列出的控制/图片/缓冲回归缺口，但使用模拟SD扇区、FIFO和SDRAM数据口，不覆盖完整HDMI、物理SDRAM及板级电气。因S1修改RTL，必须独立上板；不能沿用S0通过结论。未放宽约束，未合并main，S1未上传。

[交接记录](../HANDOFF.md) · [历史资料](history/2026-10-04/MODE_ARCHIVE.md)
