# v0.5.1 S0/S1 基线

基于 v0.5.0 已验收工程。生产 RTL、TD 工程和 `user_source/constraints_source/timing.sdc` 暂不修改。现有基线报告为 Setup WNS −6.565 ns、TNS −251.158 ns、Hold +0.003 ns；67 个负端点中 64 个位于 SDRAM 接口、3 个位于内存内部路径。

课程复位示例仅作为审计参考。当前工程继续使用双 PLL、125 MHz 内存、五域三拍高有效复位和 SDRAM 就绪同步。ModelSim 的 PLL、FIFO、存储模型不能替代物理时序或 Flash 电气验证。

S0/S1 不产生新 bit；后续阶段必须在本文件所述基线之上逐项比较。
