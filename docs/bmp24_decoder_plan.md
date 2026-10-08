# 2.11 BMP 解码器独立化阶段计划

基线 v0.5.4。仅实现 2.11，采用兼容包装，按最小可验证阶段推进。当前 S2 本地候选待用户上板，尚未完成整个 2.11。

## 阶段及门槛

| 阶段 | 内容 | 状态 |
|---|---|---|
| S0 | 固定基线和接口，运行原有稳定性与系统回归 | 已验证 |
| S1 | 独立字节流解码器、RGB/坐标和结束检查，独立 ModelSim 与 TD 综合 | 本地通过 |
| S2 | bmp_read 接入新像素路径，保留旧路径作逐拍对照，完整 TD 构建 | 已生成候选，等待上板 |
| S3 | S2 上板确认后，将扫描/加载共享的头解析与校验抽离；完成事件来自 decoder，去除旧重复实现 | 未执行 |
| S4 | S3 专项、回归及 TD 通过后，交付最终结构的 bit 再次上板 | 未执行 |
| S5 | 最终验收后更新版本说明、项目文档和交接；按用户授权发布并历史归档 | 未执行 |

每阶段修改生产 RTL 后，先 ModelSim 专项及相关回归，再 TD 完整构建。用户上板确认前不建立 board 标签、不推送 GitHub。S2 上板通过后才能进入 S3；不能把当前像素接入当作完整独立化。

## 接口与范围

- 单时钟、高有效 rst。file_start 独占一拍，随后从 offset=0 顺序输入字节；file_valid 可插空拍，无背压。
- file_size 为上游提供长度；file_end 可与末字节同周期，内部下一拍检查末像素和行填充。
- header_accepted、pixel_valid、frame_commit、bmp_done 为脉冲；bmp_error 为锁存的 3 位结果：0 正常、1 头错误、2 上游错误、3 截断。
- frame_commit 只表示解码成功，显示交换仍须等待 SDRAM 写完及跨域确认。
- EXPECTED_WIDTH/HEIGHT 默认 640/480；RUNTIME_DIMENSIONS=1 使用任务期间稳定的 expected_width/height；ALLOW_32 默认 1，生产包装设 0。
- RGB888 按文件行顺序输出，x 递增，y=height-1-row；坐标表达显示位置，不缓存重排整帧。包装不消费坐标，现有显示方向不变。行填充跳过，32 位 alpha 丢弃。
- 原生产仅支持 24 位显示，32 位仅作为扫描快跳候选。早期计划把两者混淆；独立 decoder 的 32 位支持不代表生产格式扩展。
- 原始扇区没有真实文件 EOF，不能保证识别被后续磁盘字节填满的截断文件。
- 不引入 2.12、独立恢复 FSM、快速启动、Flash 配置或 UART/OSD 扩展。

## 当前验证与复现

独立 640×480 和 3×2 各 13 场景通过；7 类稳定性专项、5 组新旧逐拍对照、8 个原有回归入口通过。reset 入口曾漏编译 decoder，补依赖后单独通过；原失败日志保留。异步帧交接、重扫恢复及暂停续扫专项通过。

S2 TD：Setup +0.096 ns、Hold +0.037 ns、STA 99.93%；6360 LUT、4098 寄存器、4 BRAM、4 DSP、1 PLL。重复解析是 S2 暂时代价，S3 去重后须再次对比资源与时序。历史 IP 警告保留，不修改约束掩盖问题。

复现：diagnostics/bmp_decoder/run_sim.ps1、run_synthesis.ps1、run_td.ps1；相关原有回归脚本已补 decoder 编译依赖。

## 版本及交付

旧 v0.6.0-s1/s2 标签已被其他任务使用，不重写。本任务使用 v0.6.0-bmp211-sN-local.N，当前为 s2-local.1，打包修订 package.1 保持 bit 不变。

release 仅备份改动代码，当前为 bmp_read.v 与 bmp24_decoder.v；其他模块引用对应仓库版本。保留 bit、报告、说明、清单和回退路径，禁止再复制整个 user_source。用户原有 TD 工程与 best_result 修改不纳入任务提交。

候选：releases/v0.6.0-bmp211/s2-local.1/demo.bit。回退：releases/v0.5.4/demo.bit。上板步骤见候选目录 BOARD_VALIDATION.md。

每阶段更新本计划、README、CHANGELOG、验证状态和 HANDOFF（任务/完成/卡点/下一步/踩坑）。最终确认后归档到 docs/history/<完成日期>/bmp24_decoder/，活动计划保留结项入口；当前不得归档为任务完成。