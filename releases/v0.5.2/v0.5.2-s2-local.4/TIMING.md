# local.4 最终时序

TD 6.2.1，最终构建 `v052_s2_local4_final`，报告时间 2026-10-06 18:51:58。沿用 high fanout / timing ultra / post-place high，时钟和 SDC 不变。

|指标|结果|
|---|---|
|SD 域内部 setup WNS|+0.110 ns|
|内存域内部 setup WNS|+0.495 ns|
|全局 hold WNS / TNS|+0.018 / 0.000 ns|
|全局 setup WNS / TNS|−6.565 / −250.777 ns|
|SDRAM 硬核边界 setup 负端点|64（两个方向各 32）|
|其他 setup / hold 负端点|0 / 0|

首次构建出现的三条 SD 内部负路径已消除。没有增加时序例外或降低不确定性。硬核边界仍不收敛，不能将本候选描述为全局时序通过；原始报告随候选保留，板测另行确认。
