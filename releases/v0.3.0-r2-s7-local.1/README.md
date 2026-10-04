# R2 S7 正弦音上板候选

日期2026-10-05。分支`feature/hdmi-audio-v0.3.0`，本地标签`v0.3.0-r2-s7-local.1`。**仿真、TD构建及用户上板验收通过；全局时序未收敛。** 2026-10-05用户确认S7通过，板级标签v0.3.0-r2-s7-board.1，固定bit不变。

## 本阶段修改

板级RTL只将S6送入bridge的左右零样本换成S2 pcm_test_tone的有符号16位左右输出。保持25MHz分数48kHz使能、440Hz DDS、峰值±12000、8样本FIFO及握手；视频、新核心、PHY、DDC高阻、复位依赖、TD清单与约束不变。

S6已于2026-10-05获用户上板确认，板级标签及S5/S6前置提交已推送。S7固定[demo.bit](demo.bit)为629624字节，生成于2026-10-05 00:07:09（Asia/Shanghai），归档与运行文件逐字节一致。

## 仿真

ModelSim SE-64 10.6e，2026-10-05约00:06（Asia/Shanghai），编译和两项仿真零错误零警告。

- 68ms符号链路：3200个样本完整发送并从三路TMDS输出重组，800音频包/66 ACR/5 InfoFrame；左右顺序、24位左对齐、192帧状态、BCH、奇偶校验、固定N/CTS及数据岛均通过。
- 独立Python实数正弦参考逐样本核对全部3200个输入，与440Hz/48kHz和16点LUT一致；左右相同、峰值−12000/+12000。包参考再核对实际发送PCM与输入相同、总数一致，无丢样或溢出。
- 原实际视频/PHY测试以SILENCE=0运行：两帧614400 RGB像素、1631次PCM握手、849998串行字；复位后307200像素、863次握手、449998串行字。厂商EG_LOGIC_ODDR模型核对三个数据通道低位先发及0000011111时钟。
- 测试文件和日志沿用S6命名，运行参数已切换为S7正弦音；不是把旧静音日志作为新证据。板级控制/面板未改，本次沿用S6已通过的回归及板级证据，未重复全套。

[编译](compile.log) · [包及视频](tb_hdmi_packets.log) · [真实视频与PHY](tb_hdmi_s6_phy.log) · [完整运行与独立参考](full_run.log)。tone_packets.txt为本轮样本及解码包。

复现：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_hdmi_s6_tests.ps1 -Stage s7
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_td_build.ps1 -BuildName audio_r2_s7_local1
```

## TD构建及时序

TD 6.2.168116，EG4S20BG256、top，综合/布局布线/bitgen完成。

| 指标 | S6 | S7 |
|---|---:|---:|
| Setup WNS / TNS ns | −6.699 / −295.870 | −6.699 / −295.004 |
| Hold WNS / TNS ns | +0.004 / 0 | +0.025 / 0 |
| 视频同域Setup WNS ns | +25.367 | +26.444 |
| 控制域Setup WNS ns | −0.387 | +0.189 |
| 内存同域Setup WNS ns | −0.219 | +0.178 |
| LUT / 寄存器 | 2809 / 2264 | 3230 / 2535 |
| BRAM / PLL | 4 / 3 | 4 / 3 |
| STA覆盖率 | 92.38% | 92.37% |

[路径组比较及限制](timing_comparison.md) · [时序](demo_pr.timing) · [资源](demo_phy.area) · [综合](build_syn_1.log) · [布局布线](build_phy_1.log)。新增音频/视频无负裕量，控制/内存内部本次为正；剩余SDRAM接口64端点违例，写侧有0.101ns退化。未改约束，原像素/串行exclusive覆盖限制仍在，不声称整机时序收敛。

## 上板与下一步

独立[上板验证文档](BOARD_VALIDATION.md)要求左右有声，连续至少10分钟无明显断音/杂音/画面异常，并验证手动/AUTO/模式/数码管。图片音调联动尚未启用。

用户确认S7通过后才建立板级节点并推送，再执行S8。异常先恢复已验收S6静音bit并停在S7定位。
