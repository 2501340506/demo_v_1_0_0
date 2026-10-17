# M6 四页科普内容与双模式整卡：content.1

2026-10-17；定稿候选，等待用户审阅图文、完整听审及实际板测。四页不含真实村落、真实撤离地图或官方背书；现场以当地预案和指挥为准。旧[M1测试音包](../geohazard_basics/generated/manifest.json)原样保留。

| 页 | 主题和讲解稿 | 普通话合成配音 | 文件时长 |
|---|---|---|---|
| 1 | [认识常见地质灾害](scripts/page1.txt) | [试听1](inputs/narration1.wav) | 39.3964375秒 |
| 2 | [留意异常，及时报告](scripts/page2.txt) | [试听2](inputs/narration2.wav) | 41.3015秒 |
| 3 | [听从指挥，按预案避险](scripts/page3.txt) | [试听3](inputs/narration3.wav) | 46.0661875秒 |
| 4 | [做好准备，熟悉演练](scripts/page4.txt) | [试听4](inputs/narration4.wav) | 47.8231875秒 |

[四页总览](generated/previews/overview.png)、[完整清单](generated/manifest.json)。音频来自本机 Microsoft Huihui Desktop（zh-CN，Rate=-1，Volume=100），[生成参数](inputs/voice.json)。这是逐页合成讲解，完整听审与稿音一致性仍待用户确认；未称正式配音验收通过。时长由PCM样本数除48000得到，是文件长度，不是板上计时。

定义、异常征兆、撤离勿取物及灾后勿立即返回分别追溯到[S01](sources/S01.md)、[S02](sources/S02.md)；家庭准备及集合清点为[S03原创建议](sources/S03.md)。2026-10-17重新取得官方页面及长图，核对语境；不分发参考图，不把其方向口诀泛化成任意地形规则。字体不分发。用户应逐页核对知识表述、易读性及四段全文读音和句尾，再决定是否接受。

## 整卡

- [示意村整卡目录](cards/demo/card)：18个文件，28436020字节。
- [山洪村整卡目录](cards/flood/card)：18个文件，28436214字节。

每套 `card/` 直接含 EDU1–4.BMP、VOI1–4.PCM、PIC1–4.BMP、SND1–4.PCM、FONT.BIN、TEXT.BIN。只把其中18个媒体文件复制到FAT32根目录；manifest、预览、WAV、脚本不放卡根目录，不把card文件夹整体套入根目录。两套景物/字库/文案成套使用。SND齐全，无需另加BGM；VOI不能添加WAV头。G:\原卡本次未改；如复用现有完整村卡，需同步更新四EDU和四VOI，不能只换图仍保留旧测试音。建议保留原卡并用独立测试卡。

[整机验收与计时口径](../../../docs/宣传模式M6整机验收.md)。换卡断电操作，上电/换卡后复位。故障卡和短音测试卡生成于 `diagnostics/output/publicity_m6_media01/{missing_voice2,odd_voice2,old_scene,short_voice1}/card/`，不覆盖正式整卡。short_voice1的VOI1是2秒测试音，其余为讲解；不能拿该卡验收第一页旁白。

## 新目录复现

在仓库根目录执行，每个输出路径必须从未存在：

```powershell
py -I -X utf8 tools/make_publicity_pack.py tools/publicity/geohazard_release/pack.yaml --output diagnostics/output/m6_pack_repro_NEW
py -I -X utf8 tools/make_dual_mode_card.py --scene tools/scenes/m6_demo/generated --publicity tools/publicity/geohazard_release/generated --output diagnostics/output/m6_demo_NEW
py -I -X utf8 tools/make_dual_mode_card.py --scene tools/scenes/flood_village/generated --publicity tools/publicity/geohazard_release/generated --output diagnostics/output/m6_flood_NEW
py -I -X utf8 diagnostics/publicity_mode/verify_m6.py --output diagnostics/output/m6_verify_NEW
```

固定PNG/WAV是逐字节复现输入；原字体/Pillow下重画5个栅格文件也已比较。需要重新生成声音时执行 `& tools/publicity/geohazard_release/synthesize.ps1 -OutputDirectory diagnostics/output/m6_voice_NEW`；系统语音引擎跨机器/版本不承诺字节相同，改变录音必须新增内容版本、重新打包和听审。不要改写当前固定输入或已有候选。
