# v0.8.0 四 bank 帧缓存验证

S1 生产顶层仍使用双缓冲；loader/reader 已分离，SDRAM 为原 40 MHz/64 字 burst。四区测试用于证明端点具备四区寻址能力，不代表 S3 缓存调度已经完成。

## 入口

在项目根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/four_bank/run_sim.ps1 -RunName 新名称
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/four_bank/run_handoff.ps1 -RunName 新名称
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/stability/run_regression.ps1 -Stage 新名称
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/four_bank/run_td.ps1 -BuildName 新名称
```

- `run_sim` 使用实际厂商 FIFO、加密 SDRAM 控制器、既有 BL4 命令/DQ 模型和生产视频时序/延迟模块。四区分别写入 640×480 行列图案，通过真实读取的 RGB 总线逐像素比较。覆盖并发读写、刷新、源失败、短帧、活动 burst 取消、FIFO 溢出、停滞、下溢与下帧恢复。
- SDRAM 模型内部下标是物理组织，不能直接拿应用地址索引后断言相等。验证采用控制器读回端到端对比。它是功能模型，不替代器件电气时序或上板。
- 加密控制器不启用 `SIMULATION`，仅外层 sdram 包装器启用以引出模型引脚。ModelSim 保留厂商可选空端口及加密 IP 未定宽常量告警（2685/2718/2121），不隐藏；其他告警和任何 Error/Fatal 失败。
- `run_handoff` 从当前两套 FAT32 交接测试生成只替换连接的副本。原刺激、断言及三组异步时钟/源间隔保持不变；生产顶层不使用测试适配器。生成文件留在本次输出目录。
- 完整 TD 隔离构建复用 v0.7.0 的 high/ultra/high 策略，不写用户 GUI 的运行结果。

## S1 新接口与日志

loader 的 `source_done/source_error` 来自解析器的显式结果；`write_finish` 是内存域成功脉冲，由顶层转换为原有完成 toggle。`error_toggle` 和稳定的 `memory_error` 跨回 SD 域，源解析错误不重复生成内存错误事件。

reader 保持原 read_req/ack/en/data 延迟；`underflow` 是像素域本帧状态，`reader_error` 是内存域本帧状态，下帧 FIFO 重置后清除。下溢后本帧余下像素为黑，行场同步和 DE 不变。

原 UART 事件名称/长度不变，使用 `ERROR` 且 `phase=F` 标识帧存储诊断：

| error | 含义 |
|---|---|
| 1 | 写 FIFO 溢出 |
| 2 | 输入像素数量错误 |
| 3 | 写入停滞 |
| 4 | 有效显示下溢 |
| 5 | 读 FIFO 溢出 |
| 6 | 读返回数量不符 |

写错误进入既有加载失败处理；停滞对应通信停机状态 F，其余写错误对应加载失败 D。读错误上报并在下帧恢复，不改变当前图片编号。事件 15 继续保留给 logger 的 DROP，不复用为新事件。

## 状态

S1 用户已确认功能正常，记录为 `v0.8.0-s1-board.1`。S2 独立缓存控制器仿真和综合通过，接口、验证和运行入口见 [S2 控制器说明](CACHE_CONTROL.md)。S2 不接生产顶层、不生成 bit；上板继续使用 S1 已验收文件，下一阶段为 S3 集成。
