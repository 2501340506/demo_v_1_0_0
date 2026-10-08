# v0.7.0-s3-local.1：FAT32 生产接入候选

固定 bit：demo.bit（629624 字节）。本地 TD attempt7：Setup +0.104 ns、Hold +0.014 ns；8890 LUT、5686 寄存器、4 BRAM、2 DSP。尚未上板验收。

基线为 v0.7.0-s1-board.1，源代码在 feature/fat32-filesystem；S2 核心在本候选加入生产并分拍收敛时序。source/SD 仅备份相对基线新增/修改的四个 RTL；project/demo.al 是实际构建配置快照，不是可独立打开构建的完整工程。完整隔离构建留在 diagnostics/output/fat32_s3_attempt7。

支持 FAT32 直接引导或首个 0B/0C 主分区、根目录完整簇链和碎片文件；固定 PIC1.BMP～PIC4.BMP，缺图允许，按文件编号形成紧凑列表。只支持当前分辨率的未压缩 24 位 BMP。禁止将本地仿真结果解释为实卡碎片/高 LBA 已验收。

加载保留原按键、轮播、音频与双缓冲交接。扫描预检完成后才加载首图。文件目录长度限制输出；SD 失败/超时进入停机恢复，坏图按原策略重试/跳过。UART 包不变，地址记录最近实际物理 LBA；启动版本行仍是历史文本，请按本固定 bit 路径识别候选。

构建使用 high fanout、ultra timing、high post-place，未调整时钟约束。64 个工程输入与构建快照逐字节一致，固定 bit 与构建产物逐字节一致，见 evidence/source_inputs.txt。未纳入用户 best_result、旧候选工程或个人记录。

硬件回退：releases/v0.6.0-bmp211/s3-local.1/demo.bit（v0.6.0-bmp211-s3-board.1）。S1 原路径验收 bit 也仍保留在 releases/v0.7.0/s1-local.1/demo.bit。

[板测步骤](BOARD_VALIDATION.md) · [S3 验证记录](../../../docs/fat32_s3_validation.md)
最终验证：核心 42 个场景、包装器 42 个素材加 5 个边界/格式模式，以及 run_s3.ps1 的全部 16 个验证入口通过。精简实际输出见 evidence/validation.txt 和 evidence/core.txt。
