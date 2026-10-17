# 宣传模式 M5 实施与验证

日期：2026-10-17；状态：本地验证/TD/审计完成，固定 v0.18.0-m5-local.1，板测待确认。

输入：M4 local.1 `eb7deb3`，用户反馈“M4功能正常”，记录为 M4 board.1 `e548d72`。开发回退 `v0.18.0-m4-board.1`，复用 `releases/v0.18.0/m4-local.1/demo.bit`；正式回退 v0.16.0。原目录、原宣传分支开发，个人记录与用户 TD 工程不进入提交。

1. 核对并完成 01 B/V、10 C/V 的选择、饱和加减和组合恢复；最终视频参数条优先于情景速度，00 宣传不显示速度。
2. 修正情景 11 的上一/下一焦点路由；预览提交经情景事务同步图片、阶段和音频，同页重新提交也从头播放。预警状态提交普通阶段应退出预警。
3. 验证 00→01→10→11→00 应用和公共参数保持、非00无自动推进、返回后重计、当前资源预览与无效占位。
4. 专项、旧卡/纯宣传/缺文件/故障恢复、双村情景及全部受影响回归；实际生产顶层验证最终像素、时序和逐样本PCM/HDMI有效负载，说明外部模型边界。
5. 完整 TD 与时序、告警审计；Setup/Hold>0、TNS=0、无ERROR、完整bitgen、LUT≤16660；失败证据留诊断目录。合格后固定源码/配置/bit/证据及操作说明，提交并打 `v0.18.0-m5-local.1`，只推 new-origin 当前分支和本阶段标签。

M4总体确认不补造单项、时长或M6数据；M1 VOI仍为测试音，正式配音/内容审阅待办。M5本地通过不等于板测通过。

## 最终结果

实际生产改动仅三文件，详见[接口清单](../../../宣传模式接口清单.md)。原有参数/身份/AUTO门控经本轮专项和生产top重验；没有重复新增参数模块或修改用户工程。

183份仿真及69份编译/模型日志核验通过。最终像素：`PASS M5 production final pixels: 262080 RGB/timing, 149760 glyph-region, 37440 clean-content, 52416 preview; 9953280 decoded HDMI TMDS pixels; actual SD BMP/scaler/bank/identity/keys/layers`。状态栏：`PASS M5 production status: 46592 exact final RGB pixels across 14 CDC windows; EDU/SCENE/COMPAT, pages, AUTO, N/W/V/D/E, BUSY/ERROR/NO SET`。音频：`PASS M4 production top: 1536 exact VOI source samples / 6 sessions, 21948 scaled PCM and 21948 HDMI payload samples; four pages, AUTO after transmitted tail, scene warning and return; real 307200-pixel scaler`。其余真实SDRAM/双村/旧卡与错误恢复及外部模型边界见[完整验证](../../../../diagnostics/publicity_mode/M5_VALIDATION.md)。

TD `publicity_m5_td_attempt27`：16022 LUT（81.74%）、10686寄存器、56 BRAM9k、2 BRAM32k、13 DSP；Setup +0.006ns/Hold +0.030ns，TNS0，STA覆盖率99.97%，无ERROR、完整bitgen。111工程输入及根脚本与隔离快照逐字节一致，仅保存相对M4变化的三份生产源；个人问题记录同起始副本逐字节一致、不提交。失败构建及测试台失败保留诊断，不混入固定候选。

交付：[固定候选](../../../../releases/v0.18.0/m5-local.1/README.md)、[操作与板测](../../../宣传模式操作与板测.md)、[审计](../../../../releases/v0.18.0/m5-local.1/reports/AUDIT_REVIEW.md)、[阶段归档](README.md)。M5板测待确认；M1四VOI仍是2/6/8/10秒无人声测试音，正式配音与专业内容审阅留M6；前序v0.17.0/M6未确认项不补结论。
