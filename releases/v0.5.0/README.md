# v0.5.0 — Flash固化与上电自启

2026-10-05，用户确认S4整体通过并授权S5。正式标签`v0.5.0`，开发分支`feature/flash-boot-v0.5.0`。沿用Git标签与固定产物的发布方式，不另建GitHub Release页面。

[下载demo.bit](demo.bit) · [最终验收](../../docs/flash_boot/s4/BOARD_VALIDATION.md) · [固化指南](../../docs/flash_boot/S3_FLASH_GUIDE.md) · [结项归档](../../docs/history/2026-10-05/Flash固化与上电自启/README.md)。

## 修改与启动顺序

两颗PLL外部reset接按键复位，保持双PLL及五域三拍复位释放。SDRAM就绪经两拍同步至SD域；TF初始化、解析器和SDRAM均就绪后才启动扫描。W25Q64固化及脱离下载器独立启动已由用户确认，保持现有图像、MAN/AUTO及音频行为。

## 固定产物与证据

正式bit直接复制已验收并已固化的S2候选，629624字节，与候选文件及`v0.5.0-s2-local.1`标签内文件逐字节一致；未重新构建。工程、约束、构建设置、源清单与TD报告一并保留S2来源。

[S2仿真与构建证据](v0.5.0-s2-local.1/README.md)：四种启动顺序、门控负对照、五轮PLL复位、七项稳定性、真实解析器异步缓冲三配置及八个既有回归入口通过。S5仅产物与文档收尾，无RTL变化，不重复仿真或TD。

[S3编程校验及冷启动](../../docs/flash_boot/s3/BOARD_VALIDATION.md)与[S4最终验收](../../docs/flash_boot/s4/BOARD_VALIDATION.md)分别获用户整体确认；不将清单中的轮数和时长补写为实测记录。

资源3926 LUT、2902寄存器、4 BRAM、4 DSP、2 PLL。SD +0.170ns，内存→SD +0.725ns；全局Setup −6.565ns、TNS −251.158ns、Hold +0.003ns。67个负端点：64个原SDRAM接口及3个旧内存内部端点（最差−0.084ns），全局未收敛，新增启动路径无负端点。见[时序对比](timing_comparison.md)。

## 复现与边界

[源清单与构建参数](source_inventory.md)记录实际构建命令。GUI工程快照为默认策略，复现候选须设置Phy/Place：hfn_opt_effort=high、opt_timing=ultra、post_place_opt=high。

SD底层恢复、免复位热插拔、单PLL迁移及参数持久化不在本版范围。历史固化日志flashsize 128与用户W25Q64/64Mbit资料存在差异，后续重烧按实际64M设置；完整Flash后缀和启动跳线未提供，不作推断。既有Flash已验收，无需为发布再次烧写。
