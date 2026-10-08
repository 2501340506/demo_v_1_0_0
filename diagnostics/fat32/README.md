# FAT32 升级验证入口

S3 已接入生产并完成本地验证，固定候选待上板。run_core.ps1 验证 42 个核心场景；run_s3.ps1 运行包装器和受影响系统回归共 16 个入口。S3 TD 使用 run_td.ps1 -BuildName 新目录名 -PostPlaceOptimization high。见 [S3 验证](../../docs/fat32_s3_validation.md)。以下 S1 入口保留为历史工具，当前生产验收使用 run_s3.ps1。

从本分支工作区根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/fat32/run_sector.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/fat32/run_s1.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/fat32/run_td.ps1 -BuildName fat32_s1_new_build
```

`run_sector` 覆盖字节顺序和索引、分离的完成事件、读失败/超时、长度错误及下一次请求；实际 sd_card_top 协议链路测试只在 SPI 字节边界模拟卡，验证 CMD17 拒绝、CRC 失败和成功读取后不会多发读命令。

`run_s1` 顺序运行专项、真实像素/重扫异步交接、恢复/超时、SD 协议、UART 逐字节接收、八项系统回归及上电就绪握手。日志在 diagnostics/output/ 下，测试库互相隔离。已有 BMP 独立解码器的 S0 基线通过记录另见 docs/fat32_validation.md。

`run_td` 从当前分支工程清单创建全新隔离快照，默认使用高扇出优化、ultra timing 和 ultra post-place，检查完整 bitgen 及最终 Setup/Hold；负裕量直接报错，不作为候选。每次构建必须提供新目录名。

## 扇区接口约定

- 在 `sector_busy=0` 时提交一个时钟周期的 req，LBA 当拍锁存。
- 每个 valid 表示一个字节，索引从 0 开始；数据、valid、index 在适配器输出同步寄存一拍。实际 SD 驱动字节速率保持不变，不引入高速回放。
- done 为一个周期，晚于最后字节；busy 包含完成通知周期，下一请求须等 busy 撤销。
- error 在 done 时有效：00 成功，10 底层失败，11 无进展超时，12 长度错误。
- 复位放弃当前事务且不发 done；系统重扫仍按原流程取消内存写入并重新初始化 SD。
- S1 的旧接口桥在旧请求撤销前不重新接受它；短扇区仍由原 BMP 完整性判断触发重试，介质失败和超时进入原恢复流程。
