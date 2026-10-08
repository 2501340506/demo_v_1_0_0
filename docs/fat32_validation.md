# FAT32 v0.7.0 验证记录

## S0：已完成

2026-10-08，在 feature/fat32-filesystem 独立 worktree 中，以未修改生产 RTL 运行：

- BMP 解码器：640×480 和 3×2 各 16 场景，共 32 场景通过；编译与仿真 0 errors、0 warnings。
- 真实 BMP 与异步帧读写：三个时钟/数据间隔组合通过；各报告 commits=20、errors=5（预期注入）、collisions=0、mixed=0。覆盖部分帧失败、重新发起、短扇区和成功提交。
- 基线日志固定保存在 `diagnostics/output/fat32_s0/`，后续运行不覆盖这一份。

## S1：实现与验证中

新增 sd_sector_adapter，在 sd_card_bmp 内桥接旧 BMP 请求。未改 BMP 解析、播放器策略及 SD 协议模块。项目清单补齐已有 UART、解码器依赖及新适配器。

专项新增两层测试：独立扇区契约，以及实际 sd_card_top/controller/command 链路（仅 SPI 字节侧模拟卡）。后者检查 CMD17 错误和 CRC 错误后不重复发读命令，下一次显式请求可成功。

首次构建 attempt1 在接口审查修正前启动，属于被替代的本地诊断，不交付；最终候选必须使用修正后的独立构建和复测结果。

板级尚未验证。S1 用户确认之前，不进入 S2。
