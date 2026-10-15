# v0.17.0 M1 local.1：32bpp 像素通路候选

本候选在原有加载链路中保存 `{R,G,B,T}`。32bpp BMP 的 A 字节作为 T，24bpp 和缩放黑边的 T 为 FF；显示仍使用 RGB。本地专项、相关回归和完整 TD 通过，**上板尚待用户确认**，正式版仍为 v0.16.0。

- 标签：`v0.17.0-m1-local.1`；分支 `feature/mountain-escape-classroom`。
- 功能基线与回退：`v0.16.0`（1818adc），固定 [回退 bit](../../v0.16.0/demo.bit)。工程保留 `v0.17.0-plan.1` 的用户项目快照。
- 上板下载：[demo.bit](demo.bit)，664544 字节，与 `diagnostics/output/mountain_scene_m1_attempt01/TD_project/demo_Runs/phy_1/demo.bit` 逐字节一致。不要从会被覆盖的 TD 工作目录下载。
- 资源：14358 LUT（73.26%，相对基线 +168）、8274 寄存器（+24）、56/64 BRAM9k（+2）、0/16 BRAM32k、13/29 DSP。
- 最终时序：Setup +0.111ns、Hold +0.003ns，TNS 均为 0。采用布线后面积报告；中间报告的 14346 LUT 不作为交付统计。
- 验证：[VALIDATION.md](VALIDATION.md)、144 份通过的仿真日志、编译日志及 [构建输入清单](MANIFEST.md)。全部 102 个工程输入与构建快照逐字节一致，仅备份 5 个变化的生产文件。
- 板测：[BOARD_VALIDATION.md](BOARD_VALIDATION.md)；四张 32bpp 诊断图及 RGB 参考 PNG 见 [board_samples](board_samples)。将 PIC1–4.BMP 复制到另一张 FAT32 卡根目录，换卡后复位，并保留原 24bpp 卡用于回归。

生产改动只涉及 SD 目录五个加载/缩放文件；decoder 保留 24 位 pixel_rgb 兼容输出，新增 32 位 pixel_rgba。修复最后字节与 file_end 同拍时使用旧计数的问题，并在连续头字节后等待表头校验寄存完成。没有接入 hazard_layer、场景状态机、SND/FONT/TEXT 或 M2 场景工具。

已知限制：Hold 仅 3ps；约束审计保留基线未设 I/O 延迟等提示；受保护 IP 可选端口、未定宽常数、SE 多宏参数提示及 Intel Starter 容量告警保留在原始日志中。SD 卡专项使用扇区服务模型，仿真和 TD 不能替代实际卡/板/HDMI 验证。M1 的 T 正确性由 SDRAM 写入/读出逐像素仿真证明，当前显示没有灾害着色。

用户确认本候选通过后才建立 `v0.17.0-m1-board.1` 并推送分支及本阶段 local/board 标签。M2 可独立推进，M3 仍需 M1 板测和 M2 素材。
