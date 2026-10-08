# BMP 2.11 S2 本地候选：待上板

本目录 demo.bit 为原 S2 候选，打包调整没有修改或重新生成 bit。

## 源码保存规则

releases 只备份本次新增或修改的用户代码：

- sources/hdl_source/SD/bmp24_decoder.v
- sources/hdl_source/SD/bmp_read.v

其他源码使用仓库对应版本，不在 release 重复备份。project/demo.al 的两个改动模块引用本包 sources，其他源文件引用仓库 user_source。因此本目录不是脱离仓库的完整工程包。

未改动源码已逐文件移到本地 diagnostics/output/decoder_s2_release_full_sources，不属于发布包；没有批量删除文件。后续阶段也采用只保存改动代码的规则。

## 验证与状态

独立 640×480 与 3×2 解码矩阵、新旧路径对照、稳定性、帧交接及重扫恢复本地验证通过。TD Setup +0.096 ns、Hold +0.037 ns、STA 99.93%；6360 LUT、4098 寄存器、4 BRAM、4 DSP、1 PLL。历史失败日志和 IP 警告仍保留。

新 decoder 驱动像素输出；S2 暂留旧头校验与完成判定，尚未完成整个 2.11。生产仍只显示原有 24 位格式，独立模块的 32 位测试不代表生产支持 32 位显示。

按 BOARD_VALIDATION.md 验证本目录 demo.bit。UART 启动行仍为 v0.5.4-s3-local.2。回退为 releases/v0.5.4/demo.bit。尚未建立 board 标签、未推送 GitHub；用户确认后继续 S3。