# 当前入口：v0.9.1 OSD 优化

当前生产包含状态、滚动和底条三层，接口、命令和验证范围见 [OPTIMIZATION.md](OPTIMIZATION.md)。下方 S1/S2 与“底条未实施”文字为历史说明。run_system_scroll.ps1 现在同时检查 S3 最终合成，run_alpha.ps1 使用唯一 RunName 保存完整日志。

# OSD S1 验证

## S2 滚动字幕

S2 顶层在状态条之后串接 `scroll_text_overlay`，同周期组合输出至 HDMI 音频桥。`OSD_ENABLE=0` 关闭全部 OSD，`SCROLL_ENABLE=0` 仅关闭滚动层。底条尚未实施。

- 编译参数 `TEXT_LEN=25`、`TEXT="ANLOGIC FPGA IMAGE PLAYER"`，高位字节为第一个字符；改文案时同时匹配长度，支持已有大写字模。400 像素宽、白色、Y=444，裁剪窗口 X=[8,632)。
- 沿用 25 MHz 像素时钟和原 800×525 时序，实际约 59.52 帧/秒，每帧 1 像素；完整周期为 1025 帧，约 17.22 秒。首图后的第一个 VS 开始周期，文字从窗口右边界外进入，完全退出左侧后循环。
- 首图有效来自既有 `audio_enable`，不是后台加载状态；普通切图、AUTO 和保图重扫不中断滚动，系统复位重启。
- 运行 `run_sim_scroll.ps1 -RunName <新名称>`：独立字模参考，1030 个测试帧、19422858 个有效像素，完整进入/移出/回绕、无首图、复位、旁路及消隐。周期测试保留全部 480 个 DE 行，对非字幕行缩短行宽加速，四个帧使用完整 640×480；不强制 DUT 内部状态。
- 运行 `run_system_scroll.ps1 -RunName <新名称>`：在现有真实 SDRAM 系统测试上追加滚动层，保留 S1 原图号快照及图像/音频验证；检查切图、重扫和失败恢复时滚动不中断、区域外透传及合成颜色。
- 回归和 TD 沿用以下入口，传入 S2 的新运行名；专项初版输出不作为最终通过证据。最终结果以候选说明中的具体运行目录为准。

生产代码在 user_source/hdl_source/osd，接在 video_delay/首图黑屏之后、HDMI 音频桥之前。S1 只有状态条，滚动及底条等待后续板测门槛。

## 运行

在项目根目录执行，各次运行使用不同名称，保留旧证据：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/osd/run_sim.ps1 -RunName osd_s1_sim1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/osd/run_system.ps1 -RunName osd_s1_system1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/four_bank/run_regression.ps1 -RunName osd_s1_regression1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/osd/run_td.ps1 -BuildName osd_s1_attempt1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/four_bank/audit_timing.ps1 -BuildName osd_s1_attempt1
```

## 覆盖范围

- tb_status_osd：独立点阵预期与六帧逐像素比较，1843200 个有效像素；检查 PIC:-、图片 1～4、MAN/AUTO、00～03、黄/红、消隐、整帧旁路、帧中改变状态下一帧才生效、CDC 在途更新合并和清零。
- OSD_S1 系统配置：沿用 tb_cache_system 的真实 FAT32/BMP、读写 FIFO、受保护 SDRAM 控制器和 SDRAM 命令/DQ 模型。新增观察器检查每帧第一行的实际图号、整帧快照稳定及区域外透传；原全帧图片、缓存、重扫、错误恢复、音频检查保留。
- 系统卡服务仍是扇区级模型；SPI 物理交互使用现有协议回归，不声称仿真代替实卡/显示器/Flash 板测。
- 系统测试沿用受保护 IP 的既有模型警告限制；专项及普通回归要求零 Error/Warning。系统应用实例的 OSD 输出通过层级观察，因此可能报告未连输出端口。
- TD 在 diagnostics/output 中使用独立构建副本，不覆盖主工程的运行结果或 best_result。审查路由 Setup/Hold、资源与 check_timing，不能只看综合结果。

## 接口及注意事项

- 顶层 OSD_ENABLE=0 可做零延迟 RGB 旁路；默认 1。
- 状态字符串实际为 17 个字符，字框 [8,280)×[8,24)，保留原确认文字。未来状态底条为 [4,284)×[4,28)。
- `sd_card_bmp.osd_error_code[7:0]` 对齐现有保持错误，初始化/扫描正常为 00，无图 01，通信/超时 02，前台失败 03。图片编号是有效图片列表中的逻辑编号，与原面板一致；缺图时不代表文件名中的数字，也不是物理 bank。
- AUTO 和错误在保持数据的 request/ack 邮箱中过域；显示图号直接使用已经验证的 media_commit_cdc 像素域输出，不增加音频握手或消费者。
- 首行起点锁存状态，字体在第八行开始。VS 下降沿太早，不能用于本项目当帧图号锁存。
