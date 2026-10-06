# local.5 时序摘要

TD 6.2.1，构建 `v052_s2_local5`，报告时间 2026-10-06 19:29:40。high fanout / timing ultra / post-place high，原时钟及 SDC 不变。

|指标|结果|
|---|---|
|SD 内部 setup WNS|+0.108 ns|
|内存内部 setup WNS|+0.391 ns|
|全局 hold WNS / TNS|+0.025 / 0.000 ns|
|全局 setup WNS / TNS|−6.565 / −250.963 ns|
|SDRAM 硬核边界 setup 负端点|64（两个方向各 32）|
|其他 setup / hold 负端点|0 / 0|

内部路径无负端点，既有硬核边界仍未收敛，不宣称全局时序通过。未增加例外、未降低不确定性。bit 629624 字节，与本次最终构建输出逐字节一致。
