# M1：32bpp 像素加载验证

基线 `v0.16.0`，生产改动仅限五个 SD 加载/缩放文件。SDRAM 格式为 `{R,G,B,T}`；32bpp 的第四字节直接作为 T，24bpp 和黑边为 FF。保留 decoder 的 24 位 `pixel_rgb` 兼容端口，新增 `pixel_rgba`；缩放链路沿用 `pixel_rgb` 名称但宽度为 32。

`tb_rgba_decoder.sv` 覆盖宽度 1–5、24 位行填充、可变 alpha、连续文件字节、像素背压、最后像素排空、缺 alpha、BI_BITFIELDS 拒绝和恢复。旧 decoder 矩阵另覆盖最后字节与 file_end 同拍。

`tb_rgba_stream.sv` 从 BMP 字节流检查 640×480 输出，按数学坐标独立计算最近邻结果；覆盖 24/32bpp、1:1、放大、缩小、竖图黑边、扇区门控及背压。既有 scaler 测试扩为 32 位并使用坐标相关 T；旧 24bpp stream/FAT32 测试核对 FF。

`tb_rgba_sdram.sv` 复用四 bank 系统连接及卡服务模型，使用真实双时钟 FIFO、安路 SDRAM 控制器和 command/DQ 模型；四种 32bpp 尺寸逐像素检查实际 SDRAM 写入、读出 T、RGB、地址及完整帧。SD 卡在扇区级建模，SPI 协议不属于本专项。

`make_fixtures32.py` 复用原 42 种 FAT32 布局/故障；3 像素宽的 24/32 位行同为 12 字节，直接替换 BGRA 负载，测试 preflight 和固定解码支路。缩放支路另跑同一用例。

## 运行

```powershell
# 完整专项及受影响回归；Prefix 必须是未使用的输出前缀。
& diagnostics/mountain_scene/run_m1.ps1 -Prefix mountain_m1_verify
# 工具路径可通过 -SimRoot/-TdRoot 指定。
& diagnostics/mountain_scene/build_m1.ps1 -BuildName mountain_scene_m1_attempt01
& diagnostics/mountain_scene/run_legacy.ps1 -Suite audit -RunName mountain_scene_m1_attempt01
py -I diagnostics/mountain_scene/make_test_bmps.py diagnostics/output/mountain_m1_samples
```

默认使用 `F:/modelsim/win64` 的 ModelSim SE-64 10.6e 和 E:/TD。本次 decoder/scaler/FAT32 已用 Intel Starter 10.5b 通过；长回归因 Starter 容量限速改用 SE，保留主动停止的旧输出。适配器复用旧脚本的测试矩阵，不改写旧路径设置。原始日志保留：已知 IP 可选端口告警 `vsim-3017/3722`、受保护模型未定宽常数 `2121`、Starter 容量提示与历史 vopt 类别可接受。SE 的完整系统编译另有一条 `vlog-13288`（`Multiple macros defined in +define+ command line switch.`），来自旧 runner 将多个宏放在同一参数；打包器仅接受该准确文本，未知编译告警仍拒绝。其他告警和所有错误均拒绝。不能把含已知告警的日志写成零告警。实际结果以候选 `VALIDATION.md` 及原始日志为准。

PowerShell 重定向的编译/TD 日志为 UTF-16，打包器按 BOM 解码检查并保存原日志。

构建快照仅放 `diagnostics/output/`。打包器逐字节核对工程全部输入、bit 和备份，源文件仅保存相对 `v0.16.0` 的变化，不使用文件哈希。

## 上板素材

生成四张标准 40 字节 DIB、compression=0、自下而上 BGRA BMP 和对应 640×480 RGB PNG：640×480、160×120、801×601、317×479。红/绿横纵渐变、蓝色四象限、白边用于识别方向、颜色和黑边；T 为坐标图样，覆盖全部 256 种字节。生成器逐字节反读检查 RGB/T。M1 显示不使用 T；此工具仅制作诊断卡，场景配置、灾害参考模型属于 M2。
