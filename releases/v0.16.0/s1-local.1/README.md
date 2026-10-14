# v0.16.0 S1 local.1 候选

- 基线：v0.15.0；总回退 releases/v0.15.0/demo.bit。分支 feature/lut-optimization，源码提交 0a47a58（测试台修正 37861bc 不影响生产输入），构建 diagnostics/output/lut_opt_attempt02（HighFanoutOptimization、PlacementStrategy 5、opt_timing high、post_place_opt high，约束/时钟/引脚未改）。
- 上板文件：本目录 demo.bit（662216 字节，与构建产物逐字节一致；与 v0.15.0 bit 大小相同为器件固定长度格式，内容不同）。
- 改动：功能不变的 LUT 缩减 S1（批1–3）：提示音固定增益改 FIFO 后常数表、亮度对比度饱和位判断；帧写/读静态长度按突发计数、写地址单加法器、缩略图地址共享乘积；SD 超时计数器、PCM 播放相位、短文件回放比较、scanner 布局检查收窄。
- 资源/时序：15072 LUT（v0.15.0 为 15402，−330）、8490 寄存器、4200/4201 MSlice/LSlice、54 BRAM9K、13 DSP（−2）；综合 14357 LUT（−407）。Setup +0.109ns、Hold +0.004ns，时序审计 14 类与 v0.15.0 一致（dangling 节点 4→3）。
- 验证：validation/ 91 份通过日志：批1–3 旧新逐周期等价（含变异体检出）、scanner 对 v0.15.0 等价、21 项基础回归、42 项 FAT32 读取、调节 6 项、HDMI/提示音、缩放、四宫格按键、帧路径/双写入/缩略图物理存储、生产 PCM、生产顶层（336271 像素/1148 样本）、真实 SDRAM 预览（165 帧）与完整系统（591 帧、365203 次刷新），后两项统计与 v0.15.0 逐项相同；亮度对比度与音量门级 9216 组向量。详见 LUT_RECORD.md。
- 已知限制：仅本地仿真与 TD 通过，未上板；Hold 余量 4ps 与 v0.15.0 相同，以板测为准。
- 板测：按 BOARD_VALIDATION.md（v0.15.0 第 1–12 项 + 本阶段 13–19 项），请反馈候选名及实际通过/异常项。
