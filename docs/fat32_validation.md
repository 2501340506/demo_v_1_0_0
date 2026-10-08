# FAT32 v0.7.0 验证记录

## S0：已完成

2026-10-08，在 feature/fat32-filesystem 独立 worktree 中，以未修改生产 RTL 运行：

- BMP 解码器：640×480 和 3×2 各 16 场景，共 32 场景通过；编译与仿真 0 errors、0 warnings。
- 真实 BMP 与异步帧读写：三个时钟/数据间隔组合通过；各报告 commits=20、errors=5（预期注入）、collisions=0、mixed=0。覆盖部分帧失败、重新发起、短扇区和成功提交。
- 基线日志固定保存在 `diagnostics/output/fat32_s0/`，后续运行不覆盖这一份。

## S1：实现与验证中

新增 sd_sector_adapter，在 sd_card_bmp 内桥接旧 BMP 请求。未改 BMP 解析、播放器策略及 SD 协议模块。项目清单补齐已有 UART、解码器依赖及新适配器。根据实际时序报告，将适配器字节输出寄存，并在 UART 日志字符选择和发送器之间增加一个字节寄存器；UART 包格式、字节内容和握手不变。

专项新增两层测试：独立扇区契约，以及实际 sd_card_top/controller/command 链路（仅 SPI 字节侧模拟卡）。后者检查 CMD17 错误和 CRC 错误后不重复发读命令，下一次显式请求可成功。

| 构建 | Setup / Hold | 结论 |
|---|---|---|
| attempt1 | +0.110 / +0.011 ns | 在失败请求撤销修正前启动，被替代，不交付 |
| attempt2 | -0.023 / +0.018 ns | Setup 失败，不交付 |
| attempt3 | -0.023 / +0.018 ns | 加强 post-place 仍失败，不交付 |
| attempt4 | -0.295 / +0.037 ns | 简化成功结束门控后仍失败；报告定位 UART 和 SD 字节有效到 BMP 地址路径，不交付 |
| attempt5 | -0.060 / +0.021 ns | 字节边界寄存后剩余违例集中在 UART 字符选择/转换；继续拆分字段选择与十六进制转换，不交付 |

以上构建完整产物保留在 diagnostics/output/，不进入正式候选目录。最终候选必须绑定寄存边界修正后的 RTL、完整回归及通过的独立 TD 构建。

板级尚未验证。S1 用户确认之前，不进入 S2。
