# v0.5.2-s3-local.1（待板测）

本候选采用用户通过 TD 6.2.1 生成的单 PLL：50 MHz 输入，C0/C1/C2/C3/C4 为 100/40/40/25/125 MHz，C2 相对 C1 为 172.8°（12 ns）。生产顶层仅实例化该 PLL，五域复位由唯一 locked 驱动，SDRAM 周期为 25 ns。

- bit：`demo.bit`
- TD 参数：`-HighFanoutOptimization -TimingOptimization ultra -PostPlaceOptimization high`
- TD 时序：Setup WNS +0.168 ns，Hold WNS +0.041 ns；SDRAM 硬核边界路径单独保留在完整报告中。
- 仿真：PLL 周期/相位、单 PLL 复位、启动、SD 协议与 CRC、既有控制/音频/HDMI/视频回归通过。
- 刷新表达式：40 MHz 下终值 1249，含端点为 1250 周期；实际板级刷新服务仍需结合 S3 板测确认。

## 板测表（用户填写）

|项目|结果|备注|
|---|---|---|
|SRAM 首图|待确认||
|连续翻图|待确认||
|AUTO|待确认||
|HDMI 音频|待确认||
|复位|待确认||
|正常重扫|待确认||
|拔卡插回恢复|待确认||
|扫描/加载中恢复|待确认||
|换卡首图|待确认||
|保图、MAN、单次提示音|待确认||

本候选未通过板级验收前，不建立 board 标签，不进入 S4，不上传远程标签。
