# v0.1.9 — seg7_panel 数码管面板

本版本完成数码管显示逻辑模块化，并通过 ModelSim、TD 和板级验收。

- 新增 `seg7_panel`，统一 6 位数码管扫描、图片编号、组合键提示和自动轮播小数点。
- 顶层保留原有 `seg_sel`、`seg_data` 引脚和显示布局。
- ModelSim 控制回归及数码管模块编译通过，0 errors、0 warnings。
- TD 6.2 综合、布局布线和 bitgen 完成。
- 用户已完成板级验收：图片编号、自动轮播小数点、组合提示及原有 HDMI/音频功能正常。

时序结果：Setup WNS -6.699 ns，Hold WNS +0.011 ns。该时序状态沿用工程既有结果，未在本版本处理。

发布文件：`demo.bit`、`demo_pr.timing`、`demo_phy.ts`、ModelSim 回归日志。
