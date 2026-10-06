# v0.5.2 TF 卡恢复测试

`run_tests.ps1` 运行真实 SD 协议/初始化和 KEY2 专项，字节级 SPI 应答代替引脚模型；外部卡计数不会随主机局部复位清零。`run_handoff.ps1` 运行真实 BMP、播放器及帧读写控制，复用行为 FIFO/SDRAM；覆盖恢复期间保图和在途写突发/显示提交。

local.1 板测失败后新增 `tb_sd_spi_pins.sv`，通过真实 SPI 引脚交换完整命令及扇区，不 force `spi_wr_ack`/`spi_data_out`；纳入默认 `run_tests.ps1`。已覆盖正常初始化、ACMD41 busy 后成功、扇区好/坏 CRC、主机局部复位，仍未复现用户正常卡 0→F 现象。local.2 的诊断值保持及数码管译码另由初始化与面板测试验证。

三种像素半周期/源字节间隔组合为 17/2、19/16、23/64。它们验证异步交接，不代表 S3 已采用某个内存频率。S3 参数仍待定。

必须顺序执行，输出在 `diagnostics/output/`。完整既有回归继续使用 `diagnostics/flash_boot/run_baseline.ps1`。历史 `diagnostics/history/sd_recovery` 保留旧缺陷复现，PASS REPRO 不纳入本次通过统计。
