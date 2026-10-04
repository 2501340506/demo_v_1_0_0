# 当前验证状态

更新：2026-10-04。音频升级S0（本地`v0.3.0-s0-local.1`、板级`v0.3.0-s0-board.1`）TD综合、布局布线和bitgen通过；拨码/面板专项重新运行通过，编译和仿真均0 errors、0 warnings。用户已反馈“S0通过”，记录并推送后开始S1；S2—S9未开始。[产物和本次证据](../releases/v0.3.0-s0-local.1/README.md)。

本次Setup WNS −6.699ns、TNS −295.899ns；Hold WNS +0.003ns、TNS 0ns；STA覆盖95.86%，时序未收敛。LUT 4190、寄存器3867、BRAM 20、PLL 3。

此前v0.2.0模式功能阶段1至3已有用户板级确认；模式、按键、播放控制器专项仿真和TD构建有历史通过记录。完整集成回归尚未补齐，不能沿用旧板级确认代替S0候选验收。

- `run_mode_tests.ps1` 覆盖拨码及面板。
- `tb_mode_key_control` 和 `tb_media_player_control` 有专项通过记录，不能替代集成测试。
- `tb_picture_requests.sv` 仍引用旧按键端口、已移除参数和旧实例，`run_control_tests.ps1` 不能作为当前全套通过证据。
- 本轮模式功能开发没有重新执行异步双缓冲回归的记录。
- 模式改变恰逢AUTO到期需补测：计数在时序块清零，但自动请求组合逻辑未屏蔽模式变化，同拍行为不能宣称已经验证。

S0未修改RTL和已有测试逻辑，新增TD构建脚本，重新生成并固定bitstream。上述缺口在S1补齐，不把面板专项结果扩大为完整回归通过；本轮不自动合并main。

[交接记录](../HANDOFF.md) · [历史资料](history/2026-10-04/MODE_ARCHIVE.md)
