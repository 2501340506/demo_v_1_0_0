# 当前交接：宣讲全文字幕已补卡，本地固件通过、待烧录板测（2026-10-19）

- 当前任务：用户明确要求完整语音滚动字幕并修改固件，字幕位于最大波形上方。原目录分支 feature/publicity-narration-subtitles，基线 ef3c545 / v0.20.0-s1-local.1。
- 已完成：四页599字、276字形，PS1字幕包及同步字体ROM接入；字形y424..439、底带y420..443、波形y452..479，按PCM总时长滚动，换页/重播复位；情景/旧图/预览/菜单隐藏，旧TX文字与18拍视频延迟保留。[固定候选](releases/v0.21.0/s1-local.1/README.md)。
- 实际补卡：已替换G:\宣讲模式\TEXT.BIN为1242字节并读回一致，其余49应用媒体逐字节未变。原TEXT102字节在候选rollback；全部50原媒体本地备份 diagnostics/output/narration_card_backup_20261019/before。四图已是前版去来源/版本的图，四PCM与字幕配速输入一致。
- 本地验证：25项仿真，含全文/坏资源/模式/最终像素/旧情景/音频参数；完整TD narration_subtitles_td01 Setup +0.055ns/Hold +0.024ns、TNS0，17626 LUT、11875寄存器、51 BRAM9k、2 BRAM32k、14 DSP。134源码逐字节一致，最终物理15字体BRAM/4416行全部核对通过。新ROM数组无过程驱动提示及旧SDRAM放置提示重复增加已审阅，既有IO约束/本地时钟边界保留。
- 当前问题与下一步：无本地阻塞。必须烧录本候选demo.bit，再重插TF卡/KEY3复位检查四页全文及末字、最大音量间距、切页重播/静音/情景/预览/菜单。尚未操作烧录器，板测待反馈；无board、未正式发布、未合main。配速按整段时长计算，不是逐字语音时间戳。
- 踩坑：py -I不导入脚本同目录，审计工具已改独立；TD日志按UTF-16 BOM读取。不能仅凭仿真或bitgen断言ROM初始化，已解码最终物理INIT/INITP。保留FONT兼容现有加载，新字模在固件，改稿需重生成并构建。
- 保护：用户TD GUI工程、个人记录、旧日志/候选未提交；不写哈希、不批量删除。新TD审计日志留本地。[计划](docs/宣讲完整语音字幕计划.md) · [S1归档](docs/history/2026-10-19/publicity-narration-subtitles/README.md)。Git同步见归档README。
