# 验证范围与限制

新增诊断 RTL：detail 专项验证逐图片隔离、请求关联、FAT/BMP/内存优先级及重试/提交/重扫清除；case0 四场景16图、菜单取消/持键等；case16首图先于FONT/TEXT；case18真实坏签名两次失败得到41并在成功重试后清除；case19真实25MHz pixel/音频分频、模拟外存，手动及AUTO四页、场景四阶段和预警PIC4通过。diag_spi_audio19额外使用BYTE_GAP48和真实HDMI音频桥背压。

frame19_retry增加接近真实的16.8ms帧周期，25MHz pixel及真实HDMI背压，外存模拟；测试在应用切换后等待场景首图/音频握手就绪再发导航，覆盖宣传手动四页、场景四阶段和预警PIC4，不覆盖AUTO。

case23是改诊断前相同业务逻辑的证据：完整640×480的24/32位图、64扇区/簇、BYTE_GAP48和持续PCM、真实音频静音反馈，内存writer/reader模拟；该次旧bench像素71.4MHz，音频分频参数25MHz，不能宣称板级音频速率。

真实SDRAM writer/controller/reader联合combined19_retry仅完成宣传手动四页；进入场景后持续等待，在5.4秒仿真处人工停止，未完成，不计PASS，记录放validation/incomplete。此前case21在3秒watchdog失败。上述联合覆盖仍有缺口，不能据此声称整体显示链路验证完成，也未将等待判为板上根因。独立reader逐RGB测试是此前分项验证。case18诊断断言初次误写43，实测坏签名为41，纠正测试预期后通过，生产RTL未因此改变。

上述测试均未复现用户板上的故障；实体卡FAT布局、物理SD传输、实板显示与启动性能尚待验证。不能把本地通过当作板级通过，不能把本候选称作修复版。本轮不写卡、不改资源、不提高SPI频率、不放宽SDC。
