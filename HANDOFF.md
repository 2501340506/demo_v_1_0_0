# HANDOFF

## 当前任务

将本地 Anlogic FPGA demo 工程整理后上传到 GitHub，并根据工程功能设置合适的仓库名。

## 已完成

- 阅读了 TD 工程、顶层 Verilog、TF/BMP 读取逻辑、HDMI 音视频逻辑和约束文件。
- 确认目标器件为 EG4S20BG256，工程使用 Tang Dynasty 6.2.168116。
- 确认主要功能为 TF 卡 BMP 扫描与轮播、SDRAM 双缓冲、640x480 HDMI 输出和 48 kHz 测试音。
- 选定仓库名 `anlogic-eg4-hdmi-bmp-player`。
- 添加 `README.md` 和 `.gitignore`；保留 `demo_Runs/best_result`，忽略可重新生成的综合、布局布线中间文件和日志。
- 扫描源文件，未发现常见的明文凭据。

## 卡住的问题

- GitHub 仓库尚未创建。Playwright 默认查找 Chrome，但本机只有 Edge；下一步改用 Edge 打开 GitHub。
- 本机没有安装 GitHub CLI，因此计划通过 GitHub 网页创建仓库并通过 Git 推送。

## 下一步计划

1. 初始化本地 Git 仓库并提交整理后的工程。
2. 使用 Edge 打开 GitHub，确认登录状态并创建私有仓库。
3. 添加远端地址，推送 `main` 分支并核验 GitHub 页面。
4. 更新本文件为最终状态。

## 踩过的坑

- 工程最初不是 Git 仓库。
- `TD_project/demo_Runs` 约占 25 MB，绝大部分是可重建中间文件；直接全部提交会让仓库臃肿。
- Playwright 默认使用 Chrome channel，本机未安装 Chrome；应显式指定 `--browser msedge`。
- 部分中文注释在 PowerShell 默认读取编码下显示乱码，源码本身未因此被改写。
