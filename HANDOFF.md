# 当前交接记录

更新2026-10-05。当前任务：将feature/hdmi-audio-v0.3.0合并到main并更新文档。文档迁移、链接修复和诊断归档已完成；用户已手动删除_cleanup，已核实目录不存在。目录整理此前已提交并推送开发分支。本轮基于最新origin/main无冲突合并开发分支，保留双方历史，更新当前状态文档后推送main。

## 已完成

- 原docx的11份文档并入docs及对应history日期，无冲突覆盖；docs/README.md为入口。v0.2.0合并审查移入docs/history/2026-10-04。
- reference没有活动工程/仿真依赖。课程来源保留在docs/HDMI_AUDIO_SOURCES.md，用户已有备份的14份原件及原说明移到_cleanup/reference。
- diagnostics根部只保留README、run_td_build.ps1、history和output。8个仿真入口、16个testbench、2个Python参考放在history/v0.3.0，脚本适配新路径，运行输出统一diagnostics/output。
- 延期SD问题复现testbench单独归入history/sd_recovery，仅存档，不接入正常回归，不开启修复。
- 299个旧日志/报告/生成源码/bit等压缩到diagnostics/history/2026-10-05/local_results.zip（约2MB），已校验可读并逐条与原件比对一致；inventory.json记录迁移。851份其余缓存未纳入归档，可重建。
- 旧运行目录、空EDID目录和合并后空的docx目录树移至_cleanup；没有批量删除文件。output和_cleanup加入Git忽略。
- 历史文档及发布README的链接/复现路径同步，失效本地链接修复；原始工具日志不改。
- 迁移后的8个仿真入口全部通过。testbench/Python代码未改变，生产RTL/TD工程/正式时序资源报告无Git差异，正式bit与发布节点逐字节一致。未重新构建TD，也未修改SD恢复逻辑。

## 卡点与待操作

无合并冲突或其他阻塞。遵守用户禁止批量删除的要求，助手仅迁移和归档；暂存目录由用户手动删除，已核实清理完成。

## 下一步

主分支已纳入v0.3.0及目录整理，后续以main为当前基线，等待用户安排后续工作。不重写既有版本标签，不自动启动新功能或SD修复。后续诊断输出放在diagnostics/output，历史资料从docs/README.md和diagnostics/README.md进入。

## 版本与延期问题

v0.3.0/S9已获用户确认并发布，固定下载releases/v0.3.0/demo.bit。SD复位偶发卡0、扫描/读头拔卡卡2、密集翻图中KEY3复位卡0仍按用户指令暂不修改。Setup−6.565ns/TNS−294.439ns，Hold+0.004ns，64个SDRAM接口违例仍在。

## 踩过的坑

- 脚本迁移需同时调整PSScriptRoot、testbench/Python路径和输出位置；不能让新缓存进入历史源码目录。
- 历史快照混用根相对/文件相对路径，本轮统一检查可达性；工具日志里的旧路径属于原始证据，不改写。
- SD复现的PASS REPRO表示观察到旧缺陷，不是修复成功，不能并入正常回归。
- _cleanup原为待删暂存，现已由用户删除；不得通过循环逐文件删除规避禁止批量删除要求。
- Windows所有迁移源/目标已确认在工作区内且目标不冲突。Git对文本有CRLF转换，文本一致性与bit逐字节一致性分别检查。

[统一文档](docs/README.md) · [诊断入口](diagnostics/README.md) · [迁移归档](diagnostics/history/2026-10-05/README.md) · [正式版本](releases/v0.3.0/README.md)
