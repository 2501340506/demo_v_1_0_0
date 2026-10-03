# Anlogic EG4 HDMI BMP Player

当前归档版本：v0.2.0，2026-10-04，分支demo010-0_1_1。本次未创建Git标签或GitHub Release。

| SW2 SW1 | 模式位 | KEY1 | KEY2 |
|---|---|---|---|
| 00 | 0 图片 | 上一张 | 下一张 |
| 01 | 1 亮度预留 | 无新请求 | 无新请求 |
| 10 | 2 对比度预留 | 无新请求 | 无新请求 |
| 11 | 3 缩放预留 | 无新请求 | 无新请求 |

KEY4单击切换MAN/AUTO；复位MAN，扫描完成且图片多于一张才允许切换AUTO。按键20ms消抖，长按不连发。SW1=C8、SW2=C7，拨上为1；KEY4=C1，按下为0。

AUTO跨模式保持，空闲约3秒后轮播；模式变化重新计时。加载时各方向最多挂起一次，同向合并，下一张优先于上一张，再优先于自动轮播。图片编号在显示交接确认后更新，小数点表示AUTO。

TF卡扫描前131072扇区，最多4张640×480、24位未压缩BMP；双缓冲HDMI输出和48kHz测试音。未实现OSD、B/C调节及缩放。

用户确认阶段1至3板级正常；专项仿真和TD构建通过。完整集成回归仍需适配旧测试，不能视为全套通过。时序未收敛：Setup WNS −6.699ns，Hold WNS +0.003ns。

- [固定bitstream](releases/v0.2.0/demo.bit)
- [版本说明](releases/v0.2.0/README.md)
- [当前交接](HANDOFF.md)
- [验证边界](diagnostics/README.md)
- [归档索引](docs/ARCHIVE_INDEX.md)

构建：Tang Dynasty 6.2打开TD_project/demo.al，器件EG4S20BG256，顶层top；产物TD_project/demo_Runs/phy_1/demo.bit会随构建覆盖，固定版本使用releases目录。
