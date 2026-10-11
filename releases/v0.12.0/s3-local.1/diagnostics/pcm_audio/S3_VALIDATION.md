# S3 生产接入验证（本地通过，待上板）

基线为 v0.11.0，阶段回退为 S1 已验收的 `releases/v0.12.0/s1-local.1/demo.bit`。S3 本地候选为 `v0.12.0-s3-local.1`，尚未获得板测确认。

## 实现

`fat32_bmp_reader` 导出音频文件与卷几何，并开放共享服务音频客户端。`sd_card_bmp` 在扫描结果接受后启动独立音频文件流；重扫先停止音频、等待物理事务与播放器双域停止握手，再复位读卡与扫描状态。单张图片取消只作用于图片客户端。

生产顶层启用 AUDIO_ENABLE，沿用 100MHz/25MHz 单 PLL；4096 样本环形缓冲、2048 预填充、48kHz 输出与 128/256 音量。经已验证的保持型音源选择器接入现有 HDMI 桥，未选中琶音持续消费。未启用音频的历史测试仍采用默认参数。

## 已通过

- `pcm_s3_units1`：音频发现、背压音源选择、碎片链/并发文件读取专项。
- `pcm_s3_reader1`：42 个 FAT32 图片读取用例。
- `pcm_s3_regression1`：21 项控制、SD 协议、复位、视频和 HDMI 音频回归。
- `pcm_s3_production5`：真实生产 sd_card_bmp、播放器、音源选择和 HDMI 桥，9,279 个输出样本逐项比较；四图后跨根目录簇发现、碎片文件循环、在途重扫、读失败回退与重试、无音频回退、仅音频新启动、两字节短文件循环。零错误、零警告。
- `pcm_s3_attempt5`：完整 TD 通过，TimingOptimization=high、PostPlaceOptimization=high；Setup +0.100ns、Hold +0.004ns、覆盖率 99.96%。13,204 LUT、7,282 寄存器、12 BRAM9K、4 DSP、1 PLL。87 个工程输入与当前源码逐字节一致。

时序审计：无无效约束、无时钟缺失、无组合环路；保留既有 PLL buffer、dummy node 与板级未约束端口分类。音频 4096×16bit RAM 推断为 BRAM（固定除二后最低位无用途，综合优化输出宽度）；短文件缓存也采用 BRAM。综合网表保留 wr_sync1/2、rd_sync1/2、run1/2、ack1/2 两级链。

音频两域来自同一 PLL，现有相关时钟 STA 覆盖交叉路径，不增加 false path 或放宽约束。扩展时序报告抽样的 rd_gray→rd_sync1 Setup 最小 +8.699ns、Hold +0.244ns，wr_gray→wr_sync1 Hold 最小 +0.399ns，run1 Hold +0.253ns、ack1 Setup +7.982ns / Hold +0.581ns；全设计最终 Setup/Hold 均通过。完整网表留在 diagnostics/output/pcm_s3_attempt5/pcm_cdc_audit，交付保留时序报告。

## 完整系统

- `pcm_s3_system3`：正常退出，零错误，18 条既有模型/可选端口警告。真实 SDRAM、四 bank、手动/AUTO/两种转场、字幕 UART、计时及背景 PCM 逐样本对照通过。
- 582 个显示帧、22 次提交与对应事件、15 次缓存命中；2 次 AUTO 揭示、15 次手动淡出淡入、180,326,400 个转场像素比较。
- 472,955 个 PCM 样本逐项正确、5 次播放会话，无欠载/溢出；并发图片加载、缓存切换、重扫、图片错误重试与超时后缓存切图通过。
- 4 组字幕 UART 命令在帧边界应用，时间/滚动字幕/透明底带共 246,539,248 次像素及消隐检查。仿真耗时 23 分 34 秒，这是主机仿真耗时，不是板级持续试听时长。

## 失败历史与修正

- system1 的测试声明语法错误，已修正后启动 system2。
- system2 在 366 帧时旧缓存断言把音频 SD 请求也计为图片读卡，导致失败；此前 294,143 个 PCM 样本逐项正确。改按共享服务 owner 统计图片请求，保留“缓存命中不得重新读取图片”的断言，重新运行 system3。没有改生产 RTL 或重建 bit。
- attempt1 的工程文件缺少新增模块 CompileOrder，TD 无法打开；补全后 attempt2 完整构建成功。
- attempt2：Setup −1.171ns、Hold +0.011ns，覆盖率 99.97%，不交付。违例位于原 SD 诊断到数码管路径，音频路径无 Setup 违例。资源为 13,191 LUT、7,274 寄存器、12 BRAM9K、4 DSP、1 PLL。
- attempt3：ultra 布局优化触发 TD 无效物理引脚错误；改用 high/high 后 attempt4 通过，没有修改时序约束。
- attempt4 最终警告审阅发现新增模块 CompileOrder 重复，改为独立的 200/201/202 后 attempt5 通过；RTL 和约束不变，最终候选使用 attempt5，重复序号警告已消除。
- production1 错把 KEY4 当作重扫键，测试看门狗结束；改为长按 KEY2。
- production2 对仅音频卡错误要求清除旧画面；基线重扫保留旧画面，修正断言只检查图片数量，production3 通过。
- production4 新启动测试曾立即读到复位前计数，补齐等待 active 先低再高，production5 实际增加 700 个仅音频新启动样本。

板级试听、切图不断音、长时播放、Flash 和冷启动尚未执行；不将 S1 确认外推为音频验收。
