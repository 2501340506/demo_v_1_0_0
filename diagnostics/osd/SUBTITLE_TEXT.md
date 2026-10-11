# 中文字幕替换（2026-10-11）

默认滚动内容改为 `胆子肥嘟嘟的 FPGA `，共 12 个字符槽；`SUB=CN` 显示 `胆子肥嘟嘟的`，共 6 个字符槽。

原字模编号 80–88 保留，新增 89=胆、8A=肥、8B=嘟、8C=的；子复用 83。新增字模由 Windows SimSun 16px 单色栅格生成，左上角起笔，每行最高位对应左侧。点阵效果见 [预览](subtitle_preview.png)。UART 原始字模编号输入范围扩展至 80–8C，仍不支持直接发送 UTF-8 中文。

本次验证：

- `run_uart_subtitle.ps1 -RunName subtitle_dandu_uart1` 通过，覆盖复位默认文本、CN 命令与查询、帧边界提交及原串口行为。
- `run_runtime_pixels.ps1 -RunName subtitle_dandu_pixels2` 通过，核对 208 行字模，使用新增“胆”字进行完整滚动周期像素检查。
- TD 首轮 `subtitle_dandu_build1` 生成 bit，Setup −0.198 ns / Hold +0.040 ns，未通过时序。第二轮 `subtitle_dandu_build2` 提高布局优化为 ultra 后，TD 在布局阶段崩溃。当前无合格新 bit，上板未验证，详情见根目录 HANDOFF.md。

历史 releases 文件保持原样，新显示内容须烧录本次重新生成的 bit 才会生效。
