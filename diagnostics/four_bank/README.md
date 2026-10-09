# v0.8.0 四 bank 帧缓存验证

S3 已接入生产四 bank 缓存，固定候选见 [S3 local.1](../../releases/v0.8.0/s3-local.1/README.md)。SDRAM 仍为 40 MHz/64 字 burst。S1 读写分离、S2 独立控制器的历史证据保留；它们不替代 S3 集成验证。

## 入口

在项目根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/four_bank/run_sim.ps1 -RunName 新名称
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/four_bank/run_system.ps1 -RunName 新名称
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/four_bank/run_regression.ps1 -RunName 新名称
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/fat32/run_reader.ps1 -RunName 新名称
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/four_bank/run_td.ps1 -BuildName 新名称
```

- `run_sim` 使用实际厂商 FIFO、加密 SDRAM 控制器、既有 BL4 命令/DQ 模型和生产视频时序/延迟模块。四区分别写入 640×480 行列图案，通过真实读取的 RGB 总线逐像素比较。覆盖并发读写、刷新、源失败、短帧、活动 burst 取消、FIFO 溢出、停滞、下溢与下帧恢复。
- SDRAM 模型内部下标是物理组织，不能直接拿应用地址索引后断言相等。验证采用控制器读回端到端对比。它是功能模型，不替代器件电气时序或上板。
- 加密控制器不启用 `SIMULATION`，仅外层 sdram 包装器启用以引出模型引脚。ModelSim 保留厂商可选空端口及加密 IP 未定宽常量告警（2685/2718/2121），不隐藏；其他告警和任何 Error/Fatal 失败。
- `run_system` 连接生产应用、FAT32/BMP、厂商 FIFO、真实 SDRAM 控制器和物理模型，逐像素验证显示，同时检查缓存事务、重扫与真实音频 CDC/提示音。卡端使用扇区服务模型，真实 SPI 协议由相关回归覆盖。
- `run_regression` 使用新的独立输出目录，运行 21 项现有按键/播放器/面板/HDMI/音频/SD/启动/复位测试。启动测试改为观察新扫描状态，UART 测试增加两个缓存事件，原断言保留。
- `run_handoff` / `prepare_handoff` 是 S1 的双缓冲历史入口，仅适用于 S1 源码。S3 不再使用旧的双缓冲重读次数断言，以 `run_system` 中四图驻留、命中不读卡及重扫保图断言替代；原测试文件不删除。
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

S1 已上板验收，S2 独立阶段已完成。S3 本地集成、相关回归和 TD 通过，Setup +0.126 ns、Hold +0.003 ns，等待用户板测。S4 尚未开始。
