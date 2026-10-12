# MISO 原语板测修复（2026-10-13）

基线为 v0.14.0-s3-local.2，原目录 feature/thumbnail-timing-margin。local.2 用户上板报告 INIT_OK、SCAN_DONE 后 STOP E=2，未出现首图加载。保留原标签与失败证据，不建立 board.2。

## 已确认的原因

导出 local.2 的 demo_pr.db 为 local2_routed.v：MISO_delay_top 位于物理 slice 的 f[1]，INIT_LUTF1 与 INIT_LUTG1 均为 0，输出恒零；初始化完成后 sd_init_done 使 SPI 输入选择该分支。旧 RTL 仅设置 AL_MAP_LUT1.INIT=2'b10，未设置 EQN，综合声明的 EQN 默认 "0"。本轮增加 EQN="A"，使综合方程与仿真 INIT 一致。

用导出的真实物理 slice 和厂商 EG4 行为库进行负对照：外部 MISO 反复切换 0/1，旧 slice 始终输出 0，miso_local2_zero 已复现。修复后必须对新 Routed 网表重复同一测试并证明两种电平均透传，而非只看 RTL。

arch/al_lmacro.v 是综合原语声明，模块体为空；正确行为模型在 sim_release/common/al_map_lut.v。现 SD 测试和外部延迟测试加载行为模型。该行为库明确忽略 EQN、只使用 INIT，所以单靠 RTL 测试无法发现两者不一致，必须检查实际映射。

## 阶段与验证

1. 单行生产修复 EQN，SD 协议/初始化/引脚扇区/CRC/重启五项专项通过，零错误警告。
2. 原 SDC 和频率不变，完整 TD；再导出 Routed 网表验证 MISO 0/1，跑含外部延迟的引脚测试及 timing audit。
3. 全部本地门槛通过后固定递增 v0.14.0-s3-local.3，用户上板通过前不建 board.3。可用阶段回退为已确认功能正常的 S2 local.1；local.2 不作为已通过回退。

本轮不重新声称图片/缩放/音频历史回归已运行：这些逻辑未改，复用 local.2 的相关证据，新增验证集中在其遗漏的真实 MISO 通路。

## 日志边界

用户日志时间 00:08:24.349–00:08:24.614：BOOT v0.5.4-s3-local.2；INIT_OK T=5；SCAN_DONE T=FF；STOP E=2。BOOT 是 UART 历史固定字符串，不能据此推断下载版本。SCAN_DONE 的 E=0 只表示事件编码，不证明扫描成功；E=2 的 STOP 也不单独证明物理超时。根因来自实际网表及负对照。

上一轮关于 Mixed+Failure 组合测试失败的“流水错误分类”推断没有独立根因证据：最终查明是测试台把预期停止当成 Mixed 错误。保留目前已验证的整束响应实现，但不把该历史推断写成本次板测根因。
