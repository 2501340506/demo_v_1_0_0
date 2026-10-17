# v0.18.0 宣传模式 M6 local.1

本候选用于M6新内容和整机验收；用户听审、内容确认及实际板测待反馈。固定[demo.bit](demo.bit) 673856字节，逐字节复用用户已确认的[M5原bit](../m5-local.1/demo.bit)。基线 `v0.18.0-m5-board.1`（e49bb94），生产实现f2d45c8；分支 `feature/science-publicity-mode`。本版未改RTL/工程、未重新TD，不以新内容继承M5板测结论。

交付[content.1四页图文、逐页脚本、四段试听和两套18文件整卡](../../../tools/publicity/geohazard_release/README.md)，普通话合成语音Microsoft Huihui Desktop，替换旧占位测试音。用户已选择本机普通话合成语音；四段完整听审与专业内容人工确认仍待反馈，清单保留unreviewed。M1旧包原样保留，本次未修改G:\卡。

按[完整操作与整机板测](../../../docs/宣传模式M6整机验收.md)执行并回填[实际记录](BOARD_RESULT.md)。连续运行≥40分钟、Flash冷启动、双向切换及换卡复位保留原始读数；不从M5总体反馈或历史版本补结论。内容变化需重验图音；本版bit不需为更换图片重新烧写，但Flash独立启动/持续运行必须使用此固定bit和本版内容。

本地验证范围见[VALIDATION](VALIDATION.md)，字节/工程/打包清单见[MANIFEST](MANIFEST.md)。TD继承M5 TD27：LUT16022/19600（81.74%），10686寄存器、56 BRAM9k、2 BRAM32k、13 DSP；Setup +0.006ns/Hold +0.030ns、TNS0、STA99.97%，无ERROR、完整bitgen。审计例外及6ps Setup裕量原样披露，详见[M5审计](../m5-local.1/reports/AUDIT_REVIEW.md)，不能称全IO覆盖或零告警。

M6候选确认后才建立board并按规则推送；约定验收完成且用户确认发布后，复用验收bit发布v0.18.0、回填实测、归档并合并main。当前未发布。开发回退 `v0.18.0-m5-board.1`、同一M5 bit及原M1测试素材；正式回退[v0.16.0](../../v0.16.0/README.md)。源码变更或新bit需递增候选；素材修订也固定新版本，不移动旧标签。
