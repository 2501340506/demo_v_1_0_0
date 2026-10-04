# S9 旧链路清理与复位候选

`v0.3.0-r2-s9-local.1`，2026-10-05，已由用户确认上板通过。S8已由用户整体确认通过并推送。S9上板确认后才发布v0.3.0及归档，不提前宣布正式版本完成。

固定[demo.bit](demo.bit)：629624字节，生成于2026-10-05 01:02:06（Asia/Shanghai），已与TD输出逐字节比较一致。

## 最终实现

- 活动TD清单移除8项旧I2S、音频PLL、旧ACR、官方加密HDMI发射器、AXIS转换及其辅助源；原文件保留。详见[source_inventory.md](source_inventory.md)。
- 仅保留系统/视频两颗PLL，导出原extlock。外部复位或任一PLL未锁定立即断言复位；面板50MHz、SD控制100MHz、内存125MHz、像素25MHz、串行125MHz分别在本域3个上升沿后释放。按键复位不重新启动PLL；失锁会重置所有消费者。
- 提交CDC分离源/目标域复位，PHY分离像素/串行复位，并复位串行装载和ODDR流水线，避免重启残留事件。双端CDC复位来自同一复位请求，不能任意单独复位一端。
- 清理顶层失效连线，帧缓存地址/长度显式使用ADDR_BITS宽度，消除原隐式24→21位截断告警，默认地址和值不变。
- 移除原像素/串行互斥约束，保留两PLL时钟推导和命名，无新增例外。图片、三键、四模式、数码管、四图旋律、固定音量128和DDC高阻行为保持。

## 本轮证据

ModelSim 10.6e全部本轮编译及仿真零错误零警告；TD 6.2.168116完整综合/布局布线/bitgen完成。

| 验证 | 结果 |
|---|---|
| 实际顶层复位 | 5组启动/锁定先后/视频停钟失锁/系统失锁/按键及在途提交复位恢复；每域同步释放、无残留图片事件、复位后零PCM及新首图提示、DDC高阻 |
| 真实视频与厂商ODDR | LOCAL_RESET=1、MEDIA=1；614400像素+复位后307200像素，849995+449995串行字逐位匹配 |
| 媒体与HDMI | 4组完整旋律、307381样本、24次连续CDC、3200实际发送PCM/800包，独立BCH及N/CTS/InfoFrame验证 |
| 图片/按键/模式/面板 | 6项控制及面板通过，74次实际显示提交逐个对应音频更新；快速请求、等待/失败和AUTO覆盖 |
| 异步帧缓存 | 3组时钟/来源速度回归，未混帧、未覆盖旧显示缓冲 |
| PCM与基础封装 | 独立440Hz参考、节拍/FIFO、256 BCH向量、1024 TMDS向量、双源选择/背压及800个模式样本包通过 |
| 视频对齐 | 800×525总时序、640×480有效区、整行坐标、RGB与S1参考、复位恢复通过 |

顶层复位测试使用真实top/控制/音频/PHY，但PLL时钟和lock、SDRAM与FIFO存储是行为模型；不代替实际PLL锁定时间、物理SDRAM或上电测试。独立缓冲仿真负责存储交接功能。PHY日志沿用S6名称，本轮命令明确LOCAL_RESET=1及MEDIA=1。

## 构建限制

3301 LUT / 2590寄存器 / 4 BRAM / 1 DSP / 2 PLL。Setup −6.565ns，Hold +0.004ns，STA覆盖99.86%。新增复位/音视频路径为正，原BMP解析违例本轮消失；剩余64个SDRAM接口违例，写侧比S8退化0.133ns。全局未收敛，见[路径组对比](timing_comparison.md)。

## 复现

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/history/v0.3.0/run_s9_reset_tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/history/v0.3.0/run_control_tests.ps1 -Prefix s9
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/history/v0.3.0/run_mode_tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/history/v0.3.0/run_buffer_handoff.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/history/v0.3.0/run_audio_tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/history/v0.3.0/run_hdmi_packet_tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/history/v0.3.0/run_video_alignment.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/history/v0.3.0/run_hdmi_s6_tests.ps1 -Stage s9
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_td_build.ps1 -BuildName audio_r2_s9_local1
```

附工程清单、约束、运行配置、构建日志、各组最终仿真及包记录。固定bit用于本次验收，后续构建不得覆盖本目录。

上板按[BOARD_VALIDATION.md](BOARD_VALIDATION.md)。不推送候选，不合并main。正式v0.3.0和完成文档归档等待S9板级反馈。

## 2026-10-05早先问题反馈（保留历史，最新结论见下）

用户反馈：复位偶发末位卡0；复位后末位2时立即拔SD卡会一直2；连续下一张未完成时按KEY3复位，也有概率卡0。第三项以用户最新更正为准。尚无设备、精确次数或故障内部状态记录，不补造。

停留S9分析处理，不发布v0.3.0。固定bit保留供复现。代码分析和两项缺陷复现见[SD恢复分析](../../docs/diagnostics/s9_sd_recovery/analysis.md)，当前未生成修复bit。

## 最新验收与范围确认

2026-10-05用户确认“S9通过，开始下一阶段，我提到的问题不在这一版本修改，也先不做相应修改”。S9按用户结论验收通过；SD复位偶发卡0、扫描/读头拔卡卡2及连续翻图中复位卡0作为已知问题保留，明确暂不修改。未补造逐项设备、次数或运行时长。

沿用原固定bit，建立`v0.3.0-r2-s9-board.1`及正式`v0.3.0`节点，完成归档；不修改RTL、不重建bit、不合并main。此前“未通过/暂停发布”的临时结论由本条用户确认取代。
