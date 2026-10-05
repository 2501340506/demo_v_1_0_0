2026-10-05更新：用户确认S1通过并授权S2，建立本地v0.5.0-s1-board.1；本目录bit不变。以下保留候选交付时记录。

# v0.5.0-s1-local.1 — PLL按键复位

2026-10-05。本地验证通过，**待用户SRAM上板确认**。未推送GitHub，未进入S2，没有Flash固化结论。

[固定demo.bit](demo.bit) · [上板步骤](BOARD_VALIDATION.md) · [时序对比](timing_comparison.md) · [源清单](source_inventory.md)

## 修改与复现

生产RTL仅顶层两颗PLL的reset从常量0改接~rst_n；五域三拍同步释放、PLL频率/相位、ADC/SDC及其他RTL不变。

首次默认布局出现两个SD复位recovery负端点（−0.273ns）。RTL扇出与保留属性尝试未改善物理结果，全部撤回；最终使用TD物理高扇出优化，消除了这两个新增端点。诊断证据见[首次报告](../../../diagnostics/flash_boot/evidence/s1_build1/README.md)及后续build2–4。

复现命令（仓库根目录）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/flash_boot/run_reset_tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/flash_boot/run_reset_tests.ps1 -BaselineTop
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_td_build.ps1 -BuildName flash_boot_s1_local5 -HighFanoutOptimization
```

候选工程快照保持原工程默认配置；若在GUI重建，需把物理布局的hfn_opt_effort设为high。仅打开demo.al用默认medium构建，不是本候选的复现参数。构建设置随附保存。

## 已验证

- S0七项稳定性专项、真实解析器异步交接三配置及八个既有入口通过，零错误零警告；[固定基线证据](../../../diagnostics/flash_boot/evidence/s0)。未改子模块复用本轮证据。
- S1真实顶层专项五轮：两个锁定顺序、系统/视频PLL各自停钟失锁恢复、按键使PLL丢弃旧锁定、在途提交清除、五域三拍释放、复位后静音和新提交一次提示音。最终正向编译/仿真零错误零警告。
- 旧顶层负对照在未连接PLL按键复位处按预期失败；负对照日志一次Fatal不是产品回归失败，不计入正向统计。
- TD完整综合、布局布线、bitgen通过。bit为629624字节，与最终构建逐字节比较一致。
- 资源3951 LUT、2900寄存器、4 BRAM、4 DSP、2 PLL。SD同域+0.147ns、内存同域+0.266ns、像素→串行+6.222ns。全局Setup−6.565ns/TNS−250.840ns、Hold+0.004ns；仅剩原64个SDRAM接口负端点，未全局收敛。

PLL/存储/FIFO采用行为模型，实际SD控制与音视频RTL及厂商ODDR参与仿真。提示事件使用注入提交，不能冒充真实TF扫描后的板级播放验证。TD既有警告类型和IO约束边界见时序对比。

## 下一步

用户完成[5轮复位、图片切换、AUTO与音频检查](BOARD_VALIDATION.md)，确认后建立本地board标签并进入S2。S5前不上传。恢复可用[v0.4.0固定bit](../../v0.4.0/demo.bit)。
