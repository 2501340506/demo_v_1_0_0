# 当前交接：v0.5.4已完成收尾

- 当前任务：S5版本发布与归档完成，采用已上板通过的S3 local.2原bit。
- 已完成：生产代码及原有测试脚本核对基线一致；正式bit逐字节一致；README、版本说明、验证状态、完成计划及历史索引已更新。S4按用户指示跳过，其未验收产物已移至本地归档，不纳入交付。
- 卡点：无待板测或待构建事项。本次没有RTL变化，不重复验收相同bit。
- 下一步：使用releases/v0.5.4/demo.bit；串口正确版本仍为BOOT v0.5.4-s3-local.2。新需求另立阶段。
- 踩坑：不要为改启动版本行重建；不使用TD best_result或旧诊断替代正式bit。历史物理告警仍保留，不能称为全部消除。
- 本地保留：用户TD工程、best_result及.recent_user_depot.ini不纳入本次提交；不批量删除。归档仅本地保留未验收阶段产物；正式版无代码变化，未重复复制源码。

[正式版本](releases/v0.5.4/README.md) · [验收摘要](docs/history/2026-10-07/v0.5.4/FINAL_VALIDATION.md) · [完成归档](docs/history/2026-10-07/v0.5.4/README.md)

## 2026-10-07 课程第4课 2.11/2.12 对照审查

- 当前任务：核查工程是否实现课程文档《第4课_系统稳定性增强.md》的 2.11“BMP 解码器独立化”和 2.12“image 层架构”，并补充其他明显差异。
- 已完成：检查 `user_source/hdl_source/SD/bmp_read.v`、`sd_card_bmp.v`、稳定性仿真脚本/记录及源码文件名；确认当前工程具备 BMP 严格校验、错误码/恢复、坏图快跳、无进展超时、像素完整性检查等第4课基础增强。
- 结论：2.11 未按课程完赛架构实现。当前只有 all-in-one 的 `bmp_read`，没有独立 `bmp24_decoder.v`；其接口仍直接连接 SD 扇区协议，错误码仍为 3 位基础码，未形成课程示例中的字节流输入/像素流输出独立契约。2.12 也未按课程完赛架构实现：没有可检索到的 `media_recovery_fsm`、`fast_boot_gate`、`player_config`、`uart_status_reporter`、`status_osd_overlay` 或独立 image/storage/memory/display 层模块；`sd_card_bmp` 仍承担调度、恢复和显示提交控制。
- 已实现但属于基础版：`bmp_read.v` 中可见 `bmp_error[2:0]`、`pixel_count`、`wait_timeout`、`ST_LOAD_DRAIN/ST_LOAD_CHECK`；`sd_card_bmp.v` 中有 retry/recovery、sticky error、首图提交和超时停机逻辑。现有稳定性测试脚本覆盖 baseline/recovery/headers/scan/pixels/timeout/timeout_control。
- 卡住的问题：没有发现 2.11/2.12 独立模块或对应独立层级 testbench，因此不能把当前工程称为课程文档所说的“完赛工程五层稳定性架构”。现有板测通过只证明当前单体实现的功能/稳定性，不能证明架构拆分已完成。
- 下一步计划：若目标是满足 2.11/2.12，应先定义 `bmp24_decoder` 的字节流/像素流接口并从 `bmp_read` 抽离解析状态机，再把恢复状态机和显示提交边界抽离；之后补独立 testbench、顶层接线和回归。若目标仅是课程第4课基础要求，当前实现可视为已覆盖，架构拆分属于后续增强。
- 踩过的坑：课程文档与部分历史记录存在编码显示异常；本次判断以源码、文件检索和现有验证记录为准。未批量删除或改动生产代码。

## 2026-10-08 2.11 S1 实施状态

- 当前任务：按 docs/bmp24_decoder_plan.md 实施 BMP 解码器独立化 S1。
- 已完成：新增 user_source/hdl_source/SD/bmp24_decoder.v 和 diagnostics/stability/tb_bmp24_decoder.sv；新增阶段接口/范围文档。生产 bmp_read 和 sd_card_bmp 尚未接线修改，未创建 board 标签，未上传 GitHub。
- 已验证：ModelSim vlog 编译 decoder 与专项 testbench 为 0 errors、0 warnings；输出库位于 diagnostics/output/bmp24_decoder_s1/。
- 当前卡点：专项仿真正常 4x1 24 位 BMP 流未通过，结果为 count=0, done=0, bmp_error=3。首版 decoder 的头部确认与首个像素字节接收存在时序问题，需要先修复并增加错误格式覆盖，不能进入 S2。
- 下一步：修正 header acceptance 与 pixel stream 边界；补齐签名/尺寸/planes/位深/压缩/偏移/截断测试；重新运行 ModelSim，再做模块级 TD 综合。S1 通过前不切换生产路径、不打版本标签。
- 踩坑：ModelSim 通过相对 Windows 路径启动时出现库路径拼接错误，改用绝对 POSIX 形式库路径后可正常加载；testbench 的 upstream_error 连接需显式使用 8 位常量以消除宽度警告。



## 2026-10-08 发布包规则修正

- 当前任务：按用户要求，release 仅备份改动过的用户代码。
- 已完成：S2 sources 仅保留 bmp_read.v 和 bmp24_decoder.v；未改动源码逐文件移到 diagnostics/output/decoder_s2_release_full_sources。project/demo.al 改为未变更源引用仓库、变更源引用本包，README 与 files.txt 更新。
- 卡点：无打包卡点；S2 仍待上板。bit 未改变，原本地标签保留历史，新打包修订另建标签，不推送 GitHub。
- 下一步：等待板测后继续 S3；之后 release 均只保存本阶段改动代码，最终才做任务结项归档。
- 踩坑：Windows 拒绝整目录移动，改用逐文件 Move-Item；未批量删除。差量发布包依赖同版本仓库，不再宣称可脱离仓库独立打开。

## 2026-10-08 候选交付文档复核

- 当前任务：修复 S2 上板交付中文文档，保持原始分阶段门槛。
- 已完成：阶段计划与 BOARD_VALIDATION 重写为 UTF-8；清除本任务写入项目文档的不可读问号行；release 仍仅保留两个改动 RTL。
- 验证事实：独立两尺寸 26 场景、7 类稳定性、5 组逐拍对照、8 个回归入口（reset 补依赖后单独通过）、异步交接及重扫恢复已通过；TD Setup +0.096 ns/Hold +0.037 ns。
- 卡点：等待用户确认 S2 上板。S3/S4/S5 尚未完成，不标记整个目标完成。
- 下一步：收到 S2 板测后完成共享头解析/校验和完成事件抽离，重新回归并交付 S3。
- 踩坑：PowerShell 管道向 Python 传递中文会损坏文本，本次直接用 .NET UTF-8 写入；仅更正文档，不重建相同 RTL 的 bit。

## 2026-10-08 测试素材
已生成 diagnostics/test_assets/bmp211：正常 24 位、坏签名、错误尺寸、32 位和截断 BMP，各文件用途写在 README.txt；未修改生产 RTL。

## 2026-10-08 截断测试素材修正
用户上板发现旧版 05_truncated 产生混合图。根因是其头部 file_size 仍声明完整长度，而 SD 扇区接口无真实 EOF，后续文件被当作像素。已将 05 文件头长度字段修正为实际短长度 38454，扫描应在头校验阶段跳过；README 已注明旧版不可用。
