# v0.9.1 验证入口与接口

公共 osd_pixel_position 重建有效区 Y，提供低有效 VS 的下降沿 frame_start 以及首个有效像素 first_active。每个图层实例化同一模块，综合可合并等价寄存器；无 RGB 寄存器延迟。状态快照保持在 first_active，滚动位置保持在 frame_start。

status_osd_overlay 新增 active 输出（实际字形命中），scroll_text_overlay 的 active 语义相同。osd_alpha_band 新增必接 glyph_active 输入，顶层连接两层 active 的或值；不能用 RGB 颜色辨认字形。底条 active 表示当前像素实际执行减半。

字幕固定 25 个单元，其中字符串只有 24 个字符，保留原来的前置空单元和 400 像素宽度。WINDOW_LEFT/RIGHT 是左右开闭边界，TEXT_Y 是顶边，PIXELS_PER_FRAME 为正整数步进；字符单元固定 16×16。末步钳位到完全退出位置，再回绕。默认仍为每帧 1 像素、1025 帧周期。不实例化动态文本跨域接口；现有状态 request/ack CDC 保持不变。

依次运行（每次使用新的输出名称）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/osd/run_sim.ps1 -RunName osd_opt_status1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/osd/run_sim_scroll.ps1 -RunName osd_opt_scroll1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/osd/run_alpha.ps1 -RunName osd_opt_alpha1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/osd/run_system_scroll.ps1 -RunName osd_opt_system1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/four_bank/run_regression.ps1 -RunName osd_opt_regression1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/osd/run_td.ps1 -BuildName osd_opt_attempt1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/four_bank/audit_timing.ps1 -BuildName osd_opt_attempt1
```

状态专项保留独立字模预期、帧中更新和 mailbox 连续变化；滚动专项覆盖完整出入和回绕；底条专项遍历两帧 614400 像素，包含黄/红/白图像像素与任意颜色 glyph 的区分。系统入口新增 OSD_S3，保留真实 SDRAM/BMP/FAT32 和声音检查，并检查最终底条合成。系统 IP 模型警告沿用脚本既有分类，普通专项及回归要求零警告。没有运行时文本源，因此不声称验证了动态文本 CDC。
