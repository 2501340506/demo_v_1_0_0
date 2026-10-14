# v0.16.0 S2 local.1 候选

- 基线：v0.16.0-s1-board.1（S1 已验收）；回退 releases/v0.16.0/s1-local.1/demo.bit 或 releases/v0.15.0/demo.bit。分支 feature/lut-optimization，源码提交 9999cb3，构建 diagnostics/output/lut_opt_attempt11（配置同 S1，约束/时钟/引脚未改）。
- 上板文件：本目录 demo.bit（662216 字节，与构建产物逐字节一致）。
- 改动：HDMI 音频包 BCH 共享、ACR/InfoFrame 常数直出；簇号→扇区地址逐拍移位、按索引加载（删除重复图片表）；字幕提交装载时判定变化；数码管单译码器；两处新关键路径的等价寄存（cache_control image_last、PCM 启动检查）。
- 资源/时序：14190 LUT（S1 15072，v0.15.0 15402，累计 −1212 / −7.9%）、8250 寄存器、3969/4015 MSlice/LSlice、54 BRAM9K、13 DSP；Setup +0.144ns、Hold +0.003ns。
- 验证：validation/ 137 份通过日志，见 LUT_RECORD.md S2 节。
- 已知限制：仅本地仿真与 TD 通过；簇偏移逐拍移位使扇区请求晚 0–7 个 100MHz 周期，不影响可见行为；Hold 余量 3ps，以板测为准。attempt07/08 同输入 TD 两次崩溃，网表变化后消失，记录于 LUT_RECORD.md。
- 板测：按 BOARD_VALIDATION.md（原 1–19 项 + 本阶段 20–26 项），请反馈候选名及实际通过/异常项。
