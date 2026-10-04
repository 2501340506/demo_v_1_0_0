# 第3课 HDMI音频原始参考

2026-10-04从用户本机目录`D:/My_Program/安路/资料/拓展系列/第四讲：HDMI音频输出基础/第3课_HDMI音频基础/`复制全部14份Verilog原件，内容未修改。讲义为同级`第3课_HDMI音频输出基础.md`。这些文件是参考归档，不在TD工程或活动仿真编译清单内，避免与活动同名模块冲突。原目录未附独立许可证，本项目保留来源，不另行声明授权。

## 活动实现

`user_source/hdl_source/hdmi_audio/`包含10个课程HDMI模块及改写的media_hdmi_audio_bridge。BCH、ACR、symbol_core和bridge有下列修改，其余7个HDMI文件沿用原件：

- BCH按发送顺序逐字节低位先行，以右移和0x83反馈计算；原版按字节高位先行，不能匹配mapper发出的码字。
- ACR保留字节SB0=0，CTS在SB1..3，N在SB4..6；原版把保留字节放在SB6，造成整体错位。
- symbol_core由VS下降沿及x=656确定固定525行栅格，仅在下一有效行前发送视频前导/保护带；原版在垂直消隐每行也发视频前导。启动时等待首次VS下降沿锁定，此为后续集成需要保持的固定640×480接口约定。
- bridge保留整组视频寄存器，改为外部测试音/媒体PCM valid-ready接口。选择在样本受阻时锁定至接受沿，不在S5提前接入图片控制或媒体旋律。

课程pcm_test_tone由S2的48kHz实现替代；pcm_media_tone仅参考归档，待S8处理显示提交、使能及跨域；m06_pcm_contract_adapter仅归档，S5直接使用明确的握手选择及仿真检查，不添加同功能监测器。媒体旋律生成与图片联动未在S5验收。

## 独立核对资料

2026-10-04只读核对hdl-util/hdmi的下列实现及其HDMI规范章节注释，未复制其RTL进入活动实现：

- https://github.com/hdl-util/hdmi/blob/master/src/packet_assembler.sv — 发送位顺序与BCH，HDMI第5.2.3.4节/图5-5。
- https://github.com/hdl-util/hdmi/blob/master/src/audio_clock_regeneration_packet.sv — ACR子包字节布局，第5.3.3节。
- https://github.com/hdl-util/hdmi/blob/master/src/audio_sample_packet.sv — 音频样本、B标志及奇偶校验，表5-12/5-13。
- https://github.com/hdl-util/hdmi/blob/master/src/hdmi.sv — 视频前导仅在即将开始有效视频的行发送。

独立Python参考使用多项式长除法核对BCH，端到端测试从三个TMDS输出重组包，而不是读取内部packet_body作为结果。测试源选择与调度锁定检查会读取内部握手状态以确认覆盖。
