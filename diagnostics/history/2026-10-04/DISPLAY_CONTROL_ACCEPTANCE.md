> 历史归档：2026-10-04，最终验收基线 v0.1.8。下文保留阶段过程；其中的待办、命令及构建目录描述不代表当前任务。文中未使用链接的项目路径均相对项目根目录解释。

# 显示策略拆分验收 — 2026-10-03

## 实现边界
新增 user_source/hdl_source/SD/media_display_control.v，管理注册状态码、组合键饱和计数、提示有效信号及 1 秒保持计时。sd_card_bmp 原端口不变，原有显示采样延迟和异步复位行为不变。顶层 C 字形译码、计数低四位显示及扫描器保持原接线。SD/BMP、播放控制和双缓冲提交逻辑未改变。

## 仿真
ModelSim 10.6e 编译及四个 testbench 均 0 errors、0 warnings：
- tb_media_display_control：图片 1～4、首图前状态、全部诊断状态优先级、提示时长、再次触发续时、255 饱和计数、提示中复位。
- tb_picture_requests：原有 14 项全部 PASS。
- tb_media_player_control：控制模块专项 PASS。
- tb_dual_key_event_router：双键组合与单键互斥 PASS。
日志为 diagnostics/modelsim_check/display_tb_*.log。

## TD 构建
TD 6.2.168116 / EG4S20BG256 / top，综合、布局布线、bitgen 完成。
产物：TD_project/demo_Runs/phy_1/demo.bit，629624 字节，2026-10-03 22:37:35（北京时间）。
日志：syn_1/build_display_control.log、phy_1/build_display_control.log。
报告：phy_1/demo_phy.ts、demo_pr.timing、demo_phy.area。
Setup WNS -6.699 ns，TNS -293.308 ns；Hold WNS +0.011 ns，TNS 0 ns。
LUT 4313，寄存器 3898，BRAM 20。仍有 IP 初始化、未驱动引脚、SDRAM 位置和局部时钟布线警告。时序尚未收敛，本次不调整。

## 板级验收（用户已确认正常）
使用上述新产物，勿误用 releases/v0.1.3/demo.bit。
1. 复位、首图出现及数字显示恢复正常。
2. 下一张、上一张与自动轮播时图片编号跟随实际图片。
3. 双键组合显示 C 和计数，约 1 秒后恢复编号；单键功能不误触发。
4. 提示期间再次触发组合可续时；提示期间复位可清除提示和计数。
5. HDMI 图像与声音保持正常。

2026-10-03 用户确认板级功能验收正常；未记录定量压力测试时长。本阶段归档至 releases/v0.1.4，v0.1.3 保留。