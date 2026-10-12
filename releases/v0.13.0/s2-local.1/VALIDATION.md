# v0.13.0 验证记录

## S1（2026-10-12）
- ring_s1_unit3：幅度/负满幅/握手/饱和/上升下降/静音/缺样/历史回绕/帧快照通过；两拍RGB和HS/VS/DE/X、关闭透传通过。编译和仿真零错误零警告。
- 独立Python胶囊几何参考与1,228,800个RTL像素一致；预览位于diagnostics/output/ring_s1_unit3/ring_0.png～ring_3.png。
- ring_s1_music3：本地BGM.PCM第10秒起的片段，20个RTL画面，16,121个采样，柱高随音乐变化；music.gif/music.png为实际仿真绘图，非板测。
- ring_s1_syn1：独立TD综合通过。overlay 206 LUT、21 BRAM9K；levels 1491 LUT、547寄存器、1 BRAM9K。ROM实际物理分配高于逻辑位数估计；加上基线12个BRAM，预计34/64，等待生产构建确认。
- 历史失败：unit1命名碰到SV关键字；unit2测试未考虑半组旧峰值，静音补足97组后通过；music1/2缺少仿真依赖/包含路径，music3仿真通过，预览脚本修正ModelSim十进制文件名空格后生成成功。
- S1无生产bit，无local/board标签。S2和板测尚未完成。

## 复现
先运行tools/generate_audio_ring.py，再运行run_unit.ps1（新RunName）、check_pixels.py对应输出目录、run_music.ps1和run_synthesis.ps1（新BuildName）。已有输出不覆盖。

## S2 已完成的本地检查
- ring_s2_production1：接入圆环与延迟后视频的生产HDMI音频桥，9,279个样本逐项比对通过；碎片循环、重扫排空、错误回退/重试、缺音乐、纯音频冷启动和短循环通过。
- ring_s2_audio_units1：扫描、音源切换、流读取3项通过。ring_s2_regression1：21项按键/播放/音频/HDMI/SD/复位/日志/帧缓存/视频对齐回归通过。
- ring_s2_osd1：全部OSD串接，1,695,744个圆环外像素与原显示链路一致，40,064个圆环变化像素；首次图片和图片切换通过。
- ring_s2_music4：修正预览输入，按生产pcm_stream_player将PCM算术右移一位；重新完成20个RTL帧和动态预览。交付使用music4，不使用幅度偏大的早期music3预览；生产RTL/bit未变。
- ring_s2_attempt1：完整TD成功，bit 654,068字节；Setup +0.101ns、Hold +0.004ns，覆盖率99.97%；14,858 LUT、7,928寄存器、34 BRAM9K、4 DSP、1 PLL。约束未修改。
- timing_audit：无无时钟节点、组合环或无效约束；保留基线相同分类的dummy节点、异步/低速接口延迟提示。PLL条目内部无未约束引脚、无频率不匹配。
- ring_s2_gate5：独立综合后的圆环与RTL比对109,443个像素，覆盖0/14/28高度，验证BRAM初始化内容和流水线。1731条厂商模型警告：vopt-2675=1、vopt-2685=150、vopt-2718=1512、vsim-3016=68；不是零警告仿真，也不代表整机门级验证。
- TD保留既有SDRAM ECO位置、局部时钟提示；新增geometry无驱动提示已通过BRAM推断及上述综合后比对验证。
- 旧pcm_audio/audit_cdc.ps1的get_clocks多名称查询为空，输出实际是未筛选路径；该输出不作为专门CDC验证证据、不收入发布报告。新增PCM采集/快照/绘图均在video_clk，无新增跨域路径；原音频握手与跨域模块未改。
- 历史gate1～4为脚本路径、Verilog语言模式、厂商库依赖问题；gate5修正运行环境后通过，未改生产RTL。
- ring_s2_system1完整系统回归正常退出：582帧、22次提交、472955个PCM样本逐项正确、5次音频会话、无欠载/溢出；17次转场（2次AUTO擦除、15次手动淡变）、4组UART、字幕/计时/底带检查通过。18条既有模型/可选端口警告，零错误。
- 完整系统台架覆盖既有真实SDRAM/图片/转场/PCM/OSD系统；新增圆环由独立像素参考、生产HDMI音频桥及全部OSD串接专项覆盖，不将旧台架描述为整机顶层圆环仿真。
- 本地检查完成，交付目标v0.13.0-s2-local.1；90个工程输入与成功构建逐字节一致，固定bit 654068字节。板测、20分钟、Flash及完全断电冷启动尚未执行。
