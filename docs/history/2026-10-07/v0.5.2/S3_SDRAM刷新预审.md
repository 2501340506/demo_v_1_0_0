# S3 SDRAM 刷新预审（2026-10-06）

状态：仅完成源码与表达式预审，未修改生产 RTL，未形成 S3 候选。

## 已复现的问题

生产工程 `TD_project/demo.al` 引用 `include/global_def.v`、`sdr_as_ram.enc.v` 和 `sdr_init_ref.enc.v`。

`SDR_CLK_PERIOD` 定义为无括号的 `1000000000/125000000`，嵌入 `64000000/SDR_CLK_PERIOD/2**ROW_WIDTH` 后，连续整数除法使刷新宏计算为 0，而非预期的 3906。

ModelSim 10.6e 直接包含生产头文件的表达式测试输出：

```text
CURRENT period_ns=8 refresh_macro=0
TARGET period_ns=25 max_refresh_cycles=1250
CURRENT request_compare=-10
Errors: 0, Warnings: 0
```

本地证据：`diagnostics/output/s3_pll/tb_s3_refresh_expression.sv`、`refresh_expression.log`。这证明宏表达式问题，不代替硬核实际命令观测。

## S3 必须继续核对

- 周期和刷新公式都应括号化。40 MHz 周期 25 ns，2048 行、64 ms 窗口对应每行最多 1250 周期。
- `sdr_init_ref.enc.v` 中计数从 0 到终值后归零，周期为终值加 1；直接把终值设为 1250 会得到 1251 周期。
- 当前提前 10 周期提出请求，实际刷新还依赖应答及读写排空。必须通过真实控制器与 SDRAM 命令观测核实最迟服务时间，不能只修终值后就宣称每行间隔满足。
- `pwr_200ms_cnt[17]` 实际等候 131072 周期，40 MHz 下为 3.2768 ms（另有流水延迟），变量名不代表真实 200 ms。初始化及最小命令间隔仍需结合模型核对。
- 控制器部分实现受工具加密保护，使用已有 ModelSim 支持的模型验证其外部命令及数据行为，不根据不可见逻辑猜测时序。
- 现有 `tb_pixel_handoff.sv` 使用 32×32 图片和约 71.4 MHz 内存行为模型；现有回归通过不足以证明 640×480、40 MHz、真实刷新竞争下无空读。S3 仍需计划所要求的完整帧、FIFO 空读及竞争验证。

本预审不改变 S2 已完成板级验收事实，也不构成 S3 或 S4 验收。
