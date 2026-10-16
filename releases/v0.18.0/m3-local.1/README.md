# v0.18.0-m3-local.1 本地候选

M3本地实现、专项/相关回归、完整TD及审计通过；板测待用户确认。分支feature/science-publicity-mode，输入M2提交8e6bf69；硬件开发回退为未获整机验收的v0.17.0-m6-local.1，正式回退v0.16.0。旧M6未结项，不补前序验收。

## 下载与素材

使用本目录固定[demo.bit](demo.bit)，673856字节。FAT32卡根目录放入[宣传草稿包](../../../tools/publicity/geohazard_basics/generated)的EDU1–4.BMP；情景资源可直接使用[M6示意村卡](../../v0.17.0/m6-local.1/cards/demo_village)或[山洪村卡](../../v0.17.0/m6-local.1/cards/flood_village)的四PIC、四SND、FONT.BIN、TEXT.BIN。两套村素材择一，不能混用同名文件。换卡后复位。

完整EDU优先进入宣传第1页；无完整EDU时旧PIC以COMPAT启动。00下KEY1上一张、KEY2短按下一张，KEY4长按一秒切宣传/情景；松开不误触短按。情景KEY4短按AUTO、KEY1短预警/长一秒调速；KEY2长两秒重扫。拨码01/10调B/C/V、11当前套预览，应用身份与公共参数保留。

**本阶段宣传静音、AUTO禁用**：宣传短KEY4不会轮播。VOI仍为M1测试音、不播放，正式配音及单次EOF/五秒AUTO待M4与后续内容审阅。COMPAT原三秒AUTO和情景终态AUTO保留。

同卡切应用复用双表和四bank，取消排空后失效重载，首图与身份消隐提交再淡入。缺目标NO SET保持当前；覆盖后失败ERROR黑场静音，可短KEY4重试、长KEY4另一套、长KEY2重扫。

## 验证与板测

155份仿真及33份编译/模型日志核验通过。TD14：15785 LUT（80.54%）、10202寄存器、56 BRAM9k、2 BRAM32k、13 DSP；Setup +0.097ns/Hold +0.024ns，STNS/HTNS=0，无ERROR、完整bitgen。保留已知模型诊断，详情见[验证](VALIDATION.md)及[输入清单](MANIFEST.md)。

请按[板测清单](BOARD_VALIDATION.md)验证两向切换、静态翻页、参数/预览、情景旧功能及失败恢复，并回填[结果](BOARD_RESULT.md)。尚未建立board/正式标签，不合并main。失败保留local.1，修复递增候选。开发回退[M6 local.1](../../v0.17.0/m6-local.1/README.md)，正式回退[v0.16.0](../../v0.16.0/README.md)。
