# v0.5.1 S2 SDRAM 路径审计

状态：审计进行中。当前基线控制回归仍有 `tb_picture_requests` 的既有失败，因此本阶段暂不修改 RTL 或放宽约束。

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

## 门禁

完成上述核对并恢复基线控制回归后，才进入 S3。S2 不新增 `set_false_path`、`set_max_delay` 或 `set_clock_uncertainty`，不生成新的 Flash bit。
