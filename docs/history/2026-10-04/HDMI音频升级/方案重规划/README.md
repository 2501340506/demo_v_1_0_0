# Git回退与R2方案重规划

2026-10-04，用户要求直接Git回退之前版本，并重规划最初HDMI音频方案；同时取消独立EDID功能。

当前分支feature/hdmi-audio-v0.3.0直接回到已验收v0.3.0-s1-board.1，再添加本轮文档修订。回退前末端由archive/hdmi-audio-edid-20261004分支保留，所有既有标签不变。没有强制推送或合并main。

同级归档目录：`D:/My_Program/anlogic_program/demo_v_0_0_EDID_archive_20261004/`。

- repository_snapshot.tar：回退前Git跟踪内容完整快照。
- repository_snapshot/：快照展开文件，可直接阅读旧HANDOFF、计划、源码和产物。
- retained_from_working_tree/：从主工作区逐文件迁移的S1之后新增文件。
- working_tree_status.txt：回退前工作区状态，包括用户此前移走的旧候选bit记录。

当前目录另存S1节点原计划和原交接，作为修订前对照。S0/S1实际上已通过；其中旧进度文字仅是历史原文，不作为当前任务。

新计划保留S0—S9编号，取消S3，不重新开发EDID；S2从历史选择性恢复后复核，后续版本加r2标识。音频项目尚未结项，取消实验不能标记为功能验收完成。
