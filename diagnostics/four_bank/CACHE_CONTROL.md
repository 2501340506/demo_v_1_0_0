# S2 四 bank 缓存控制器

本文件记录 S2 独立阶段的合同和结果；当前 S3 已通过 sd_card_bmp 接入生产，增加 retry_event 供 UART 记录重试。[当前候选与验证](../../releases/v0.8.0/s3-local.1/README.md)。下文“未接生产”等表述仅对应 S2 历史阶段。

模块：[media_frame_cache_control.v](../../user_source/hdl_source/SD/media_frame_cache_control.v)。S2 独立实现，不加入 `TD_project/demo.al`，不接生产顶层，不生成 bit 或 local/board 标签。当前硬件仍使用 S1 已验收原 bit。

## 状态与所有权

所有接口属于 SD 控制域，目标时钟 100 MHz；跨域同步留在 S3 端点适配层，不能把异步脉冲直接接入本模块。

目录提供压紧后的图片编号 0～3 和数量 0～4。`cache_valid/cache_failed` 按图片编号索引，`cache_banks[2*i +: 2]` 是图片 i 的 bank。分配最低编号的空闲 bank；有效缓存不淘汰、不搬移，正在显示及正在加载的 bank 均不可分配。逻辑 bank 交给既有读写模块转换为 0、307200、614400、921600 的 32 位字基地址。

调度顺序为首图及其显示提交、已接受的前台目标、按目录顺序补齐后台缓存。当前加载先完成（包括一次普通失败重试），再服务挂起的前台目标。首个文件两次失败后尝试下一文件；所有文件失败或扫描失败时保留旧画面，等待恢复操作。

`storage_busy` 只表示加载事务；`foreground_busy` 包含前台等待、显示交接及提交事件背压。现有 `media_player_control.load_busy` 在 S3 应连接后者，不能再连接存储忙信号。S2 测试已用真实播放器验证同向合并、下一张优先、AUTO 在后台加载时继续计时，以及后台完成不重置 AUTO。

## 接口合同

| 通道 | 合同 |
|---|---|
| 扫描 | 复位后发出 `scan_request`，保持至 `scan_accept`；扫描结果通过 `scan_result_valid/ready` 接收。适配层负责初始化 SD、重建 FAT32 列表，结果数量不得超过 4。 |
| 前台请求 | `request_valid && request_ready` 接受并锁存图片编号；`request_manual` 区分手动和 AUTO。后台加载期间可以接受目标。未命中只排队，不中断当前文件。 |
| 开始加载 | `load_request` 及 `load_image/load_bank` 保持至 `load_accept`。身份参数在整个事务中保持，不借用显示目标寄存器。一次只允许一个文件在途。 |
| 加载结果 | `load_result_valid/ready` 交接。成功必须已经解析成功、像素计数正确、FIFO 排空、最后写事务完成；普通失败也必须已完成写侧排空。完成前需要强制停止时使用取消通道。 |
| 取消 | `cancel_request` 保持至 `cancel_ack`，覆盖尚未接受的开始请求和已开始的加载；取消可撤回开始请求，但身份参数不变。适配层停止源数据，完成活动 burst、清 FIFO 后才能确认。取消期间收到完成结果也不发布缓存，仍等待取消确认。 |
| 显示 | `display_request` 与图片/bank 保持至 `display_ack`。确认必须代表 reader 在帧边界实际锁存目标，而不是收到请求。S3 适配层负责与既有 toggle 接口转换，一次只发一个 toggle。 |
| 提交事件 | 实际显示确认更新 `current_image/current_bank`，并产生 `committed_valid/committed_image`，保持至 `committed_ready`。后台完成不写此通道；新显示交接等待上一通知被消费。 |
| 诊断 | `cache_complete`、`cache_hit`、`load_failed` 各带对应图片编号，均为单周期事件；`request_failed` 表示本次前台未完成，集成层使用已锁存的前台编号记录。 |

重扫事件只在正常运行阶段受理，与现有恢复期间不重复重扫的行为一致。先停止调度并取消加载，同时等待在途显示提交及其通知；之后清空缓存有效位、重新扫描。`display_valid/current_bank` 不清零，旧显示 bank 始终独占；新首图实际显示后才释放旧 bank。扫描为空或失败也不清掉旧画面。

普通失败重试一次，仍失败则标记并跳过；手动再次请求会清除该图片的失败标记，允许新一轮尝试。AUTO 遇到已知失败图片或等待中的图片两次失败时，按目录顺序继续下一图片，避免每次计时到期都卡在同一个坏文件；手动请求失败则保留当前画面并返回前台失败。`load_timeout` 是已排空事务的通信失败结果；`communication_fault` 用于尚未排空或外部 SD 通信故障，触发取消。两者均停止后续读文件、保留成功缓存，手动缓存命中仍能显示；重扫恢复读卡。

## 验证结果与范围

最终控制器仿真：`four_bank_s2_control3`，857 个时钟周期，55 次加载接受、44 次显示提交、43 次缓存完成、20 次命中事件；编译和仿真均为 0 Error / 0 Warning。

- 首图显示前不预载、四图补齐、缓存往返不重读、显示边界确认前不改当前图。
- 后台加载中命中切换；未命中等待当前加载后优先于其他预载；请求接受同拍抑制新预载。
- 满缓存、加载中、待显示提交时重扫；旧 bank 不被覆盖，显示和音频背压处理正确。
- 新目录缺图压紧、空目录、扫描失败、首图失败回退、所有图失败保留旧画面。
- 一次重试、后台失败跳过、手动重试、通信超时停止读卡但保留命中切换、重扫恢复。
- 取消尚未接受的开始请求；重扫、加载成功与显示确认同拍时不发布废弃帧。
- 与真实 `media_player_control` 联合验证 AUTO、按键挂起合并和优先级；另验证 AUTO 跳过已知失败文件，以及在途文件两次失败后自动尝试下一图片。

独立综合：`four_bank_s2_syn3`，TD 6.2.168116 / EG4S20BG256，使用 10 ns 控制时钟。203 LUT、99 个时序单元（47 内部寄存器 + 52 输出寄存器）、0 BRAM、0 DSP、0 latch。未做布局布线，独立接口未附物理 I/O 延时预算，综合报告不代表 S3 的板级 Setup/Hold 或时钟覆盖签核。首次无显式时钟的探索性综合 `syn1` 和尚未补齐 AUTO 失败回退的 `syn2` 不作为最终证据。

这里的端点驱动只验证控制协议，不替代 SDRAM 模型。S3 仍需把缓存控制器接入真实 loader/reader、FAT32、SDRAM 控制器与模型进行完整数据链路验证，再构建上板候选。

[仿真日志](evidence/s2/simulation.log) · [编译日志](evidence/s2/compile.log) · [综合日志](evidence/s2/synthesis.log) · [资源报告](evidence/s2/media_frame_cache_control.area)

同时修复 `prepare_handoff.py` 在原始历史测试台未连接 S1 输出端口时的生成遗漏。`four_bank_s2_handoff_check1` 重新运行 pixel/rescan 两套测试，三组时钟/源间隔 17/2、19/16、23/64 共六项通过，均为 0 Error/Warning；[原始日志](evidence/s2/handoff)。这项回归仍针对 S1 分离端点，不是 S2 生产集成结果。

运行入口（使用新的输出名称保留历史证据）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/four_bank/run_cache_sim.ps1 -RunName four_bank_s2_control4
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/four_bank/run_cache_synthesis.ps1 -BuildName four_bank_s2_syn4
```
