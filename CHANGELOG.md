# Version history

## v0.2.0 - 2026-10-04

Switch mode display, independent KEY1/KEY2 direction control in mode 00, KEY4 MAN/AUTO toggle, mode-change timer reset. Pending direction semantics retained. No OSD, B/C adjustment or scaling. Fixed artifacts: releases/v0.2.0/. No Git tag created.

Board acceptance passed for stages 1-3. Focused simulations and TD builds passed. Full integration regression is NOT complete: tb_picture_requests.sv still uses removed ports, parameters and hierarchy. The asynchronous buffer regression was not rerun in this cycle. Mode change coincident with AUTO expiry also needs a dedicated check.

## v0.1.9 - 2026-10-04

Panel module refactor; TD build and board acceptance passed. See releases/v0.1.9/README.md.

# 版本更新说明

## v0.1.8 — 2026-10-04

- 增加读侧显示提交确认，采用新地址后才回收旧缓冲。
- 六个控制测试顶层和三组异步读写场景通过，TD 构建完成，用户板级功能验收正常。
- 四阶段计划全部验收，最终产物、报告、通过/对照测试和构建日志归档 releases/v0.1.8。
- 时序问题仍暂缓；按用户要求先归档，后续修改另行安排。

## v0.1.7 — 2026-10-04

- 图片编号位小数点显示轮播开关状态，兼容加载与组合提示。
- 6 个仿真顶层及 TD 构建通过，用户板级验收正常。
- 产物与日志归档 releases/v0.1.7；明确空闲轮播周期，历史时序问题仍暂缓。

## v0.1.6 — 2026-10-04

- 独立按键事件层，长按从稳定按下起算 1 秒；手势及事件交付期间自动轮播让位。
- 6 个仿真顶层通过，TD 构建完成，用户板级验收正常。
- releases/v0.1.6 归档对应产物和六份通过日志；历史时序问题继续暂缓。

## v0.1.5 — 2026-10-04

- 修复窗口内 KEY2 快速短按丢失、窗口外重叠误组合。
- 100 ms 窗口集成测试及原有回归通过；TD 构建完成，用户板级功能验收正常。
- 产物与五份仿真日志归档于 releases/v0.1.5。Setup WNS -6.699 ns，Hold WNS +0.003 ns。

## v0.1.4 — 2026-10-03

显示策略拆分后的板级验收归档。

- 新增 media_display_control，统一管理注册状态码、组合计数及提示保持计时；保持原有显示延迟和复位行为。
- 原 14 项图片回归、显示专项、播放控制专项及双键路由测试均通过，ModelSim 编译与仿真 0 errors、0 warnings。
- TD 综合、布局布线及 bitgen 完成；用户确认板级功能正常。
- releases/v0.1.4 保存对应源码版本的 bitstream、时序/资源报告及四份仿真日志。构建时间 2026-10-03 22:37:35，629624 字节。
- Setup WNS -6.699 ns，Hold WNS +0.011 ns；按用户要求暂不处理时序问题。

## v0.1.3 — 2026-10-03

媒体播放控制拆分与板级验收归档。

- media_player_control 统一管理自动轮播、方向请求挂起和加载优先级，移除旧影子寄存器。
- 接受加载时基于已提交图片计算目标索引，保留同拍新请求；BMP、SD、SDRAM 完成与双缓冲提交保持原职责。
- TD 工程补齐媒体策略和控制模块源文件。
- ModelSim 14 项集成回归及专项测试通过，编译/仿真无错误及警告；用户确认板级功能正常。
- TD 综合、布局布线及 bitgen 完成。产物、时序/资源报告及仿真日志归档至 releases/v0.1.3。
- Setup WNS -6.699 ns、Hold WNS +0.011 ns。按用户要求暂不处理时序问题。

## v0.1.0 — 2026-10-03

首个带版本标签的按键稳定性归档版本。用户确认当前代码功能和稳定性表现良好。

- KEY1/KEY2 统一使用两级同步、20 ms 消抖后的稳定电平边沿。
- KEY1 按下切下一张；KEY2 短按释放启停轮播，长按 1 秒只切一次上一张，长按释放不触发短按。
- 每个方向最多挂起一次请求，下一张 → 上一张 → 自动轮播；消费同拍的新事件保留。
- 自动轮播间隔 3 秒，手动事件优先，当前任务继续完成，手动完成后重新计时。
- 同步写应答；分别锁存 BMP 源端完成与 SDRAM 写完成，满足双方完成后提交显示。
- 未发起写入的图头失败释放任务、保留当前画面与挂起请求；首图失败重试。已发起写入的任务继续等待完成。
- 诊断显示参数默认关闭，本次事件重构未增加诊断码；底层驱动、显示链路和时序约束未调整。

验证：ModelSim 10.6e 编译/仿真均 0 errors、0 warnings，14 组 PASS；包含阈值边界、混合请求、四图方向顺序、失败恢复、延迟写完成及自动到期冲突。SD 与写应答测试模型仍与控制时钟同步，不是物理异步验证。

构建：TD 6.2.168116，EG4S20BG256，top。归档 best_result/demo.bit，629624 字节，原构建时间 2026-10-03 02:23:16；Setup WNS -6.699 ns、Hold WNS +0.011 ns。TD 仍有 IP/未驱动端口等警告；不能套用 ModelSim 的零警告结论。板级验收来自用户反馈，没有定量压力测试时长记录。
