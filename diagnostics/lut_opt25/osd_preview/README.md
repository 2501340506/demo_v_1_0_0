# 场景 OSD 渲染预览（v0.25 S5）

用真实的 `scene_text_overlay` RTL 在滑坡卡的真实阶段图上渲染出来的画面，对照参考项目的示意图 `demo_v_0_0/tools/scenes/landslide_village/out/osd/STAGE*.png`、`WARN.png`。不是示意，是仿真输出。

| 文件 | 内容 |
|---|---|
| `landslide_stage1.png` | 阶段 1，t=60，字幕滚到一半 |
| `landslide_stage2.png` | 阶段 2，t=100，字幕滚到一半 |
| `landslide_stage4.png` | 阶段 4（撤离），t=239，进度条满 |
| `landslide_warn.png` | 预警：右上面板显示村名，正中红字，红框闪烁 |

避险点（亮绿）色块慢闪，预览帧恰好是“灭”的那一帧，所以图例里看不到它。

重新渲染：`tb_osd_render.sv`（仿真测试台，输入 `bg.hex`/`font.hex`/`text.hex`，输出 `frame.hex`）、`osd_preview/prep.py`（PNG → bg.hex）、`osd_preview/topng.py`（frame.hex → PNG）。命令行参数 `+STAGE=n +WARN=0/1 +T=t +SCROLL=px +FRAMES=n`。
