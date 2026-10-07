# 优化前基线

bmp_read.v 为本轮开始时的生产源码；demo.al 为已提交的单 PLL 工程清单。

historical_demo_gate.* 和 demo_gate.* 是原工作区历史综合报告（bmp_read 870 LUT）。syn_demo_gate.*、demo_phy.area、demo_pr.timing、build_v053_baseline.log 和 demo.bit 是同参数重建结果：综合 bmp_read 875 LUT、布局 822 LUT，顶层布局 4647 LUT/3412 寄存器。对比采用后者。

TD 参数 high-fanout high / timing ultra / post-place high / 默认 seed；Setup -0.115 ns、Hold +0.004 ns。本基线只作对照，不供上板；不覆盖旧已验收 seed 3 的 I/O 候选。用户 GUI 工程本地备份不纳入发布提交。
