# 宣传内容包（M1，PC 工具）

当前套件：[认识地灾，科学避险](geohazard_basics/pack.yaml)。四页按“认识—识别—应对—准备”组织，包含 [内容模板](geohazard_basics/content.yaml)、[逐页讲解稿](geohazard_basics/scripts/page1.txt)、[来源记录](geohazard_basics/sources/S01.md)、固定 PNG/WAV 输入和 [预览总览](geohazard_basics/generated/previews/overview.png)。第2–4页讲解稿与其余来源在同级目录。内容版本 `m1-draft.1-2026-10-16`，专业内容、正式配音和电视可读性尚待人工确认。

**四段音频均为测试音，不含人声、不匹配讲解稿，不是正式配音。** 2/6/8/10秒低幅三角波分别为400/480/600/750Hz，为后续验证最短五秒与音频完成条件提供输入，尚未验证 FPGA 播放。正式配音建议按稿录制，再逐段完整听审；方案中的20–35秒是建议，实际按录音样本数计算，不能拿测试音时长冒充讲解时长。

## 生成与复现

从项目根目录运行，依赖沿用 `tools/scene_requirements.txt`，本次 Pillow 12.3.0、PyYAML 6.0.3。工具不依赖 numpy 或 ffmpeg。

```powershell
py -I -X utf8 tools/make_publicity_pack.py tools/publicity/geohazard_basics/pack.yaml --output diagnostics/output/publicity_pack_new01
py -I -X utf8 diagnostics/publicity_mode/test_publicity_pack.py --output diagnostics/output/publicity_tests_new01
```

所有输出必须为**不存在的新目录**，包括空目录也拒绝覆盖；无 `--force`。输入全部验证后才创建输出。I/O中断留下部分输出供诊断，重试另选目录。测试保留短/长/缺失及不合法素材到指定诊断目录，不批量删除。详细证据见 [M1 验证](../../diagnostics/publicity_mode/M1_VALIDATION.md)。

需要重新绘制固定输入时：

```powershell
py -I -X utf8 tools/publicity/geohazard_basics/make_inputs.py --font C:/Windows/Fonts/simhei.ttf --output diagnostics/output/publicity_inputs_new01
```

绘图使用本机黑体，字体文件不随包分发。另机合法字体或不同 Pillow 可能改变栅格；**打包复现直接使用纳管的固定 PNG/WAV，不依赖字体**。同一字体/Pillow下输入重画也做了逐字节对照，范围以验证记录为准。

## 输入与输出契约

`pack.yaml` 要求 `version: 1`、非空 `name/content_version`，恰好四页，id按1/2/3/4排列。每页包含标题、图源、脚本和非空来源记录列表，路径相对配置目录。模板决定绘图，pack配置决定实际打包，改稿后同时检查两者和画面。

- 图源必须为640×480、不透明RGB；不隐式缩放，不接收调色板或alpha。输出标准54字节头、24bpp BI_RGB、BGR底向上 BMP，每张921654字节。载入T=255是后续RTL的任务。
- 音频只接受非空、完整的48kHz/mono/s16未压缩WAV，直接提取数据为小端裸PCM，非零偶数字节、无WAV头。其他采样率、声道、位深、MP3明确拒绝，不声称已验证ffmpeg转换。
- `audio_status: test_tone` 表示测试音；`narration_unreviewed`表示待听审录音。M1工具不认证正式讲解，manifest的 `formal_narration` 始终false。
- 缺讲解测试须显式 `audio: null` 与 `audio_status: missing`。不输出该槽PCM，不生成零字节文件；清单记缺失、零样本。硬件五秒静音回退是M4任务。
- 输出根目录四个 `EDU#.BMP`、四个 `VOI#.PCM`（完整测试包），`previews/`四张PNG和一张全尺寸2×2总览，以及 `manifest.json`。清单包含完整讲解稿/来源记录、页号、格式、版本、字节数、样本数、时长和待审状态；`files`列出除清单自身外的13个有效载荷，不写哈希或时间戳。相同输入跨目录打包14个文件逐字节一致。

当前四图合计3686616字节，四PCM合计2496000字节，八个卡用媒体文件共6182616字节。未来复制到FAT32卡根目录时只复制这八个媒体文件，不复制WAV/预览/脚本，不改原PIC/SND/FONT/TEXT。**M6基线bit尚不识别EDU/VOI，本阶段不能直接当新模式硬件交付。** 双模式整卡合并及板测属于后续阶段。

## 内容编辑与待审范围

来源S01/S02登记机构、标题、发布日期、网址、原图定位、采用内容和2026-10-16核对日期；只参考知识，不复制原海报、照片、标志或录音。S03明确准备/清点建议为本项目原创教学组织，不冒充官方配额。滑坡、崩塌简明定义、图示与每条行为提示仍需专业复核。第3页采用抽象流程图，不绘制易被误用的实际撤离路线。

页面保留顶部 `[0,0,640,60]` 以及音频圆环外接保守区域 `[420,210,624,412]`；所有文字边界在生成时检查，正文24px、标题32px，来源16px。底部测试音声明在正式录音定稿后应随内容版本一起更新，不能只替换PCM却沿用“测试音”图。当前预留依据M6源码，后续OSD布局变更须重新检查。

M6前需完成：专业审阅、真实当地预案核对、四段录音与完整听审、图文音一致性、最终HDMI遮挡与电视距离下可读性。PC格式检查不能替代这些内容验收。
