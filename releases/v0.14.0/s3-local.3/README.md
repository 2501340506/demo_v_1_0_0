# v0.14.0 S3 local.3

这是修复 SD MISO 保持 LUT 功能错误后的 S3 四宫格候选。请使用本目录的 `demo.bit` 上板；`s3-local.2` 已确认会在 `INIT_OK` 后扫描失败，仅保留为失败历史，不再使用。

根因是 `AL_MAP_LUT1` 只设置了 `INIT(2'b10)`，但 TD 综合实际读取 `EQN` 参数；默认 `EQN="0"` 使初始化完成后启用的 MISO LUT 分支恒为 0。本候选显式设置 `EQN="A"`。生产代码相对 `v0.14.0-s3-local.2` 只修改 `user_source/hdl_source/SD/sd_card_top.v`，时钟和 SDC 均未改变。

完整 TD 构建最终时序为 Routed Setup +0.096ns、Hold +0.076ns，失败端点均为 0。Routed 网表门级仿真已验证 MISO 对 0 和 1 均能透传；SD 初始化、引脚、重试、扇区服务和外部延迟预算测试通过。97 个工程输入与构建输入逐字节一致。未改动的图片、缩放和音频功能沿用 `s3-local.2` 的本地验证证据，本轮没有重复运行。

上板先确认 UART 不再出现 `SCAN_DONE` 后紧接 `STOP E=2`，再按 `BOARD_VALIDATION.md` 检查四宫格、按键、图片、音乐、重扫和复位。候选尚未获得板测确认，因此不建立 board 标签，也不进入 S4。

阶段回退使用 `releases/v0.14.0/s2-local.1/demo.bit`，总回退使用 `releases/v0.13.0/demo.bit`。
