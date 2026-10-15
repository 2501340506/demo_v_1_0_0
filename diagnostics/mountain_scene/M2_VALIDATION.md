# M2 图像工具验证（2026-10-15）

本地实现、自检和专项已通过；用户目视、M1 板上底图显示、M3 灾害动画显示均尚未确认。本阶段没有新 bit，不建立 local/board 标签，不推送仍待 M1 板测确认的分支。

范围为 [make_scene_pack.py](../../tools/make_scene_pack.py)、[scene.yaml 与示意村](../../tools/scenes/demo_village/scene.yaml)、[工具与参考模型约定](../../tools/scenes/README.md)。功能基线/整机回退为 v0.16.0，当前 M1 候选保持 `v0.17.0-m1-local.1`（901f29e）。M2 未修改 RTL、TD 工程、best_result、用户已有 tools/PIC*/Qhc.wav/BGM.PCM/board_samples，也未重新构建或修改 M1 bit。

## 实际运行

环境为 Windows、Python 3.14.4、Pillow 12.3.0、numpy 2.5.4、PyYAML 6.0.3；所有 Python 命令使用 `py -I`。本机原来缺少 numpy/PyYAML，已按 [依赖清单](../../tools/scene_requirements.txt) 安装。M2 不用 ffmpeg 或 scipy；距离变换使用工具内的二遍3/4 chamfer。

```powershell
py -I tools/scenes/demo_village/make_inputs.py
py -I tools/make_scene_pack.py tools/scenes/demo_village/scene.yaml
py -I diagnostics/mountain_scene/test_scene_pack.py
py -I tools/make_scene_pack.py tools/scenes/demo_village/scene.yaml --output diagnostics/output/m2_demo_reproduce01
py -I tools/scenes/demo_village/make_inputs.py --output diagnostics/output/m2_inputs_reproduce01
```

首次生成目录和复现目录均是新目录；已有目录拒绝覆盖。后续重跑须另选目录，不能直接覆盖已入库素材。专项创建的临时证据留在 `diagnostics/output/m2_test_*`，未递归清理。

## 自动验证结果

[专项源码](test_scene_pack.py) 的8项测试全部通过，原始 UTF-8 日志见 [m2_tests.log](m2_tests.log)：

| 验证对象 | 实际结果 |
|---|---|
| BMP 文件结构 | 奇数宽度、正高度/自下而上、BGRA 四字节和末像素检查通过；拒绝错误 DIB、planes、位深、compression=3、零高度和截断负载 |
| 灰度与覆盖 | 灰度全部256值按 `gray*239//255` 量化正确；alpha=0、独立 mask 未覆盖为255 |
| 折线 | 转折后累计长度、0/239端点、宽度外255、重复点、起止时刻参数正确；零总长度拒绝 |
| 种子距离 | 多种子 chamfer 全图与独立闭式3/4距离相等；种子 mask、0/119/159/239量化和半径外255正确 |
| 合成优先级 | 多来源取最小到达时刻，避险点250最终覆盖其他来源；未覆盖255 |
| hazard 参考模型 | 四阶段×t=0/5/6/120/239×四种快/慢相位×全部256个T，20480像素与独立标量计算一致；包含前沿差值0–5/6、全保留区间、250/255以及两个旁路 |
| CLI 端到端 | 示意村4张BMP全部RGB/T反读一致；24张expected PNG保存后像素相等；四张图的避险点与未覆盖区正确、无保留T编码 |
| 已有输出保护 | 再次指定已有目录返回2，PIC1.BMP所有字节不变 |

全部四张 PIC 均为640×480，每张1228854字节，40字节 BITMAPINFOHEADER、planes=1、32bpp、compression=0、像素偏移54。反读采用原始字节解析器，不依赖图片软件对 alpha 的处理。PNG 参考图使用 BMP 反读结果计算，源图与显示坐标一致，后续 M3 可直接逐像素比较。

另做复现核对：38个输出文件（4 BMP、24 expected PNG、8 RGB/T 诊断 PNG、overview、manifest）与新目录重生成结果逐字节一致；4个输入 PNG 与绘图脚本重生成结果逐字节一致。范围和环境见 [m2_artifacts_check.json](m2_artifacts_check.json)，未制作文件哈希。

## 视觉检查与剩余门槛

已在本次开发中查看原尺寸底图和 [24图拼图](../../tools/scenes/demo_village/generated/overview.png)：底图包含坡体、沟谷、村庄、高地和道路；裂缝分段增长、沟谷内蓝色覆盖随t扩大、绿色路线通往高地，避险点亮/暗相变化。此项仅为开发检查，不代表用户目视验收或板测。

用户可先查看上述拼图与 `expected/` 原尺寸图。M1 固定 bit 显示不使用T，因此四张场景 BMP 的 RGB 相同是预期行为；M1上板时对照 `diagnostics/PIC*_rgb.png` 检查颜色和方向。原 M1 诊断卡仍保留，用于非640×480缩放回归。M3再确认裂缝/山洪/撤离动画与这些expected一致。

模型精确 RGB、混合完整和后右移及相位已冻结于工具说明与技术方案；种子扩散为教学用几何距离，不是地质/水文模型。音频、字库、文案、预警模式和帧计数分频留给后续阶段。

M2 本地工作完成，不需要 FPGA 仿真或 TD 重建；M1 板测仍待确认，M3 未授权/未实施。M3 进入前须具备 M1 板测通过反馈与 M2 参考素材确认。工具回退可使用本阶段之前的 `v0.17.0-m1-local.1` 源码入口；整机回退仍为固定 `releases/v0.16.0/demo.bit`，不移动旧标签。
