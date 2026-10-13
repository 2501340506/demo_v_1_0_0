# v0.15.0 S2验证记录

## 已通过

- S1五项专项；最终按键事件寄存/计时位宽和OSD共享BCD修改后，adjust_unit5六项通过，增加全部256个画面值和11档音量的十进制转换检查。
- adjust_syn2：六个独立模块综合通过。
- adjust_gate3：图像9216组向量和音量11档/背压/渐变通过TD导出门级网表验证。门级日志中的未接原语端口/方向警告来自器件模型，无数值不一致。
- adjust_regression2前16项、adjust_regression_tail1后5项：21项基础回归全部通过。原脚本补AL_MAP_LUT1模型；复位静音检查改为最终pcm_tap，避免对已出队源FIFO无效数据作断言。
- adjust_control_final1：最终按键RTL的模式控制、重扫、顶层复位再次通过；adjust_preview_keys1四宫格按键通过。
- adjust_top5：最终生产顶层，在解码像素与音源边界注入；336271个像素时序、1148个音频样本通过，覆盖默认、非默认参数、预览边框、转场黑色、无图黑色、音源切换、静音。该测试不模拟TF介质，也不代表板测。PLL模型端口宽度和未连接物理输出警告保留。
- adjust_system1：真实SDRAM完整系统591帧、22次提交/提示音、17次淡变、481827个PCM样本通过；UART四阶段、字幕/底条/时间逐像素检查通过。该轮在KEY4媒体事件寄存前启动，最终按键改动由adjust_control_final1及最终预览联合测试覆盖；不宣称该轮包含新总音量级，新级由门级与生产顶层测试覆盖。
- adjust_preview_final1：最终按键RTL的真实SDRAM预览/音乐/重扫/故障恢复165帧、60预览帧、10提交/提示音、139171个PCM样本通过，无欠载/溢出。使用标准尺寸，混合尺寸历史失败日志不计为完整通过。
- 后续根据attempt6实际最长路径，将缩放器每图不变的行末坐标提前寄存，接口和有效输入的周期行为不变。adjust_scaler_endpoint1十尺寸逐像素及取消通过，adjust_stream_endpoint2五尺寸完整BMP字节流逐像素通过；上述长系统测试在这处等价预计算之前执行，未冒称重跑。

## 进行中

- adjust_s2_attempt14：根据attempt12缩放区域控制长路径，将每图不变的显示区域终点提前寄存；adjust_scaler_edges1十尺寸缩放和五尺寸BMP字节流逐像素通过，周期不变。high完整TD运行中。此前局部RAM数据恒等LUT的adjust_scaler_hold1、adjust_unit6六专项和adjust_control_width1四项回归通过。

## 历史失败及修正

- attempt1：新增工程源清单未写入；修正精确的XML结束标签匹配后解决。
- attempt2：Setup -0.031ns、Hold -0.060ns，不能交付。
- attempt3：ultra布线资源冲突，未生成合格候选。
- attempt4：高扇出优化后4902个MSlice超过4900上限；改用不启用该额外优化的构建脚本。
- attempt5：关闭额外高扇出优化后完成布线，但Setup -1.076ns、Hold -0.011ns，不能交付。
- attempt6：OSD共享BCD后Setup -1.638ns、Hold -0.002ns；报告最长路径为缩放器宽度减1再比较的捕获控制链，已据此局部处理。
- attempt7：行末预计算后high构建Setup -1.287ns、Hold -0.011ns；负路径分散于扫描器及加载控制，布线占比较高。
- attempt8：同源码ultra构建Setup -0.943ns、Hold -0.020ns，仍不能交付。随后收窄原有32位消抖计数器以减少占用，未改变消抖周期。
- attempt9：收窄后ultra/high构建Setup -0.009ns、Hold -0.020ns，仍不能交付；Setup仅两个失败端点，最差Hold在音频缓存RAM地址短路径。
- attempt10：high/high构建Setup +0.120ns、Hold -0.011ns；唯一失败端点为缩放行RAM数据输入。attempt11使用ultra/ultra，结果与attempt9相同，不能交付。
- attempt12：局部恒等LUT后high构建Setup -2.110ns、Hold -0.004ns，布局变化使Setup恶化；不能交付。
- attempt13：同源码ultra最终完成布线，但Setup -0.368ns、Hold -0.020ns；不能交付。
- 顶层注入初版未提供完整0–799行坐标，无法产生HDMI数据岛；adjust_top4补齐后通过，未为此修改生产RTL。
- adjust_preview1混合尺寸+故障注入运行到主动超时，被正常加载断言误判；现仅在显式预期超时时解除该断言，重新验证故障流程。不将失败日志计为完整通过。

## 板级状态

尚未上板。S2用户确认前不进入S3，不建立board标签。
