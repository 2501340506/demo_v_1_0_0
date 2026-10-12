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
