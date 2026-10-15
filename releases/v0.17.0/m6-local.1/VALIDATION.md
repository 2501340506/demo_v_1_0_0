# M6 local.1 本地验证

日期 2026-10-16；开发输入 v0.17.0-m5-local.1（34d7a82），生产实现 bc19864；仿真 ModelSim SE-64 10.6e（F:/modelsim/win64），物理实现 Tang Dynasty v6.2.168116（E:/TD）。下列本机结果不能替代板级结论。

## 专项与整机回归

完整系统 mountain_m6_system01 已通过：591 帧、481827 个精确 PCM 样本/五会话，无 underrun/overrun；17 次转场/17 黑帧、183705600 转场像素；598 帧快照、251159248 OSD 像素/消隐检查，UART 四阶段，字幕/时钟/灰带、缓存命中/AUTO/重扫/失败重试/坏图跳过/超时缓存切换均通过。

预览 mountain_m6_preview01（Mixed=1、Audio、Failures）通过：293 帧、200 个预览帧、10 次提交/提示，238405 个精确 PCM 样本/四会话，无 underrun/overrun；前台加载失败保留预览、重试、超时后选择缓存图均通过。

最终共检查并保存 118 份仿真日志、36 份编译日志及四份 PC 工具日志（19 项测试），均通过选定 PASS 标记、错误检查及已知告警清单核验。

双卡文字分别 4778947/4778973 次视频束检查；双卡生产顶层分别 684745/685006 次最终 HDMI 检查。真实 EG4 双时钟 BRAM，扇区服务→loader→BRAM→CDC→文字叠加；KEY4 AUTO、KEY1 长短互斥、完整终态后自动切阶段、四阶段/预警/面板均覆盖。场景 PCM 173939 个精确样本、11 会话，含普通 AUTO 进入场景继承、缺 SND3/BGM 回退、无音频帧计时。原 PCM 两项 9279/9280 样本。

24bpp 和 32bpp FAT32 各全 42 例；32bpp 缩放 case0..3；解码两组尺寸、缩放、五项 SD 等价/物理 SPI、五项控制和五项 FONT/TEXT 资源测试通过。SD 锁步包含五组参数，至少 1011617 次逐拍比较。PC 工具 8+4+3+4=19 项通过，两卡各 44 个文件逐字节复现，警报采样率/幅度/扫频和文案转义独立检查。

完整运行名、逐项 PASS 标记及原始编译/仿真证据保存在 validation/ 和 logs.json；复现命令及测试边界见 [M6_TESTS.md](../../../diagnostics/mountain_scene/M6_TESTS.md)。旧整机测试台不例化场景文字，必须结合双卡顶层/文字专项；扇区注入不等于真实 SD 卡 SPI，SPI 由专门引脚测试覆盖。缩放相位使用强制帧计数采样，不作为硬件时间测量。

## TD、审计和文件固定

选定 mountain_m6_attempt02：placement strategy 7、high fanout、high route effort、high area optimization、timing optimization high。

| 项目 | 最终报告 |
|---|---|
| LUT / 寄存器 | 15083（76.95%）/9751（49.75%） |
| BRAM9k / BRAM32k / DSP | 56/2/13 |
| Setup / Hold | +0.101ns / +0.019ns；STNS/HTNS 均 0 |
| STA | 双角 Slow/Fast，覆盖率 99.97% |
| bit | 673856 字节；无 ERROR、完整 Generate bitstream completely |
| 工程输入 | 当前工作区与隔离构建的 111 个工程输入及根构建脚本逐字节相同 |

审计汇总同 M5：相对 M1 仅新增 EG_PHY_BRAM32K 的两个 dummy 输出 `g_scene_text$font_ram/ram.dob[9]`、`g_scene_text$text_ram/ram.dob[9]`，其余汇总及例外相同。未将此描述为无审计差异。归一化综合/物理告警与 M5 相同；打包同时按 M1 基线拒绝未知新增告警，只允许已记录的两个可选 placement 提示。保留原报告与已知 IP 端口/PLL/多宏提示。

package_m6.py 拒绝非正时序、未知仿真告警、TD ERROR、不完整 bitgen、未知审计变化、输入不一致和覆盖候选。只保存四个变化生产文件，其余引用 M5；局部 .gitattributes 对全部候选文件禁用 Git 换行转换，reports/validation/sources 另保留工具生成的空白，不生成文件哈希。冻结后的 bit、源文件、报告、日志及双卡均逐字节核对拷贝；暂存时发现六个元数据/复现脚本有换行转换，补全此属性后重新逐字节核对全部候选文件，未改 RTL 或 bit。

复现 TD（使用新 BuildName）：

```powershell
& diagnostics/mountain_scene/build_m5.ps1 -BuildName mountain_m6_new -PlacementStrategy 7 -HighRouteEffort -HighAreaOptimization -TimingOptimization high
& diagnostics/mountain_scene/run_legacy.ps1 -Suite audit -RunName mountain_m6_new
py -I -X utf8 diagnostics/mountain_scene/package_m6.py mountain_m6_new --candidate m6-local.new
```

## 未采用结果与边界

- TD attempt01 Setup −0.138ns/Hold +0.024ns、attempt03 Setup −0.185ns/Hold +0.004ns，均未交付；失败报告保留在本地 diagnostics/output。
- reader3201 错把所有故障用例用于缩放，case24 元数据假定访问上限 4，而缩放 streamer 上限为 16384，故报 bad image succeeded；仅选该目录 case0..3，通过的不缩放 32bpp 全 42 例来自 reader3202。没有掩盖此失败或为它修改生产 reader。
- cards_tool01 的枚举断言误把顶层 14 项当作递归 44 文件；改成 rglob 后 cards_tool02 通过，素材未变。PC unittest 在 stderr 输出，PowerShell 可显示 NativeCommandError 包装；以正文 Ran N tests/OK、无 FAILED 核验。
- M5 独立板测、M1/M3 单独板测及 M2 目视不倒填；M6 板级 SD/HDMI、警报声学效果、40 分钟、冷启动及换卡耗时均待用户反馈。
