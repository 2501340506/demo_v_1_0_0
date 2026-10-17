# v0.18.0 宣传模式 M5 local.1

本地候选，等待用户板测。固定[demo.bit](../../../../releases/v0.18.0/m5-local.1/demo.bit)（673856字节），标签`v0.18.0-m5-local.1`；分支`feature/science-publicity-mode`，输入M4 local.1 eb7deb3 / board.1 e548d72。

01/10参数条优先于SPEED，应用/公共参数保持，非00不自动推进；当前资源集四宫格预览，情景焦点移动不切阶段，提交同步画面/阶段/音频，同页重启，预警中选中普通阶段退出预警。00 KEY4短AUTO、长一秒切应用，情景KEY1长一秒调速；完整矩阵见[操作与板测](../../../宣传模式操作与板测.md)。

183份仿真及69份编译/模型日志核验通过。生产音频：PASS M4 production top: 1536 exact VOI source samples / 6 sessions, 21948 scaled PCM and 21948 HDMI payload samples; four pages, AUTO after transmitted tail, scene warning and return; real 307200-pixel scaler。生产视频：PASS M5 production final pixels: 262080 RGB/timing, 149760 glyph-region, 37440 clean-content, 52416 preview; 9953280 decoded HDMI TMDS pixels; actual SD BMP/scaler/bank/identity/keys/layers。状态栏：PASS M5 production status: 46592 exact final RGB pixels across 14 CDC windows; EDU/SCENE/COMPAT, pages, AUTO, N/W/V/D/E, BUSY/ERROR/NO SET。最终像素只覆盖日志声明的采样窗口，SD传输/外部存储在该台建模，真实SDRAM另行回归，详见[验证](../../../../releases/v0.18.0/m5-local.1/VALIDATION.md)。TD `publicity_m5_td_attempt27`：16022 LUT（81.74%）、10686寄存器、56 BRAM9k、2 BRAM32k、13 DSP；Setup +0.006ns/Hold +0.030ns，TNS0，STA覆盖率99.97%，无ERROR、完整bitgen；见[清单](../../../../releases/v0.18.0/m5-local.1/MANIFEST.md)、[审计](../../../../releases/v0.18.0/m5-local.1/reports/AUDIT_REVIEW.md)。

按[板测入口](../../../../releases/v0.18.0/m5-local.1/BOARD_VALIDATION.md)填写[实际结果](../../../../releases/v0.18.0/m5-local.1/BOARD_RESULT.md)，未测保持待测。M1四VOI仍是2/6/8/10秒无人声测试音，正式配音与专业内容审阅留M6；前序v0.17.0/M6未确认项不补结论。 换卡后复位，不要求带电拔卡。

开发回退：v0.18.0-m4-board.1，复用[M4原bit](../../../../releases/v0.18.0/m4-local.1/demo.bit)；正式回退[v0.16.0](../../../../releases/v0.16.0/README.md)。M5无board标签；正式v0.18.0发布、M6及main合并未执行。
