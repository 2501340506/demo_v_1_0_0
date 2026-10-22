# 场景 OSD 渲染预览（v0.25 S5）

用真实的 `scene_text_overlay` RTL 在滑坡卡的真实阶段图上渲染出来的画面（不是示意，是仿真输出），卡用 [s5-card.2](../../../releases/v0.25.0/s5-card.2/README.md)。

**与参考项目的示意图 `demo_v_0_0/tools/scenes/landslide_village/out/osd/STAGE1/2/4.png`、`WARN.png` 逐像素一致**（四张都是 0 个像素不同；渲染时 t=239、字幕首字放在 x=8、慢闪处于“亮”，与示意图的取法相同）。

| 文件 | 内容 |
|---|---|
| `landslide_stage1.png` | 阶段 1（致因） |
| `landslide_stage2.png` | 阶段 2（发生） |
| `landslide_stage4.png` | 阶段 4（撤离），图例里三个色块 |
| `landslide_warn.png` | 预警：面板显示村名，底部字幕条滚动预警语，红框和告警色块闪烁 |

重新渲染：`tb_osd_render.sv`（输入 `bg.hex`/`font.hex`/`text.hex`，输出 `frame.hex`）、`osd_preview/prep.py`（PNG → bg.hex）、`osd_preview/topng.py`（frame.hex → PNG）；参数 `+STAGE=n +WARN=0/1 +T=t +SCROLL=px +FRAMES=n`。和示意图对齐：`+T=239 +SCROLL=624`，正常帧 `+FRAMES=32`，预警帧 `+FRAMES=48`。
