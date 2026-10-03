# 测试入口与验证范围

当前最终验收基线为 **v0.1.8**，四阶段均已通过用户板级功能验收。后续修改及历史时序优化暂停。

## 测试入口

在项目根目录按需执行（本次归档未运行）：

```powershell
./diagnostics/run_control_tests.ps1
./diagnostics/run_buffer_handoff.ps1
./diagnostics/run_buffer_handoff.ps1 -Baseline
```

控制测试覆盖按键事件、长短按、组合键、手动优先、图片请求和显示提示；缓冲交接行为模型检查读侧确认前的缓冲所有权。脚本和 tb_*.sv 保留原路径。

## 固定证据

[最终发布说明](../releases/v0.1.8/README.md)包含 bitstream、构建报告和日志清单。

- tb_*.log：当前控制回归通过日志。
- handoff_*.log：修复后异步行为模型通过日志。
- baseline_*.log：旧控制器对照材料，前两组预期失败、最慢一组通过，不属于当前版本失败结果。
- 行为模型可证明所测场景中缓冲不会提前复用，不能证明厂商 IP 内部时序、真实亚稳态或完整电气行为。
- 板级结论来自用户反馈；Setup WNS -6.699 ns，Hold WNS +0.003 ns，功能验收不代表时序收敛。

## 历史资料与本地目录

- [阶段报告目录](history/2026-10-04/README.md)
- [归档前诊断说明与历史运行方法](history/2026-10-04/DIAGNOSTICS_PROCESS.md)
- [早期诊断过程](../docs/history/2026-10-03/DIAGNOSTICS_HISTORY.md)

modelsim_check/ 保存本地编译库和过程日志；modelsim_work/、modelsim_work_4img/、modelsim_work_delay/ 为旧验证目录。均保持原位且继续忽略，不作为固定发布证据。历史报告原路径保留索引入口，发布目录不变。
