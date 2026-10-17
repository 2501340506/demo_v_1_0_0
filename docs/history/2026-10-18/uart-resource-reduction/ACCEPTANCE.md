# UART S1 本地验证

输入075ab05，最终生产RTL/SDC对应 `uart_reduction_td_attempt05`。默认UART双关；不把前序M5的183份仿真或M6的49份仿真计为本轮重跑。

## 本轮11份仿真

| 输出 | 结果与实际边界 |
|---|---|
| options00/01/10/11 | 四种开关组合，实际串口SUB=ab命令、关闭RX无效/TX空闲、字幕CDC、可恢复logger、共享帧/身份提交及复位。SD面板注入已知64位debug总线验证顶层传递，非实卡板测。 |
| subtitle / logger | 原字幕解析/回复仲裁与日志精确线上字节/溢出专项重新执行。 |
| tb_m5_pixels | 真实BMP解码与307200像素scaler、四bank写入、身份/按键/图层、最终RGB/时序及TMDS解码；覆盖双应用、B/C/V、预览和切换。完成262080个RGB/时序、149760个字形区域、37440个纯内容和52416个预览像素检查，以及9953280个TMDS像素解码核对。检查稳定窗口x8–631，y28–51、60–63，非逐帧全屏检查。 |
| tb_m5_status | 46592个最终RGB像素、14个状态CDC窗口；状态窗口x400–607、y8–23。 |
| tb_scenario_top / tb_m6_top | PUBLICITY_ENABLE=0兼容回归，旧情景/音频及真实TEXT.BIN/FONT加载/HDMI；不能单独证明宣传模式。 |
| tb_m4_top | 保留真实307200像素scaler，VOI源逐样本、音量缩放后PCM及实际HDMI数据岛payload核对；四页、尾样本后AUTO、情景预警和返回；6次播放共1536个源样本、21948个缩放后PCM及21948个HDMI样本一致。每段256样本、加速时序，不代表175秒正式讲解已在RTL或实板完整播放。 |

逐项PASS标记与11份日志路径见 [results.json](../../../../releases/v0.18.0/uart-s1-local.1/validation/results.json)；计数见对应日志。全部11份仿真和20份编译/厂商模型日志完成核验，无Fatal/Error、无新增未分类告警。厂商PLL load_reg位宽及既有模型告警保留，不称零告警。模型使用SD传输与外部存储握手替身，保留真实BMP/scaler写像素和生产输出路径；本轮没有重新执行真实SDRAM整机长回归，旧证据仅继承参考。

## 完整构建与审计

14092 LUT（71.90%）、9530寄存器、46 BRAM9k、2 BRAM32k、13 DSP；Setup +0.040ns/Hold +0.019ns，STNS/HTNS均0。LUT 16022→14092（减少1930，12.05%）；寄存器10686→9530（减少1156）；BRAM9k 56→46（释放10块）；BRAM32k和DSP不变。TD v6.2.168116，EG4S20BG256；实际设置和日志在reports。选用设置以其settings.cfg为准；资源收益为最终物理结果，不用独立模块LUT相加代替。

检查0无时钟、0无效约束、0组合环；实际异常约束报告确认UART max-delay不存在，SD输入/输出MCP分别1/2条、SCLK max-delay 1条、HDMI max-delay 8条。未放宽内部路径时序。既有IO/model例外及warning差异见 [AUDIT_REVIEW](../../../../releases/v0.18.0/uart-s1-local.1/reports/AUDIT_REVIEW.md)。

独立约束探针在已启用UART的原基线数据库恢复三条TX约束，确认TX max-delay仅覆盖1条；关闭数据库使用默认SDC时UART max-delay不存在，见validation/constraint_probe。探针不代替当前完整构建。

attempt01/02为常量TX的旧约束/无效if引发的错误扩大范围，Setup -15.747ns；attempt03未开基线面积优化，Setup -0.645ns、Hold -0.020ns；attempt04时序通过但删除RX后的旧false-path产生1条无效约束。全部未交付，完整证据留diagnostics/output。最终默认同时注释RX false-path，重新完整构建与审计；无历史失败bit混入本候选。

## 板测与前序待办

[板测记录](../../../../releases/v0.18.0/uart-s1-local.1/BOARD_RESULT.md)全部待实测。数码管实卡调试页、TX电平、真实SDRAM/电视/长讲解和连续运行仍须上板。M5总体确认不转移成本候选确认，M6内容与完整听审、≥40分钟、冷启动/双向切换/换卡复位计时仍待反馈。复现命令见[诊断入口](../../../../diagnostics/uart_reduction/README.md)。
