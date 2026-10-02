# 切图卡住诊断（2026-10-03）

> v0.1.0 归档：用户已确认本轮功能与稳定性表现良好；板级验收状态覆盖下方历史“尚未验证”。发布产物位于 TD_project/demo_Runs/best_result/demo.bit。模型边界和时序未收敛情况仍然有效。

## 当前事件重构回归（优先于以下历史记录）

TD 已完成本轮综合、布局布线和 bitgen：使用 TD_project/demo_Runs/phy_1/demo.bit 上板。最终 Setup WNS -6.699 ns，Hold WNS +0.011 ns；时序约束未调整，尚未进行板级验证。

KEY1/KEY2 已统一为消抖稳定边沿，KEY2 使用 IDLE/HELD 和注册的 prev/short 单拍事件。加载分支只消费 pending，新事件最后捕获，消费同拍仍保留；自动轮播避开事件产生及消费两个阶段。诊断显示保持默认关闭。

ModelSim 10.6e：14 组 PASS，编译/仿真均 0 errors、0 warnings。新增 KEY1 持续按住与释放再按、KEY2 阈值前后/长短互斥、忙时长按、四图方向顺序、同拍消费与捕获，以及 KEY1/KEY2 自动到期边界。边沿测试驱动实际按键和消抖器；同拍 pending 仲裁测试局部 force 事件并显式标注。参数 CLK_FREQ_HZ=1000，20/1000/3000 周期对应消抖/长按/轮播，2 秒保持用 2000 周期缩放验证。

写应答仍延迟四个控制周期，写完成可单独延迟；SD 扇区模型与控制时钟同步，本轮未实现真实异步 SDRAM/FIFO 模型，也不能证明板上概率性故障已消除。运行库为 diagnostics/modelsim_check/work；重跑使用下方 RTL 文件清单和该库路径。

## 下一版实现记录（2026-10-03）

已在生产控制器中完成第一批计划修改：增加默认关闭的 `DIAG_DISPLAY` 参数；`write_req_ack` 经过 `sd_card_bmp` 接收时钟域两级同步后再送入 `bmp_read`；KEY1/KEY2 事件统一先进入 `next_req_pending`/`prev_req_pending`，加载分支仅消费 pending，首图分支不再清除下一张挂起请求。默认显示行为和时序约束保持不变。

ModelSim 已安装后，testbench 已扩展为扫描 4 个 sector，并按 sector 地址生成不同像素数据；`write_req` 应答延迟 4 个控制时钟。ModelSim 10.6e 编译和仿真均为 0 errors、0 warnings，7 个 PASS 场景全部通过。SD 数据驱动仍使用测试时钟边沿，尚未等价覆盖真实异步 SD 时钟；自动轮播边界仍需单独断言。

## 加载失败退出修复及回归结果

用户本次要求先修加载失败退出，暂不处理时序。生产 HDL 仅修改 `sd_card_bmp.v`：新增 `write_started_seen`，记录一次加载中是否发出过写请求。源端经历忙态后回到空闲且未发过写请求时，判定图头加载失败，释放 `load_busy` 并清除完成标志，保持显示缓冲区、图片编号及挂起请求。首图未提交时沿用首图加载分支重试；普通切图失败后等待后续挂起请求、按键或轮播。

已经发出写请求的加载仍须等待 SDRAM 完成；不添加超时强制清忙，不改变时序约束或写应答跨域实现。此修复不覆盖 SD 一直不返回、写应答缺失或写入数据不足造成的等待。

更新后的 `tb_picture_requests.sv` 已通过 ModelSim 回归，0 errors、0 warnings：

- 首图图头失败后重试，成功前不提交显示；
- 同键连按合并、双向挂起及 20 轮连续加载；
- 多次图头失败释放忙状态且保留当前画面；
- 失败后新按键可成功切图；
- 失败前已挂起的请求继续执行；
- 源端已经结束但 SDRAM 写完成被延迟时保持忙，写完成到达后正常提交。

以下“已执行的 RTL 仿真”为修复前的历史诊断结果；当前测试的预期已改为上述恢复行为。

## 已执行的 RTL 仿真

使用 ModelSim SE-64 10.6e 编译当前实际 `sd_card_bmp.v`、`bmp_read.v` 和 SD 子模块，运行 `tb_picture_requests.sv`，编译和仿真均为 0 errors、0 warnings。

测试将 SD 扇区返回和 SDRAM 应答/写完成建模，使用两张 4×1 的 24 位 BMP，缩短按键计数参数。真实应用控制器、消抖器和 BMP 解析状态机参与执行；不包含真实 SD 卡、SDRAM IP、布线延迟或亚稳态。

结果：

```text
PASS first image committed
PASS rapid same-key requests coalesce into current + one pending load
PASS both directions drain with next priority; long hold leaves autoplay off
PASS 20 rounds of back-to-back loads
REPRODUCED header rejection: ready=1 source_done=1 write_done=0 busy=1; further keys remain pending
PASS diagnostic complete; this fault injection does not prove the on-board trigger
```

同键连按会合并请求；同时存在 next/prev 时按优先级串行执行，测试中没有死锁。随后在下一次图头读取中把 BM 签名的 B 改成 0，实际 BMP 状态机拒绝图头并返回空闲。它未发起写请求，上层却一直等写完成，后续按键仅留下 pending，不能继续加载。

这是一个已复现的永久等待缺陷，不是已确认的板上图头损坏。正常测试通过也不等于排除了所有按键边界情况。

## 同时确认的时序和接口问题

- `bmp_read.v:292` 直接使用 mem_clk 域的 `write_req_ack`，顶层和 `sd_card_bmp` 之间未做接收域同步。
- `final_timing.rpt:8863` 报告此返回控制链路 setup slack 为 -1.045 ns；映射寄存器名称含 load_start_pulse，但报告最终数据网为 bmp_read/write_req。不能仅按物理单元名称判断受影响的 RTL 寄存器。
- 报告还包含 ext_mem_clk 同域 FIFO 控制路径 -0.405 ns 等违例；不能用全局异步时钟分组掩盖同域路径。
- `sd_card_cmd` 的 S_READ_WAIT 等待 0xFE 数据令牌，没有超时退出；如果令牌未收到，源端也会一直无法完成。该触发尚未仿真注入或上板证实。

## 建议修复顺序

1. 在应用模块入口同步写应答，并核对请求/应答在两时钟域的保持与撤销顺序；重新检查对应路径。
2. 区分“成功完成”和“读图头失败返回空闲”。确认没有发起写任务的失败可以结束本次加载并保留原图；已发起写任务不能仅清 busy 后盲目重启。
3. 提供最小加载阶段观测，记录卡住时 BMP 状态、请求/应答、源端完成、写完成及像素数；据此确定是否需要处理 SD 令牌等待或 FIFO 链路。
4. 处理剩余真实时序违例，最后以反复上板切图验证稳定性。

以上为诊断和修复建议，本轮没有修改生产 HDL 或重建 bitstream。按用户既有范围要求，不直接修改底层驱动或约束。

## 重跑方式

在独立临时目录运行 `vlib work`，用 `vlog -sv` 编译以下文件（路径相对于工程根目录，实际运行时使用绝对路径）：

- `user_source/hdl_source/SD/sd_card_bmp.v`
- `user_source/hdl_source/SD/bmp_read.v`
- `user_source/hdl_source/SD/sd_card_top.v`
- `user_source/hdl_source/SD/sd_card_sec_read_write.v`
- `user_source/hdl_source/SD/sd_card_cmd.v`
- `user_source/hdl_source/SD/spi_master.v`
- `diagnostics/tb_picture_requests.sv`

执行 `vsim -c -voptargs=+acc work.tb_picture_requests -do "run -all; quit -f"`。应检查完整 PASS/REPRODUCED 输出及 Errors 行，不能只看进程退出码。
