# v0.5.1 S2 SDRAM 路径审计

状态：完成。当前阶段未修改 RTL 或放宽约束。

## 已确认

- 当前工程使用 `sys_pll_m0` 产生 `sd_card_clk`、`ext_mem_clk`、`ext_mem_clk_sft`，使用 `video_pll_m0` 产生 `video_clk` 和 `hdmi_5x_clk`。
- `timing.sdc` 已创建输入时钟并通过 `derive_clocks`/`rename_clock` 命名 PLL 输出。
- 当前约束明确保留像素与串行时钟的并行时序分析，没有恢复课程示例的 exclusive 时钟组。
- 现有报告中的 64 个 SDRAM 接口负端点应视为硬核接口/厂商模型相关问题，不能直接通过 `false_path` 删除。
- 板级输入输出延迟尚未完整定义；需要以器件、板卡和接口资料为依据，不能凭课程示例猜测。

## 待核对

1. TD 报告中 64 个负端点的起点、终点、时钟对和是否全部落在 SDRAM 硬核边界。
2. `ext_mem_clk` 与 `ext_mem_clk_sft` 的真实相位、SDRAM IP 要求和现有 SDC 的采样关系。
3. SDRAM 端口是否由厂商硬核自动携带 I/O window；若是，应记录为工具/IP 约束边界。
4. 其余 3 个内存内部负路径的 RTL 层级和是否属于可安全分拍的 fabric 路径。

## v0.5.1 S2 构建结果

使用固定参数 `HighFanoutOptimization`、`opt_timing ultra`、`post_place_opt high` 完成 TD 综合、布局布线和 bitgen。报告位于 `TD_project/demo_Runs/phy_1/final_timing.rpt`，构建日志为 `build_v0.5.1_s2_audit.log`。

- 全局 Setup WNS −6.565 ns、TNS −251.158 ns、67 个负端点；Hold WNS +0.003 ns、无 Hold 负端点。
- 内存内部路径组为 3 个负端点，Setup WNS −0.084 ns、TNS −0.114 ns。
- 代表性路径一：`frame_read_write_m0/write_buf/rd_addr_reg[4]` → `frame_read_write_m0/frame_fifo_read_m0/state_reg[5]`，同属 `ext_mem_clk`，经过 `frame_fifo_write` 的 `rdusedw`、突发计数和状态逻辑。
- 代表性路径二：`frame_read_write_m0/write_buf/rd_addr_reg[4]` → `frame_read_write_m0/write_buf/ram_inst/ramread0_syn_25.addrb[4]`，同属 `ext_mem_clk`，经过异步 FIFO 读地址逻辑。
- SDRAM 硬核相关时钟为 `U3/u2_ram/SDRAM_CLK` 和 `U3/u2_ram/u1_init_ref/Sdr_clk`，均由 `sys_pll_m0` 输出并由 TD 识别为时钟网。
- 64 个 SDRAM 接口负端点仍属于硬核/IP 边界，当前资料不足以安全添加例外或 I/O delay。

## 门禁

S2 不新增 `set_false_path`、`set_max_delay` 或 `set_clock_uncertainty`，不生成用于上板的 Flash bit。下一阶段只处理上述 3 个 fabric 内部端点中的一个路径组，并在修改前建立专项仿真。

## S3 结果

S3 在 `frame_fifo_write` 中对 FIFO `rdusedw` 做本域寄存器采样，再由采样值参与 `into_burst` 判断。ModelSim 八个回归入口全部通过；TD 综合、布局布线和 bitgen 通过。全局 Setup WNS 保持 −6.565 ns，TNS 从 −251.158 ns 改善为 −249.902 ns，负端点从 67 降为 64；Hold WNS 为 +0.037 ns。该阶段未修改 SDRAM 硬核约束，也未进行 Flash 上板。
