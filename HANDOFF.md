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
- 初始化 Git 仓库，创建 `main` 分支并完成首个提交。
- 通过 GitHub 官方 CLI 登录账户 `xier1-droid`。
- 创建私有仓库 `xier1-droid/anlogic-eg4-hdmi-bmp-player`，添加 `origin` 并推送 `main`。
- 更新按键引脚约束：`key1` 使用 A2（KEY1/下一张），`key2` 使用 B2（KEY2/自动轮播），`rst_n` 使用 B1（KEY3/复位）。

## 卡住的问题

- 无。当前任务已完成。

## 下一步计划

1. 如需对外发布，在 GitHub 仓库设置中将可见性从 Private 改为 Public。
2. 后续修改在本地提交后推送到 `origin/main`。

## 踩过的坑

- 工程最初不是 Git 仓库。
- `TD_project/demo_Runs` 约占 25 MB，绝大部分是可重建中间文件；直接全部提交会让仓库臃肿。
- Playwright 默认使用 Chrome channel，本机未安装 Chrome；应显式指定 `--browser msedge`。
- 本机 Edge 会立即关闭 Playwright 自动化会话，最终改用 GitHub 官方 CLI 的设备授权流程。
- GitHub 未登录公共 API 达到速率限制，便携版 CLI 改从官方 release 重定向地址下载。
- 部分中文注释在 PowerShell 默认读取编码下显示乱码，源码本身未因此被改写。
