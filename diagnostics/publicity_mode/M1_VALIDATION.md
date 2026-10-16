# 宣传模式 M1：内容包与 PC 工具验证

日期：2026-10-16。分支 `feature/science-publicity-mode`；本阶段输入 `v0.18.0-plan.1`（c375121）。硬件输入仍为 `v0.17.0-m6-local.1`，开发回退该固定候选，正式回退 `v0.16.0`。本次为PC内容/工具提交，不产生bit，不建立local/board标签，不转移前序板测结论。

## 四页内容与来源

| 页 | 图文主题/讲解稿 | 采用记录 | 当前音频 |
|---|---|---|---|
| 1 | [认识常见地质灾害](../../tools/publicity/geohazard_basics/scripts/page1.txt)：滑坡/崩塌/泥石流，区分山洪 | [S01](../../tools/publicity/geohazard_basics/sources/S01.md)、[S02](../../tools/publicity/geohazard_basics/sources/S02.md) | 测试音400Hz，2秒，96000样本/192000字节 |
| 2 | [留意异常，及时报告](../../tools/publicity/geohazard_basics/scripts/page2.txt)：沟水/夹带物/轰鸣，先远离再报告 | S02 | 测试音480Hz，6秒，288000样本/576000字节 |
| 3 | [听从指挥，按预案避险](../../tools/publicity/geohazard_basics/scripts/page3.txt)：当地预案、及时转移、集合清点 | S01/S02、[S03原创教学建议](../../tools/publicity/geohazard_basics/sources/S03.md) | 测试音600Hz，8秒，384000样本/768000字节 |
| 4 | [做好准备，熟悉演练](../../tools/publicity/geohazard_basics/scripts/page4.txt)：联络、物品、演练及协助 | S01/S03 | 测试音750Hz，10秒，480000样本/960000字节 |

实际取得并阅读应急管理部网站2022-08-15、2023-07-28两篇图解原文及长图。来源记录给出页面/原图网址、发布来源与日期、图中小标题和采用语句、核对日期、权利处理及编辑边界。未转载原海报或录音；绘图和测试音为代码原创。第4页准备建议与第3页清点为原创课堂组织，不冒充官方物资标准或当地预案；基础概念通俗表述仍待专业复核。

模板见 [content.yaml](../../tools/publicity/geohazard_basics/content.yaml)，配对配置见 [pack.yaml](../../tools/publicity/geohazard_basics/pack.yaml)。四页均可见“测试音·非正式配音”，manifest明确 `formal_narration=false`、`audio_status=test_tone`、`audio_matches_script=false`。不存在正式讲解听审或图音语义同步通过的结论。

## 实际执行与结果

Python始终使用 `py -I -X utf8`。Pillow 12.3.0、PyYAML 6.0.3；标准WAV提取无需ffmpeg。命令从项目根目录执行，所有输出路径执行前不存在。

```powershell
py -I -X utf8 tools/publicity/geohazard_basics/make_inputs.py --output diagnostics/output/publicity_m1_inputs_attempt01 --font C:/Windows/Fonts/simhei.ttf
py -I -X utf8 tools/publicity/geohazard_basics/make_inputs.py --output tools/publicity/geohazard_basics/inputs --font C:/Windows/Fonts/simhei.ttf
py -I -X utf8 tools/make_publicity_pack.py tools/publicity/geohazard_basics/pack.yaml --output tools/publicity/geohazard_basics/generated
py -I -X utf8 diagnostics/publicity_mode/test_publicity_pack.py --output diagnostics/output/publicity_m1_tests_attempt01
py -I -X utf8 diagnostics/publicity_mode/test_publicity_pack.py --output diagnostics/output/publicity_m1_tests_attempt02
```

attempt01：16项中15项通过、1项失败。Python `wave` 对奇数字节data块按完整样本向下取整，初稿漏检尾部半样本。修复为先解析RIFF/chunk实际大小，拒绝奇数、截断、多data块和不一致长度，再按标准格式提取。失败输入、日志及部分输出保留本地诊断目录，不作为合格包。

attempt02：**16项通过，0失败/0错误**。固定 [日志](M1_test.log)、[机器记录](M1_verification.json)、[测试入口](test_publicity_pack.py)。覆盖范围：

- 四BMP独立解析头、逐行反转与BGR通道对照，再用Pillow独立解码；四页全像素1228800个/3686616字节一致。均640×480、24bpp BI_RGB、54字节头、正高度bottom-up，每张921654字节；没有alpha/T素材。
- 四PCM与标准WAV数据逐字节相同，无RIFF头；共1248000样本、2496000字节，时长2/6/8/10秒、四槽音频不同。并实际调用原 `tools/make_audio_corpus.py` 标准WAV路径，四份提取结果与新工具完全相同；未运行MP3/重采样/ffmpeg链路。
- 14个文件（四BMP、四PCM、五预览、一清单）共6670941字节，在两个不同父目录/目录名的新输出与纳管固定包分别逐字节一致。检查文件集合、每文件字节，不写哈希。额外CLI生成一份也与固定包一致。
- 固定输入9个文件（四PNG、四WAV、generation.json）在同SimHei字体/Pillow环境重画重生成逐字节一致；字体9745792字节，不分发字体。打包复现仅需固定输入，不依赖字体。`.gitattributes`仅对该输入/输出目录关闭换行转换，保护JSON和媒体原始字节。
- 恰四页、重复/错序/非法id、缺图/音/稿/来源、空稿/来源、错误尺寸、alpha/调色板、非标准采样率/声道/位深、空/伪/奇数/截断WAV均拒绝；无输出副作用。坏BMP头/长度反读拒绝。
- 无讲解显式null时不产生对应PCM、清单记录missing而非零字节文件；3样本/6字节的亚扇区短PCM与>5秒素材均通过。空目录/文件/已有内容目录及CLI二次运行拒绝覆盖，原内容逐字节保留。不合法fixture与缺讲解包留在attempt02中供后续测试。

## 版式与待人工事项

已实际查看第一页、第三页及 [四页总览](../../tools/publicity/geohazard_basics/generated/previews/overview.png)，文字无裁切/乱码、主题顺序连贯；四页共45个文字边界检查通过。标题32px、正文24px、来源16px，全部避开顶部 `[0,0,640,60]` 与右侧 `[420,210,624,412]`。预留依据M6 `audio_ring_overlay.v` 中(520,310)及dx/dy<96范围，加边界裕量；这只是PC静态预留，不是最终HDMI叠加验证。

尚未完成：用户/专业人员内容审阅、正式录音与逐段完整听审、当地具体预案核对、HDMI实际OSD遮挡、电视观看距离可读性，以及FPGA逐页讲解/五秒AUTO。无RTL改动，未运行ModelSim/TD或上板；当前基线bit不支持EDU/VOI。M2–M6未实施。M6整机板测、40分钟及前序实测数据仍待用户，不回填成已通过。

个人 `问题小记录.txt` 与本次开始时临时副本保持909字节逐字节一致，不提交。生产RTL、TD工程、旧releases无Git差异。源码和合格PC素材只在tools及本专项目录，不放releases硬件候选。后续M2按实际接口清单开展扫描/映射；本次不自动推进。

提交前检查：48个暂存文件范围正确，27个文本文件UTF-8/无替换字符，Markdown围栏配对、306个本地链接存在，`git diff --cached --check`通过；23个冻结输入/产物的Git暂存blob与磁盘逐字节一致，确认定向换行保护生效。个人记录未暂存，保护目录相对M0无Git差异；此项不扩称为整仓库原始字节比较。
