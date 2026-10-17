# v0.19.0 S1 local.1 灾害图层移植

本地通过，板测待验收。基线 `7e3ac02`，分支 `feature/mountain-disaster-selector`，标签 `v0.19.0-s1-local.1`。固定 [demo.bit](demo.bit)，679676 字节。SW3 菜单在第二阶段实施。

选择性导入四类灾害图层与实际 BMP 头类型；保留旧编码、普通图和缩略图原色。十拍 RGB/同步/坐标/身份对齐，类型随成功加载的实际显示 bank 提交，失败保持。生产仍由 scenario_fsm 驱动，保留字幕、音频、参数、双应用和 SD 数码管，UART 两项默认关闭。工具及素材使用 tools/mountain_port 独立命名空间。

完整 TD disaster_s1_td_attempt02：15780 LUT（+1688）、10878 寄存器（+1348）、52 BRAM9k（+6）、2 BRAM32k（不变）、26 DSP（+13）；Setup +0.129ns、Hold +0.012ns，STNS/HTNS 均 0，无 ERROR，完成 bitgen，资源未超限。详见 [验证](VALIDATION.md) 及 validation/results.json。变化生产输入备份在 sources，其余按基线及 MANIFEST.md 引用。

[板测记录](BOARD_RESULT.md) 待用户填写，不继承前版结论。软件回退 v0.18.0-uart-s1-local.1；已确认硬件回退 M5 board.1 原 bit，正式回退 v0.16.0。无 board 标签、未正式发布、未合并 main。G:\ 卡、个人记录及旧 TD runs/best_result 不动。
