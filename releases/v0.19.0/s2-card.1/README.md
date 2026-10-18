# S2 情景卡字幕与音频补全（2026-10-18）

用户报告 KEY1 后“立即撤离”文字或红框异常，随后授权直接补全 `G:\情景模式`。实查四类目录均仅有 PIC1–4；缺少 FONT/TEXT 会使原预警文字不可显示。本包补齐所需资源，未修改 RTL、工程或 bit，不声称已确认全部板级症状消失。

## 已写入

四目录 `landslide_village`、`debris_village`、`flood_village`、`quake_village` 各新增六文件：FONT.BIN、TEXT.BIN、SND1–4.PCM，共24文件。各组有灾害专属标题、阶段字幕和名称；warning 固定“立即撤离”。`card/` 保存这24个文件，可将各目录内六文件补到卡上对应目录，不要把 PIC 跨目录混用。

SND 复用已固定的 v0.18 M6 课堂提示音，逐字节等于 `tools/publicity/geohazard_release/cards/demo/card/SND1–4.PCM`，且与本机原始 WAV 数据一致。48kHz、单声道、16位有符号小端裸 PCM，每段384000样本/768000字节/8秒；前三段提示音，第4段为循环警报声，无语音讲解。KEY1 的原控制流程进入第4阶段并选择 SND4。

## 验证与复现

- 四组 FONT/TEXT 的十段文本反解、字体数量、非空字形、长度边界及16张 BMP 的头部类型/阶段/尺寸检查通过。
- `run_card_text.ps1` 使用未修改的生产 scene_text_overlay、scene_bram32k 和实际 EG4 模型，共19116433次像素/视频束比较；四阶段标题、名称、滚动字幕、2×/4×预警红字、闪框、13个旧字模及损坏/重载/缺资源行为通过。四份仿真均 Errors/Warnings=0；vendor 编译既有一项 vlog-2275 glbl 重定义告警单独记录，不称全流程零告警。
- 写入后24文件逐字节读回一致；写前情景/宣传目录中原有26文件、40110268字节逐字节未变，目录中仅增加指定文件。精确文件清单在 `validation/card_write_result.json`。
- 生成命令：`py -I -X utf8 tools/mountain_port/complete_card_resources.py prepare --output diagnostics/output/<新目录>`。默认目标 G:/情景模式，已存在任一目标资源时拒绝覆盖。仿真：`diagnostics/disaster_selector/run_card_text.ps1 -Assets <本地生成目录> -RunName <新名称>`。最后 `install --output <同一目录>` 写入并比较原媒体；本次实际运行名为 s2_card_resources01 / s2_card_text01。

## 上板与回退

沿用 `releases/v0.19.0/s2-local.1/demo.bit`；没有新固件和新 TD 构建，硬件资源/时序仍引用该候选原报告。本次仅卡资源包，不新增 local 或 board 标签。

重新插卡后按 KEY3 复位，SW3 进入菜单并分别确认四类场景。全屏演示页 SW1/SW2=00，释放按键后短按 KEY1：核对“立即撤离”居中红字、大小交替、红色闪框及警报；再短按 KEY1 回到第一阶段。另核对四阶段字幕、KEY2 切阶段和宣传播放。音量需非零。**卡写入和仿真通过，实际显示与听审待用户确认。**

撤回仅涉及 `validation/card_write_result.json` 中24个新增文件；原图和宣传文件均未替换。不要将删除整目录作为回退方法。若红框仍异常，继续检查具体显示时序，不把补资源记成板级通过。
