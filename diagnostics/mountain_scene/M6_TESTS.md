# M6 验证与复现（2026-10-16）

开发输入 v0.17.0-m5-local.1（34d7a82），正式回退 v0.16.0。生产改动仅四个文件：mode_key_control、sd_card_bmp、scenario_fsm、scene_text_overlay。以下均是本机仿真/工具结果，不代表板测。

最终候选 [v0.17.0-m6-local.1](../../releases/v0.17.0/m6-local.1/README.md)：118 份仿真、36 份编译日志及 19 项 PC 测试核验通过；111 个工程输入与合格构建逐字节一致。固定 bit 673856 字节，双卡随候选保存。

## 专项与回归

| 范围 | 运行目录 | 结果 |
|---|---|---|
| 场景控制、CDC、淡变、按键、SND 扫描 | mountain_m6_unit03 | 五个测试台通过；AUTO 关停终态/开启推进/预警保持、1/2/4 倍速、两次终态帧边界、KEY4 AUTO 和 KEY1 长短互斥 |
| FONT/TEXT 扫描、加载、段码/速度 UI | mountain_m6_resource02 | 五项通过；GAP=0/2，目录 FAT 链及缺失/损坏/重载；110 次段码、576 速度像素 |
| 双卡文字 | mountain_m6_text01、mountain_m6_text_flood01 | 各 4778947、4778973 次逐像素/视频束检查；实际 EG4 双时钟 BRAM32k，黑色 32px、居中红色 32/64px、滚动、13 个旧汉字、16 个 ASCII 转义及损坏/缺失回退 |
| 双卡生产顶层 | mountain_m6_top_demo01、mountain_m6_top_flood01 | 各 684745、685006 次最终 HDMI 视频束检查，六/八次实际扇区服务请求，经 loader→BRAM→CDC→叠加；四阶段/速度/预警/面板 |
| 场景及旧顶层 | mountain_m6_top_original01、mountain_m6_top_legacy01 | 414125/336269 像素、1392/1148 音频样本，普通/调节/预览/黑屏/静音 |
| 真实场景 PCM | mountain_m6_pcm_scene02 | 173939 个精确样本、11 个会话通过；覆盖 AUTO 继承、KEY4 开关、KEY1 调速、真实 PCM→CDC→t=239→自动下一阶段、四阶段循环、预警、缺 SND3 回退、重扫及无音频按帧计时 |
| 原 PCM | mountain_m6_pcm_original01 | 两项通过，9279/9280 精确样本，碎片/短循环/在途重扫/故障重试/缺文件 |
| BMP 解码与缩放 | mountain_m6_decoder01、mountain_m6_scaler01 | decoder 两组尺寸的 24/32bpp、表头/截断/取消；缩放十张图与取消，字节流回归 |
| FAT32 reader | mountain_m6_reader01、mountain_m6_reader3202 | 分别 24/32bpp 全 42 例；最终日志见候选清单 |
| 32bpp 缩放 reader | mountain_m6_reader3201 的 case0..3 | 四项通过，逐像素检查 RGB/T、黑边及背压；不把该目录后续失败用例计为通过 |
| SD 超时等价及物理接口 | mountain_m6_sd01 | 五项通过；与 M4 五组参数逐拍比较，协议、初始化、引脚 CRC7/CMD59/CRC16、三次重试后停止 |
| 完整系统 | mountain_m6_system01 | 591 帧、481827 精确 PCM 样本/五会话；17 次转场、17 黑帧、183705600 转场像素；598 帧快照、251159248 OSD 像素/消隐检查，UART 四阶段；缓存/AUTO/重扫/重试/坏图跳过/超时缓存切换均通过 |
| 预览与故障恢复 | mountain_m6_preview01 | Mixed=1/Audio/Failures；293 帧、200 个预览帧、10 次提交/提示，238405 精确 PCM 样本/四会话；失败保留预览、重试、超时缓存选择通过。旧系统测试台不例化场景文字，须结合上述双卡顶层与文字专项 |
| PC 工具 | mountain_m6_image_tool01、audio_tool01、text_tool01、cards_tool02 | 8+4+3+4 项通过；双卡各 44 文件逐字节复现，四张新图/四个 WAV 可复现，拒绝覆盖，警报频率/幅值/采样格式及 TEXT 叹号编码独立检查 |

双卡文字测试强制帧计数到 0/16 验证两个缩放相位，未将它当作硬件时间测量。顶层经扇区服务注入数据，不验证真实卡 SPI；SPI 单独由 sd01 引脚测试覆盖。全部板级 SD/HDMI、声学效果和连续运行待用户确认。overview/expected PNG 只有灾害图层参考，不包含最终 OSD。

## 历史失败及边界

- 早期 cards_tool01 把顶层条目数 14 错当作递归文件数 44；修正测试枚举为 rglob 后 cards_tool02 四项通过，生成文件未变。
- reader3201 错将全部故障用例也开启缩放；case24 的“超过链访问上限”元数据按 MAX_VISITED_CLUSTERS=4 生成，而生产 reader 的缩放 streamer 固定上限为 16384（fat32_bmp_reader.v:122），所以该用例报 bad image succeeded。最终按原 M5 验证矩阵拆分：不缩放全 42 例与缩放 case0..3；不修改生产 reader，也不把 case24 失败描述为通过。失败日志留本地。
- TD attempt01 完成 bitgen 但 Setup −0.138ns/Hold +0.024ns；attempt03 Setup −0.185ns/Hold +0.004ns，均拒绝交付。固定 attempt02：15083 LUT（76.95%）、9751 寄存器、56 BRAM9k、2 BRAM32k、13 DSP；Setup +0.101ns/Hold +0.019ns，TNS 均为 0，STA 覆盖率 99.97%，无 ERROR、完整 bitgen，bit 673856 字节。111 个工程输入与当前源码逐字节一致；审计汇总同 M5，归一化 TD 告警无新增。
- 原 PC 测试 unittest 写 stderr，PowerShell 重定向生成 NativeCommandError 包装；正文均有 Ran N tests/OK、无 FAILED。打包按正文检查，不以 PowerShell 的包装诊断当作测试失败或通过依据。

## 复现命令

在仓库根目录运行，所有 RunName/BuildName/输出目录均须改成未使用的新名字：

```powershell
py -I -X utf8 tools/scenes/make_classroom_audio.py
py -I -X utf8 tools/scenes/flood_village/make_inputs.py --output diagnostics/output/flood_inputs_new
py -I -X utf8 tools/make_scene_pack.py tools/scenes/m6_demo/scene.yaml
py -I -X utf8 tools/make_scene_pack.py tools/scenes/flood_village/scene.yaml
py -I -X utf8 diagnostics/mountain_scene/test_scene_pack.py
py -I -X utf8 diagnostics/mountain_scene/test_scene_audio.py
py -I -X utf8 diagnostics/mountain_scene/test_scene_text.py
py -I -X utf8 diagnostics/mountain_scene/test_m6_cards.py
& diagnostics/mountain_scene/run_m4_unit.ps1 -RunName mountain_m6_unit_new
& diagnostics/mountain_scene/run_m5_unit.ps1 -RunName mountain_m6_resource_new
& diagnostics/mountain_scene/run_m6_text.ps1 -RunName mountain_m6_text_new -Card m6_demo
& diagnostics/mountain_scene/run_m6_text.ps1 -RunName mountain_m6_text_flood_new -Card flood_village
& diagnostics/mountain_scene/run_m6_top.ps1 -RunName mountain_m6_top_demo_new -Card m6_demo
& diagnostics/mountain_scene/run_m6_top.ps1 -RunName mountain_m6_top_flood_new -Card flood_village
& diagnostics/mountain_scene/run_m4_top.ps1 -RunName mountain_m6_top_new
& diagnostics/mountain_scene/run_m4_top.ps1 -RunName mountain_m6_legacytop_new -Legacy
& diagnostics/mountain_scene/run_m4_pcm.ps1 -RunName mountain_m6_pcm_scene_new
& diagnostics/mountain_scene/run_legacy.ps1 -Suite pcm -RunName mountain_m6_pcm_new
& diagnostics/mountain_scene/run_legacy.ps1 -Suite decoder -RunName mountain_m6_decoder_new
& diagnostics/mountain_scene/run_legacy.ps1 -Suite scaler -RunName mountain_m6_scaler_new
& diagnostics/mountain_scene/run_legacy.ps1 -Suite reader -RunName mountain_m6_reader_new
& diagnostics/mountain_scene/run_legacy.ps1 -Suite reader32 -RunName mountain_m6_reader32_new
& diagnostics/mountain_scene/run_legacy.ps1 -Suite reader32 -RunName mountain_m6_scale32_new -ScaleTest 1 -Cases @(0,1,2,3)
& diagnostics/mountain_scene/run_m5_sd.ps1 -RunName mountain_m6_sd_new
& diagnostics/mountain_scene/run_legacy.ps1 -Suite system -RunName mountain_m6_system_new
& diagnostics/mountain_scene/run_legacy.ps1 -Suite preview -RunName mountain_m6_preview_new -Mixed 1 -Audio -Failures
```

山洪村输入 PNG 已随源码提供，上述 make_inputs 命令仅在新目录复现，不改已有素材。音频/场景包首次生成命令适用于干净检出；已有输出时用 --output 新目录。TD 复现使用 build_m5.ps1 通用快照包装器，具体最终布局/优化参数以候选 VALIDATION 和 reports/settings 为准。m6_logs.json 固定选定日志与 PASS 标记，package_m6.py 重新检查所有选定仿真、编译、PC、TD 时序、审计及工程输入，逐字节封装固定 bit 和两卡；不生成文件哈希。
