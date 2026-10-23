# 宣传模式 v0.28 内容包

计划：`docs/宣传模式科普内容重构v0.28分阶段计划.md`。保持 4 页和 PS1 框架，一页讲一种灾害，与情景模式四张卡对应：滑坡、泥石流、山洪、地震。

每页旁白按这个顺序讲：真实案例开场 → 征兆 → 往哪跑（与情景卡撤离台词一致）→ 不要做 → 口诀。

- `scripts/page1-4.txt`：旁白，同时作为全文字幕，交给 MiniMax 配音（S2）。文案已于 2026-10-23 经用户确认。
- `content.yaml`：标题、三卡要点、案例卡文字、口诀、主题色。
- `sources/S11-S15.md`：案例出处。S01、S02 沿用 `../geohazard_release/sources/`。
- `check_counts.py`：检查每页 ≤255 字（目标 ≤230），全局字形 ≤360。
- `compose.py`：AI 插画铺满画面（640×420），代码叠加标题牌、编号征兆气泡加引线、绿色逃生箭头、红色错误方向箭头、真实案例卡和口诀条。图上文字都在 y≤418 以内，y420–479 留给字幕和波形，底色与 v0.20–v0.27 相同。
- `marks.yaml`：每页气泡和箭头的坐标，与这一版插画一一对应，换图后要重新对点。
- `inputs/page1-4.png`：冻结的打包输入，由 `make_publicity_pack.py` 转成 EDU*.BMP。
- `preview/`：页面加上模拟字幕和波形后的近似效果，仅供目视检查，板上实际效果以实板为准。

AI 插画原图不入库，与情景模式做法相同。原图由 micu-image（gpt-image-2.5-flare）以 1536×1024 生成（文件名 v28f_p1-3、v28h_p4；第 4 页原图人物多一只手，已整张重画）。画风为漫画分镜：粗墨线、网点、速度线；人物本土化（蓝白运动校服加红领巾的女生、灰夹克大叔），场景为西南山村砖瓦房，无文字。

```
<scoop python> -I -X utf8 tools/publicity/geohazard_v28/check_counts.py
<scoop python> -I -X utf8 tools/publicity/geohazard_v28/compose.py --art ART_DIR --output NEW
```

需要使用带 Pillow 和 PyYAML 的 `~/scoop/apps/python/current/python.exe`。

状态：S0 文案、S1 配图（漫画分镜）、S2 MiniMax 配音、S3 字库 ROM 均已完成；候选 [releases/v0.28.0/s1-local.1](../../../releases/v0.28.0/s1-local.1/README.md)（Seed 17）待写卡和板测。
