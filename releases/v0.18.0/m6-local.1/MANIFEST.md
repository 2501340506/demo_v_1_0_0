# M6 固定候选与复现清单

- 标签：`v0.18.0-m6-local.1`；原目录 `feature/science-publicity-mode`。
- 输入：M5 local.1 f2d45c8，用户确认提交e49bb94 / M5 board.1。
- 硬件：demo.bit，673856字节，逐字节等于M5已确认bit；未新TD。
- 生产源码和工程无变化，不重复备份整个user_source。111个工程列出输入（含被排除引用及demo.al）和根构建脚本与M5 TD27冻结快照逐字节一致，见[reuse.json](validation/reuse.json)；工程/源码来源引用[M5源码清单](../m5-local.1/MANIFEST.md)及该候选。
- 原始TD报告/工程配置和审计引用[M5 reports](../m5-local.1/reports/AUDIT_REVIEW.md)，不复制造成新构建印象。
- 内容：`tools/publicity/geohazard_release/`，m6-content.1-2026-10-17，4脚本/3来源/模板与打包配置、4PNG/4WAV及生成参数、4BMP/4PCM/5预览/manifest。四PCM总8380191样本、16760382字节，约174.5873125秒；14个打包产物20954187字节。
- 整卡：示意村18媒体文件28436020字节；山洪村18媒体文件28436214字节；两套来源和逐文件大小见[demo清单](../../../tools/publicity/geohazard_release/cards/demo/manifest.json)、[flood清单](../../../tools/publicity/geohazard_release/cards/flood/manifest.json)。卡根目录仅card/*，不复制清单。
- 新内容实际像素/样本及复现证据[media.json](validation/media.json)，旧工具回归见[pc.json](validation/pc.json)。最终RTL重跑49份仿真及52份编译/模型日志全部完成并审计，见[regression.json](validation/regression.json)；所有原日志逐字节收集。
- 负例卡固定配方：make_dual_mode_card.py的missing_voice2、odd_voice2、old_scene、short_voice1；本次输出在diagnostics/output/publicity_m6_media01，不混入完整整卡，详见内容README。
- 个人问题记录909字节与M6开始副本一致，不纳入提交。无哈希；不改旧TD/best_result/worktree/卡。

工具和验证源码为本候选提交中的 `tools/make_publicity_pack.py`、`tools/make_dual_mode_card.py`、原渲染器默认保持的test_tones选项、新render_inputs.py/synthesize.ps1、`diagnostics/publicity_mode/verify_m6.py` 和 collect_m6.py。固定PNG/WAV用于字节复现，重合成跨引擎版本不保证相同。复现命令见内容包README；回归继续使用现有run_m5.ps1，在全新RunName目录运行，保留失败/完整输出在diagnostics/output。
