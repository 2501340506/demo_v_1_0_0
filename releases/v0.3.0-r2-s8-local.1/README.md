# S8 图片音调联动候选

版本 `v0.3.0-r2-s8-local.1`，2026-10-05，已获用户上板确认。最近已验收为S7。固定 bit：[demo.bit](demo.bit)，629624 字节，生成于 2026-10-05 00:30:58（Asia/Shanghai），与TD输出逐字节一致。

## 行为

SD控制域在显示交接应答后发布已提交图片编号和valid；独立保持数据的请求/应答跨域传到25MHz像素域。接收前持续发送48kHz零PCM。首图（包括编号0）和后续每次成功提交都触发一次100ms/1.5kHz提示，然后播放对应六音琶音，每音250ms、固定音量128（峰值约±6000）、左右相同。图片0为C大调、1为A小调、2为五声音阶、3为高低交替。相位连续；不承诺切换绝对无咔声。失败/等待加载保持原旋律；不新增按键或调音设置。课程原件保存在reference，未修改。

## 验证

- ModelSim 10.6e编译及本阶段仿真零错误零警告。控制六项回归通过，图片14类场景中的74次提交逐次对应图片编号和一次提示事件，覆盖首尾循环、失败、等待、连续请求和AUTO。
- 异步CDC连续24次事件（包含重复编号）握手及保持数据通过；音源307381样本以实数正弦参考检查（允许1 LSB查表取整差），四组完整六音循环、4800提示样本、12000样本/音、首图静音、相位连续、固定幅度、背压和溢出通过。音源长序列测试加速时钟；HDMI包测试使用实际25MHz/48kHz。
- 媒体输入3200个PCM逐个匹配实际发送包，800音频包/66 ACR/5 InfoFrame，独立BCH/声道/奇偶校验/N/CTS检查通过。
- 实际视频时序和媒体输入接厂商ODDR，614400像素及复位后307200像素正确，849998+449998串行字逐位通过。日志沿用S6测试名称，本轮明确MEDIA=1、SILENCE=0。
- 三组异步帧缓冲回归通过，无旧缓冲覆盖或混帧。
- TD 6.2.168116综合、布局布线及bitgen完成；3366 LUT / 2576寄存器 / 4 BRAM / 1 DSP / 3 PLL。Setup −6.699 ns，Hold +0.025 ns，全局未收敛；控制域原BMP解析3个端点本轮退化为负。详见[逐路径组对比](timing_comparison.md)。

## 复现

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_control_tests.ps1 -Prefix s8
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_buffer_handoff.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_hdmi_s6_tests.ps1 -Stage s8
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_td_build.ps1 -BuildName audio_r2_s8_local1
```

本目录附固定工程清单、约束、运行配置、构建日志、仿真和包记录。重建可能因工具环境影响布局，以本目录固定bit用于验收。

## 上板

执行[BOARD_VALIDATION.md](BOARD_VALIDATION.md)。用户确认后再记录板级标签、推送已验收节点并进入S9；当前不推送候选，不合并main。

## S8板级反馈

2026-10-05用户确认“S8通过，开始下一阶段”。记录整体上板通过，未额外提供逐项设备、运行时长或测量数据；固定bit和时序限制保留。

板级标签：`v0.3.0-r2-s8-board.1`。按计划推送已验收节点，开始S9。
