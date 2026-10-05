# R2 S2 独立PCM模块交付

日期：2026-10-04。本地标签：`v0.3.0-r2-s2-local.1`。分支：`feature/hdmi-audio-v0.3.0`。纯模块阶段，无bitstream或上板要求，不推送。

从历史`v0.3.0-s2-local.1`只恢复PCM源码、测试平台及运行脚本；脚本移除EDID入口，输出到独立目录`diagnostics/modelsim_audio_r2_s2`。课程16点正弦LUT来源说明保留在模块头部。

## 模块行为

25MHz时钟、平均48kHz使能、32位DDS，440Hz、峰值±12000的有符号16位双声道同样本。valid/ready接口和8样本FIFO，背压期间队首稳定，满时同拍出队仍能接收新样本。真正溢出丢弃新样本，节拍及相位继续前进，overflow保持到复位或禁用。禁用在时钟沿清空FIFO及相位，重启从零相位开始；无效期间数据不作保证。

## 本轮验证

运行：`powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/history/v0.3.0/run_audio_tests.ps1`。

ModelSim SE-64 10.6e，2026-10-04 22:47（Asia/Shanghai），编译/仿真均0 errors、0 warnings，五组PASS：

1. 100ms内4800次采样，每25000周期48次使能、间隔520/521周期；独立实数正弦参考检查样本、双声道及±12000幅度，440Hz检查通过。
2. 背压期间稳定，恢复后有序出队。
3. 满FIFO同拍出入队，无溢出。
4. 持续背压时保持溢出标志，不破坏已排队样本。
5. 禁用清空、重新从零相位开始及复位。

[编译日志](pcm_compile.log) · [仿真日志](pcm_test.log)

顶层和TD清单未变，本阶段不评估综合资源及时序，不表示新音频已上板。板级恢复仍用S1固定产物，原时序限制保留。下一阶段跳过S3，执行S4视频坐标对齐。
