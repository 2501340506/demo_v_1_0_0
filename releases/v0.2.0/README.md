# v0.2.0 — 四模式选择与独立按键控制

日期：2026-10-04。Git标签：`v0.2.0`。基于v0.1.9，固定产物沿用用户已验收的阶段3构建；本次仅完善中文文档和版本标签，不重新构建。标签不是GitHub Release页面。

## 本版变化

- 数码管显示SW2/SW1模式0/1/2/3；00为图片模式，其余模式暂作功能预留。
- 00模式KEY1上一张、KEY2下一张，首尾循环；其他模式不产生新的方向请求。
- KEY4在四模式下切换MAN/AUTO，复位MAN；扫描完成且图片多于一张时允许切换AUTO。按下单次触发，长按不连发。
- AUTO跨模式保持，模式变化重置等待计时；保留原加载期间的请求挂起、同向合并、下一张优先和显示交接机制。
- SW1=C8、SW2=C7，拨上为1；KEY4=C1，按下为0。

## 验证状态

用户已确认阶段1至3板级正常。模式、按键与播放控制器专项仿真及TD构建有通过记录；不能将其表述为完整集成回归通过。旧图片集成测试仍引用旧接口，异步双缓冲测试本轮未重新执行，模式变化恰逢AUTO到期仍需专项检查。详见[验证说明](../../docs/VALIDATION_STATUS.md)。

阶段3报告：Setup WNS −6.699ns、TNS −295.899ns；Hold WNS +0.003ns、TNS 0ns。时序尚未完全收敛。

## 固定产物

| 文件 | 用途 |
|---|---|
| [demo.bit](demo.bit) | 阶段3已验收产物，629624字节 |
| [demo_phy.ts](demo_phy.ts) | 最终时序摘要 |
| [demo_phy.area](demo_phy.area) | 资源及引脚报告 |
| [demo_pr.timing](demo_pr.timing) | 详细时序报告 |
| [build_mode_stage3.log](build_mode_stage3.log) | 布局布线及bitgen日志 |
| [synthesis_mode_stage3.log](synthesis_mode_stage3.log) | 综合日志 |

本版本未实现OSD、B/C调节或缩放。B初值0、范围−128..127；C初值128、范围0..256、至少9位，仅为后续要求。
