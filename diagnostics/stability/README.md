# v0.4.0活动验证

在仓库根目录使用PowerShell：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/stability/run_stability.ps1 -Suite baseline
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/stability/run_stability.ps1 -Suite recovery
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/stability/run_stability.ps1 -Suite headers
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/stability/run_stability.ps1 -Suite scan
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/stability/run_stability.ps1 -Suite scan -CompareS2
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/stability/run_regression.ps1 -Stage s1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_td_build.ps1 -BuildName stability_s1
```

输出位于diagnostics/output；固定证据位于本目录evidence及对应releases候选。ModelSim位于D:/modelsim/win64，TD构建入口默认D:/TD/anlogic/TD6.2.1。

## 覆盖

- baseline：真实bmp_read，生成4个640×480 BMP图头及连续扇区，独立按行列计算RGB，比较全部307200像素；S1起另检查唯一load_done、无错误。
- recovery：真实bmp_read与sd_card_bmp，4×1小图加速控制场景；一次重试成功、MAN两次失败保留显示、首图跳过、首图全部失败停止、AUTO跳过/一轮失败停止、手动恢复、SDRAM迟到完成和显示确认前保持错误。失败不产生提交/音频通知。
- headers（S2）：20组头样本分别经过真实扫描和加载；标准头、V4/V5扩展头、额外偏移、DIB/planes/完整32位尺寸/位深/压缩/偏移/长度拒绝；附加不复位错误后正常加载、坏头后好图混合扫描，总计22组PASS。缺少可用头时scan_done且找到数为0，不应有写请求。
- scan（S3）：14组扫描测试，覆盖可信不支持尺寸/位深、行填充、非BMP/坏结构/短长度退回逐扇区、扫描边界及地址不回绕。CompareS2从已验收标签读取真实旧解析器，实测相同布局800×600图后的好图读取数2814→2、32位图2402→2、带行填充小图4→2；不是按耗时猜测。
- 控制与缓冲测试从v0.3.0复制至活动目录，保留历史原件。控制测试仅把“首尝试失败后重试成功且挂起请求完成”的预期提交数调整为2；缓冲模型增加显式load_done/无错误端口。
- 其余6个既有入口直接复用历史脚本；HDMI物理链路选择s9配置。

SD扇区、写应答和存储为行为模型。恢复专项的坏头在扫描结束后注入，确保命中“已登记图片加载失败”，不是仅验证扫描忽略坏头。异步缓冲测试继续检查真实frame_read_write所有权及不撕裂，音频实际CDC/提示由控制回归验证。

本轮不验证物理SD卡热插拔恢复，不把旧缺陷复现当成修复结果。最终上板确认由用户填写。

S2本地上板图片可运行`python diagnostics/stability/make_s2_samples.py`生成，输出到diagnostics/output/stability_s2_samples；仅写本机文件，不访问TF卡。固定候选随附同一批图片的ZIP。

S3运行`python diagnostics/stability/make_s3_samples.py`生成2张可信但不支持显示的BMP及4张正常图。保持同一张卡内容不变，对比已验收S2和S3候选；具体步骤见候选BOARD_VALIDATION。
