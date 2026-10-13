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

## 当前阻塞

- 最新attempt36（strategy5）为Setup -1.009ns（TNS -23.488ns）、Hold -0.020ns（TNS -0.070ns），仍无合格S2。扩展100端点报告确认71条setup、1条recovery（-0.038ns）及6条Hold负路径。16929 LUT、9339寄存器、4695 MSlice/4697 LSlice、52 BRAM9K、15 DSP；相对attempt34减少295 LUT和123 MSlice，但时序变差。BMP头检查20个Setup失败端点，最差offset→file_len.ce 8级/76%布线。102个工程输入与attempt36逐字节一致。完整分析见TIMING_STRUCTURE.md。
- 本轮保留UART队列同步BRAM及loading阶段，八条可用容量不变。adjust_queue_fields2：52864字段比较、真实UART字节、448次装载、440次满替换及576溢出事件通过；adjust_queue_subtitle1真实串口回复/日志仲裁通过，均零错误警告。adjust_queue_gate1在独立TD综合网表及厂商BRAM模型下通过线级日志（测试容量2），零错误、2446条厂商端口警告；生产容量8队列压力在RTL覆盖。未将旧长系统测试声称为本轮重跑。
- attempt35字幕选择简化通过124928字段比较及逐周期真实UART集成，但完整TD的字幕物理LUT增加20、时序恶化，已恢复该生产文件。复现脚本需指定attempt35的SourceRoot才测试撤回实验；默认测试当前源码。
- attempt34（历史）为Setup -0.356ns、Hold -0.005ns，24个最大延迟失败端点及2个Hold/removal失败端点。17224 LUT、9349寄存器、4818 MSlice；原scanner提交与短缓存地址负路径消除，但全局未收敛。
- 本轮scanner五路提交预寄存及短缓存写地址第3位恒等LUT已验证：adjust_scanner_commit1三种间隔、七种场景逐周期等价；adjust_commit_audio1包含512字节缓存循环；adjust_commit_reader1全部42项；adjust_commit_production2生产联合9279样本均通过。实际Routed MISO/缩放/短缓存恒等LUT厂商模型0/1验证通过，保留模型端口警告。production1因旧测试台漏连端口被拒绝，补齐后以production2为准。
- 前33次构建全部结束，无合格S2候选。按续接任务完成模块资源/真实路径分析后，本轮只将UART的T/S/D宽快照选择改为字段内选择；attempt33固定strategy5完整TD为Setup -0.216ns、Hold -0.020ns。UART物理LUT减少111，全设计LUT增加16、MSlice减少15，不能声称全设计LUT优化成功。详见TIMING_STRUCTURE.md。
- 本轮受影响验证：adjust_uart_fields1的52864次新旧格式化等价比对、原UART线级字节专项通过；adjust_uart_subtitle1的字幕命令/回复/日志仲裁集成通过。未将历史系统测试描述为本轮重跑。
- 最新源码已通过adjust_unit7六专项、adjust_syn3独立综合、adjust_gate4门级算术、adjust_top6生产顶层336271像素/1148样本；区域预计算adjust_scaler_edges1及计数器adjust_control_width1通过。长系统测试早于这些局部修正，不能冒称最终源码完整长系统重跑。

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
- attempt14：区域预计算后high为Setup -0.046ns、Hold -0.025ns；attempt15 ultra为-0.712/-0.020ns；attempt16不加高扇出优化的ultra出现布线资源冲突，均不能交付。
- attempt17/18/19：布局后及布线后选项、high布局/路由effort均未改善最终余量，仍为-0.046/-0.025ns。post_route_opt和额外轮次未列入器件生效参数表；effort已列入，但结果未改善。
- attempt20：无额外高扇出、high路由，Setup -0.464ns，Hold +0.011ns，尚不能交付。
- attempt21：内部乘法数据级自由运行后高扇出high为-0.548/-0.004ns；attempt22无额外高扇出/high路由为-2.692/-0.008ns，均不能交付。
- attempt23/24/25（strategy2/3/5）：分别-0.548/-0.004ns、-0.703/-0.012ns、-0.233/-0.004ns。
- attempt26/28/29/30/31（strategy6/8/9/10/11）：TD路径折线优化报PHY-8103 x_offset.size() <= 0。attempt30虽报告Setup +0.113ns，仍有Hold -0.008ns及工具错误，不能交付。
- attempt27（strategy7）：PHY-8023布线资源冲突。attempt32（strategy4）：-0.703/-0.012ns。所有失败产物仅保留diagnostics/output，未建立local标签。
- attempt33：UART字段选择器局部优化后，strategy5完整构建无工具ERROR，但Setup -0.216ns、Hold -0.020ns。仅各一条负路径：scanner状态→resource1_size（85%布线），以及短音频缓存cache_write[3]→RAM写地址。尚未修正这两处；不能复用attempt25的旧Hold端点。物理17357 LUT、9339寄存器、4786 MSlice、43 BRAM9K、15 DSP。未打包候选。
- attempt34：scanner提交使能预寄存+短缓存地址定点LUT后，完整构建无工具ERROR，但Setup -0.356ns、Hold -0.005ns，仍不打包候选。实际五路寄存器和恒等LUT均保留，功能验证通过；失败端点转移，整体MSlice占用上升，未建立local标签。
- attempt35：字幕回复字节选择改为直接半字节选择，完整TD无工具ERROR，但Setup -1.632ns（124端点）、Hold -0.020ns（3端点）；字幕LUT 868→888，无收益，生产修改已撤回。
- attempt36：UART队列实际映射9 BRAM，LUT/打包资源下降，完整TD无工具ERROR，但Setup -1.009ns、Hold -0.020ns；门槛脚本正确拒绝。新队列带来pending[1]→RAM和rd_ptr[1]→RAM两条负Hold，另有BMP/缩放/写FIFO/PCM RAM共四条。还有一条复位Recovery负路径，不能统一加数据延迟。无候选、无local/board标签，下一构建attempt37。
- 顶层注入初版未提供完整0–799行坐标，无法产生HDMI数据岛；adjust_top4补齐后通过，未为此修改生产RTL。
- adjust_preview1混合尺寸+故障注入运行到主动超时，被正常加载断言误判；现仅在显式预期超时时解除该断言，重新验证故障流程。不将失败日志计为完整通过。

## 板级状态

尚未上板。S2用户确认前不进入S3，不建立board标签。
