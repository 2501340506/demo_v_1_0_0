# M2 场景包图像工具

`make_scene_pack.py` 将村庄底图和 T 预案编译成四张 FPGA 可读的 BMP，并给出灾害图层的参考像素。M2 只处理图像；SND 音频留到 M4，FONT/TEXT 留到 M5。工具和场景在 `feature/mountain-escape-classroom` 开发，硬件基线为 v0.16.0，当前像素通路候选为 `v0.17.0-m1-local.1`。

## 使用

在仓库根目录运行（Python 3.11 以上）：

```powershell
py -I -m pip install -r tools/scene_requirements.txt
py -I tools/make_scene_pack.py tools/scenes/demo_village/scene.yaml
py -I diagnostics/mountain_scene/test_scene_pack.py
```

默认输出到示意村目录的 `generated/`，该目录保存本阶段已生成的素材，因此重新生成时须选择新目录：

```powershell
py -I tools/make_scene_pack.py tools/scenes/demo_village/scene.yaml --output diagnostics/output/m4_demo_rerun01
```

工具拒绝覆盖已有输出目录。输入路径、YAML 的 `output` 相对 scene.yaml；命令行 `--output` 相对当前工作目录。四张输出 BMP 位于输出目录根部；只把 `PIC1.BMP`–`PIC4.BMP` 复制到另一张 FAT32 卡根目录，换卡后复位，保留原卡。无需复制 expected、diagnostics、overview 或 manifest。当前 M1 bit 只显示底图 RGB；灾害动画由 M3 实现。

## scene.yaml v1

完整实例见 [demo_village/scene.yaml](demo_village/scene.yaml)。必填项为 `version: 1`、`base`、`output`、按顺序排列的四个 `stages`（`id` 为 1–4）。可填写 `name`，各阶段可用 `base` 覆盖公共底图。每阶段 `sources` 为列表，省略或空列表时不覆盖任何像素。

底图和 mask 尺寸须相同，不自动拉伸。支持硬件范围内的正尺寸：横图不超过 1920×1080，或竖图不超过 1080×1920。坐标原点在左上，x 向右、y 向下；示意村固定 640×480，使 M3 的参考像素与显示坐标一一对应。其他尺寸的 expected 是源图坐标，M3 使用前须按硬件最近邻/黑边规则适配。

| T 来源 | 字段 | 计算规则 |
|---|---|---|
| `type: grayscale` | `path`，可选 `mask` | 灰度 0–255 量化为 `floor(gray*239/255)`；越黑越早。PNG alpha=0 不覆盖；alpha>0 覆盖，不做半透明混合 |
| `type: polyline` | `points: [[x,y],…]`，可选 `width`（默认5）、`start/end`（默认0/239）、`mask` | 投影到最近线段，以从起点累计的欧氏长度线性量化；距离≤width/2 的像素覆盖，端帽为圆形。等距交点选列表中较早的线段；允许重复点，但总长度须大于0 |
| `type: seeds` | `points` 和/或 `seed_mask`，`max_distance`，可选 `mask` | 二遍 3/4 chamfer：水平/垂直步长3、对角4。`T=floor(cost*239/(3*max_distance))`；超出 max_distance 不覆盖 |

所有 mask 为灰度 PNG，非零表示覆盖；没有 mask 时为全图。灰度图中的白色表示 T=239，**不代表未覆盖**；请用 mask 或透明区表示未覆盖。seed_mask 非零像素为种子，种子点须为整数。种子距离在全图计算，之后以 mask 裁剪，不将 mask 当作障碍，也不模拟实际地形水流；M2 未实现 DEM 加权。

多个来源重叠时取较早到达的 T。未覆盖为255。顶层 `safe_spots` 和阶段内 `safe_spots` 均可使用 `{center: [x,y], radius: 7}`；半径内最终强制填250，优先于其他来源。工具不生成保留值240–249/251–254。

## BMP 与文件输出

- `PIC1.BMP`–`PIC4.BMP`：14 字节文件头 + 40 字节 BITMAPINFOHEADER，像素偏移54，planes=1、bitcount=32、compression=0（BI_RGB），正高度，自下而上，BGRA 字节序，A=T。每行 width×4，无额外行填充。
- `diagnostics/PIC*_rgb.png`：M1 应显示的原 RGB；`PIC*_T.png`：T 原始灰度，仅用于检查编码。
- `expected/PICn_t000_bright.png` 等24张 RGB PNG：四阶段 × t=0/120/239 × 亮/暗两相。
- `overview.png`：24张参考图的缩小拼图，用于目视；精确比较使用原尺寸 PNG。
- `manifest.json`：文件尺寸、T 直方图和模型约定，不含文件哈希。

BMP 生成后使用原始字节解析器反向读取，核对表头、尺寸、界限以及所有 RGB/T。不能使用普通图片查看器判断 A/T 是否正确：很多软件会丢弃 BI_RGB 的第四字节，或把 T 当作透明度。

## M3 参考模型约定 v1

调用 `hazard_reference(rgb, times, stage, t_now, blink_fast, blink_slow, enable, thumbnail)`，stage 为0–3，对应 PIC1–4；t_now 为0–239。图层在亮度/对比度之前，输出 RGB，不改 T。

| RTL stage | 阶段 | HAZARD RGB | 已覆盖区域混合 | FRONT RGB |
|---|---|---|---|---|
| 0 | 降雨 | 无 | 保留 RGB，无前沿染色 | 无 |
| 1 | 裂缝 | `60 30 10`（十六进制） | 3/4灾害色 | `FF E0 00` |
| 2 | 滑坡/山洪 | `00 60 E0` | 1/2灾害色 | `FF FF FF` |
| 3 | 撤离 | `00 C0 40` | 3/4灾害色 | `00 FF 00` |

判定和运算固定如下，后续 RTL 逐位遵循：

1. `!enable || thumbnail`：直接返回 RGB。
2. stage≠0 且 `T<240 && T<=t_now` 为 covered；`covered && t_now-T<6` 为 front。减法需扩位，不能将负差值当作无符号绕回值。
3. front 时：blink_fast=1 返回 FRONT；否则用3/4灾害色混合（包括 stage2 前沿）。covered 非 front 按表中比例混合。
4. `T==250` 时：blink_slow=1 返回 `00 FF 00`，否则保留 RGB。避险点在所有 stage 都有效。
5. 其余保留 RGB；T=240–249/251–255 均不被灾害覆盖。

混合每通道先做完整无符号加法再右移：1/2为 `(rgb+hazard)>>1`（9位和），3/4为 `(rgb+3*hazard)>>2`（10位和），向下取整。不能分别右移各项再相加。前沿恰为差值0–5，差值6进入已覆盖区域。

bright PNG 固定 `(blink_fast,blink_slow)=(1,1)`，dark 为 `(0,0)`；专项测试另覆盖 `(1,0)`、`(0,1)`。这里只冻结给定相位的像素结果，2–8Hz 前沿和慢速避险点的帧计数分频留到 M3。没有加入预警红框、OSD、转场和亮度/对比度；这些属于后续模块。

## 示意村与验证状态

[demo_village/village.png](demo_village/village.png) 为原创代码绘制的虚构教学地图，含坡体等高线、沟谷河流、村庄、高地和撤离道路。裂缝沿坡体折线增长，山洪从种子扩散并用沟谷 mask 裁剪，撤离路线从村庄通往高地。地图不代表实际村庄，也不是灾害预测数据。

输入 PNG 已入库；复现到新目录可运行：

```powershell
py -I tools/scenes/demo_village/make_inputs.py --output diagnostics/output/m2_inputs_rerun01
```

生成器不覆盖已有输入。工具自动验证、独立专项结果见 [M2 验证记录](../../diagnostics/mountain_scene/M2_VALIDATION.md)。用户目视和板上显示仍待确认；M2 无独立 bit，不建立 local/board 标签。后续用户已授权先完成 M3/M4 本地实现，未推定前序板测通过。

## M4 音频输出

可选配置 `audio: [placeholder1.wav, placeholder2.wav, placeholder3.wav, placeholder4.wav]`，路径相对 scene.yaml。配置须为空或恰好四项，按阶段顺序输出 SND1–4.PCM；省略时只生成图像。工具用当前 Python 和 `-I` 调用 `make_audio_corpus.py`，输出 48kHz 单声道有符号 16 位小端 PCM。符合该格式的 WAV 直接精确提取；其他输入沿用 ffmpeg 转换。本机未安装 ffmpeg，仅原生 WAV 路径完成实测，其他格式重采样尚未验证。输出目录必须是新目录，已有素材不覆盖。

示意村每段音效为 8 秒、384000 个样本、768000 字节，音高依次为 330/440/550/660Hz，在 0/4 秒附近有短音。这些是占位音效，不能作为旁白关键词同步已验收的证据。四个 WAV 输入已入库，可在新目录复现：

```powershell
py -I tools/scenes/demo_village/make_audio_inputs.py --output diagnostics/output/m4_audio_inputs_rerun01
py -I tools/make_scene_pack.py tools/scenes/demo_village/scene.yaml --output diagnostics/output/m4_scene_pack_rerun01
py -I diagnostics/mountain_scene/test_scene_audio.py
```

4 项音频专项及 8 项原图像专项通过；除 manifest 外 37 个图像输出与 M2 逐字节相同，原生 WAV 与输出 PCM 数据逐字节一致。`generated_m4/` 为本地可再生输出；固定的四张 BMP、四段 PCM 和 manifest 见 [M4 候选](../../releases/v0.17.0/m4-local.1/README.md)，expected 继续引用 M2 的 `generated/expected/`。

## M5 字库与文本输出

在顶层增加 `text` 配置：`titles` 和 `subtitles` 各四项，`warning` 和 `village` 各一项。省略 titles 时采用四阶段的 name。每段最多 31 字，支持 CJK 汉字及 `0123456789 :.-/!`。可选 `font` 指定字体文件，默认 `C:/Windows/Fonts/simsun.ttc`；新增字使用 SimSun 16px、原点 (0,0) 的 16×16 单色点阵。前 13 个字逐位提取原 case 字库，新增字符按文案首次出现顺序排列，总槽数最多 128。

工具在创建输出目录前完成文案与字体校验；输出 FONT.BIN（每字 32 字节、MSB 在左）和 TEXT.BIN（TX、版本 1、10 段、小端绝对偏移）。段 0..7 依次是四阶段标题/字幕，8 是预警语，9 是村名。字符 00..7F 为字库槽，F0..FF 对应上述数字和符号。完整格式见 [M5 实施说明](../../docs/M5_IMPLEMENTATION.md)。缺省 `text` 时仍支持只输出图像/音频。

```powershell
py -I -X utf8 tools/make_scene_pack.py tools/scenes/demo_village/scene.yaml --output tools/scenes/demo_village/generated_m5
py -I -X utf8 diagnostics/mountain_scene/test_scene_text.py
```

输出目录须不存在。`generated_m5/` 是忽略入库的可再生输出；固定十个卡文件及 manifest 交付到 [M5 候选](../../releases/v0.17.0/m5-local.1/README.md)，卡根目录只需 PIC1–4、SND1–4、FONT.BIN、TEXT.BIN。44 个生成文件在两个新目录逐字节复现，PIC/SND 与 M4 固定素材一致，新增三项文本测试通过。字体渲染依赖指定字体的实际版本，跨机器请以固定候选文件为验收输入。
