# S1首次构建时序定位记录

2026-10-04。这是调试证据，不是上板候选；最终产物见[正式S1候选目录](../../../../releases/v0.3.0/v0.3.0-s1-local.1/README.md)。

首次修复在自动请求输出增加mode与mode_seen一致条件，功能回归通过，TD综合/布局布线/bitgen完成。报告：[完整时序](demo_pr.timing)、[状态](demo_phy.ts)。

- 全局Setup WNS −6.699ns、TNS −301.585ns，Hold WNS +0.011ns。
- sd_card_clk域从S0的+0.093ns降为−0.677ns，新违例不能算作旧SDRAM问题。
- 最差路径为img_found_count经available、previous_load_request、目标图片选择至load_sector，目标选择掺入请求有效性形成额外逻辑层级。
- 后续将target_image的方向选择条件改为`!next_pending && previous_pending`。目标仅在load_request有效且被接受时消费，此时与原选择等价；空闲时的目标值不构成请求。
- 没有修改时钟频率、SDC例外或SDRAM链路。完成回归后重新构建并以最终报告验收。
