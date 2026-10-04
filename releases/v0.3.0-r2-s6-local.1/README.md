# R2 S6 新核心静音上板候选

2026-10-04，分支`feature/hdmi-audio-v0.3.0`，标签`v0.3.0-r2-s6-local.1`。**仿真、TD构建及用户上板验收通过，全局时序未收敛。** 用户于2026-10-05确认S6通过，沿用固定bit，板级标签v0.3.0-r2-s6-board.1。

下载[固定demo.bit](demo.bit)，按独立[上板验证文档](BOARD_VALIDATION.md)操作。本阶段应有正常图片且持续静音。

## 变更

top以S5符号核心替换旧官方发射器，输入S4对齐的HS/VS/DE/x/RGB，保留原PHY。S2模块提供25MHz域48kHz分数节拍和8样本FIFO握手，传入编码核心的左右样本固定为零，DDS输出未消费可被综合裁剪。时钟符号固定1111100000，经现有PHY低位先发。

DDC SCL/SDA均为inout并赋高阻，位置P2/R2及原上拉约束不变，未接独立EDID。官方核启动读请求不再实例化；旧I2S/AXIS模块源和未消费实例暂留，S9再清理。旧音频PLL保留锁定信号作为复位依赖。

TD清单新增PCM与11份新HDMI源码。首次构建发现被裁剪的audio_mclk造成空时钟约束，最终移除其失效rename及异步组引用；没有新增或放宽时序例外。原像素/串行exclusive约束沿用，完整约束整理仍在S9。

## 仿真

ModelSim SE-64 10.6e，2026-10-04 23:53—23:54（Asia/Shanghai）。编译、静音包、真实视频流水线/PHY、六个控制及面板测试均0 errors、0 warnings。

- 静音包：68ms、3200个零样本全数按序解码，800音频包/66 ACR/5 InfoFrame，4帧共1228800有效像素；BCH、状态、奇偶校验、N/CTS及数据岛时序均通过。
- 真实链路：color_bar→video_timing_data→video_delay→新bridge→原PHY，FIFO读口用同步模型供给带位置标记RGB。两帧614400像素解码正确，1631个零样本握手，849998个串行字逐位比较通过。
- 复位重启后再验证一帧307200像素、863个零样本及449998个串行字。
- PHY使用TD安装目录原版eg_logic_io.v的EG_LOGIC_ODDR及eg_phy_glbl.v模型，25/125MHz、固定1ns相位偏移；三数据通道bit0先发，时钟每字0000011111，所有通道同步。未用替代ODDR模型宣称厂商行为。
- 六个控制及面板测试通过；帧缓存未修改，既有异步缓冲证据沿用S1。上述测试不等于完整板级top的物理SDRAM/PLL/HDMI电气仿真。

[编译](compile.log) · [静音符号](tb_hdmi_packets.log) · [真实视频与PHY](tb_hdmi_s6_phy.log) · [完整运行及独立参考](full_run.log) · [控制](control_run.log) · [面板](panel_run.log)。

复现：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_hdmi_s6_tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_control_tests.ps1 -Prefix audio_r2_s6
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_mode_tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_td_build.ps1 -BuildName audio_r2_s6_final
```

## TD构建与时序

TD 6.2.168116，EG4S20BG256、top。综合/布局布线/bitgen完成。固定bit为629624字节，2026-10-04 23:54:57生成，归档与运行文件逐字节相同。

| 指标 | S4 | S6 |
|---|---:|---:|
| Setup WNS/TNS ns | −6.699 / −293.242 | −6.699 / −295.870 |
| Hold WNS/TNS ns | +0.003 / 0 | +0.004 / 0 |
| 视频同域Setup WNS ns | +27.772 | +25.367 |
| 视频含跨域WNS ns | +4.282 | +4.128 |
| 控制域WNS ns | +0.203 | −0.387 |
| 内存同域WNS ns | +0.149 | −0.219 |
| LUT / 寄存器 | 4157 / 3871 | 2809 / 2264 |
| BRAM / PLL | 20 / 3 | 4 / 3 |
| STA覆盖率 | 95.85% | 92.38% |

[路径组及退化定位](timing_comparison.md) · [完整时序](demo_pr.timing) · [时序例外](demo_exception.timing) · [资源及引脚](demo_phy.area) · [综合](build_syn_1.log) · [布局布线](build_phy_1.log)。

新增视频/音频像素路径无违例；控制域3端点为BMP file_len判定路径退化，内存内部4端点为原帧缓存控制路径退化，另有64个旧SDRAM接口违例。不能把本次全部负裕量统称为旧SDRAM问题，也不声称时序无回退。原像素与串行exclusive关系导致其装载跨域STA未覆盖，静音常量裁剪后的资源不能外推至S7。

最终空时钟组告警已消除；仍有既有IP端口/位宽/初始化、SDRAM位置及局部时钟布线警告。首次构建与约束保存于[历史目录](../../diagnostics/history/2026-10-04/audio_r2_s6_first_build/README.md)。

## 下一步

按BOARD_VALIDATION.md检查启动、颜色/四边、三键、AUTO、四种模式、数码管和稳定静音。用户确认S6通过后才建立板级标签、推送S6及S5前置节点，再进行S7正弦音接入。异常先恢复已验收S4固定bit并停在S6定位。
