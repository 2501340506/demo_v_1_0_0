# v0.18.0 宣传模式 M4 local.1

本地验证候选，等待用户板测。固定[demo.bit](demo.bit)（673856字节），标签`v0.18.0-m4-local.1`；分支`feature/science-publicity-mode`。输入为M3 local.1（fdb8065），已获用户总体确认的M3 board.1（adfdd66）。

VOI逐页单次播放，消费者接受最后源样本后才正常完成，完成带会话身份；新资源未选定前保持旧流停止。00 KEY4短按AUTO，完整淡入后至少300帧tick且有效讲解播完才翻页，缺音/错误静音回退；参数/预览不推进，返回00重新计时，提交同页从头重播。情景预警/速度/终态AUTO及BGM循环保留。

169份仿真及53份编译/模型日志核验通过；生产顶层：1536 exact VOI source samples / 6 sessions, 21948 scaled PCM and 21948 HDMI payload samples; four pages, AUTO after transmitted tail, scene warning and return; real 307200-pixel scaler。TD publicity_m4_td_attempt14：15966 LUT（81.46%）、10683寄存器、56 BRAM9k、2 BRAM32k、13 DSP；Setup +0.072ns/Hold +0.003ns，TNS0，无ERROR、完整bitgen。详见[验证](VALIDATION.md)、[清单](MANIFEST.md)、[审计](reports/AUDIT_REVIEW.md)。

按[板测步骤](BOARD_VALIDATION.md)验证，回填[实际结果](BOARD_RESULT.md)。00末尾A/M=自动/手动，V/D/N/E/W=播放/完成/缺失/错误/等待，E红色；完整OSD整理留M5。KEY4长按一秒切应用，情景KEY1长按调速手势不变，详见[按键矩阵](../../../docs/专业科普宣传模式分阶段修改计划.md)。

卡根目录使用[M1宣传包](../../../tools/publicity/geohazard_basics/generated/manifest.json)的EDU1–4.BMP/VOI1–4.PCM，并放入原场景PIC/SND/FONT/TEXT。M1音频为2/6/8/10秒测试音、无人声，不是正式配音或内容听审。换卡须复位。

开发回退：[M3原bit](../m3-local.1/demo.bit)，标签v0.18.0-m3-board.1；正式回退[v0.16.0](../../v0.16.0/README.md)。前序v0.17.0/M6仍未正式验收发布；M5/M6尚待实施，M4本地结论不替代板测。
