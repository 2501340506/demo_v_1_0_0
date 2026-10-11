# PCM 背景音乐验证

## S1 服务合同

`sd_sector_service` 将一个物理 `sd_sector_adapter` 包装为两个独立客户端。S1 在 `fat32_bmp_reader` 的原 adapter 位置接入，生产 a 端固定关闭；S3 才接音频客户端，不提前改动文件扫描或音频输出。

- `req && !busy && !cancel`（a 端还需 enable）是接受条件，`accepted` 在该采样边沿有效；LBA 同时锁存。单拍请求不会因另一客户端占用而丢失。持续请求必须在接受后撤销。
- busy 包含排队、在途、排队取消完成周期。每客户端最多一个未完成事务。
- 两边都有请求时按扇区轮转；a_urgent 可优先 a；a_enable 阻止新接受和新调度，但不截断已经调度的扇区。
- valid/done/error 只交给拥有者；sector_byte/index 是共享载荷，必须以对应 valid 为准。
- cancel 撤销排队事务并返回一次 done/error=0x13；在途取消丢弃后续字节，等待原物理读取正常结束、失败或超时，再返回完成。另一客户端的请求不会被复位。
- 物理 adapter 的超时从实际发起读取开始。排队不消耗超时预算。全局 rst 清两个客户端和 adapter，生产与既有 SD 驱动复位联动；S3 的音频重扫停止/清空握手仍待后续阶段实现。

## 运行

在项目根目录运行；每次输出使用新名称，保留旧证据。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/pcm_audio/run_service.ps1 -RunName pcm_s1_service3
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/fat32/run_reader.ps1 -RunName pcm_s1_reader2
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/four_bank/run_regression.ps1 -RunName pcm_s1_regression1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/transitions/run_system.ps1 -RunName pcm_s1_system1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/osd/run_td.ps1 -BuildName pcm_s1_attempt1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/four_bank/audit_timing.ps1 -BuildName pcm_s1_attempt1
```

服务专项覆盖排队时间超过物理超时、LBA 锁存、轮转、紧急音频、排队取消、在途取消、失败/超时后继续读、禁用客户端和全局复位。完整系统继续使用真实 SDRAM 控制器及模型，并启用转场、OSD、UART 和计时检查。

首轮 service1 的测试预期未考虑上一事务的轮转历史，错误预期图片优先，实际正确选中音频。修改测试令取消场景先明确建立图片 owner；service3 为最终 RTL 的通过记录。reader1 在最终错误输出隔离修改前编译，仅作中间记录；最终使用 reader2。
