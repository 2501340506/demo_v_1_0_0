# S3：W25Q64固化与首次独立上电

2026-10-05。S2已获用户整体上板确认，本地标签`v0.5.0-s2-board.1`。本阶段沿用[S2固定demo.bit](../../releases/v0.5.0/v0.5.0-s2-local.1/demo.bit)，629624字节，不改RTL、不重新构建、不另复制bit。

## 当前实际情况

本轮只读检查了已打开的BitWriter界面，提取[现有日志](s3/bitwriter_observed.log)。其中S2路径对应的`program_spi`和`verify_spi`均完成，最后显示`Downloading succeeded!`，状态栏显示`PROGRAM_FLASH success !`。这是已存在的实际操作证据，本轮助手没有点击Run或重复烧写。

日志识别器件EG4S20BG256，界面下载器AL-LINK；TCK转换日志为5MHz，命令含`-v`。显示的Flash ID仅为`ef`（厂商信息），不能由此判定完整型号或容量。

**剩余验收：用户确认断电、移除下载器、独立上电后首图和声音正常。** 当前设备列表显示No hardware不推翻历史成功日志，也不证明已做过断电验证。

本次成功日志使用`-flashsize 128`，而用户提供W25Q64为64Mbit。保留该差异，不把历史128M设置写成推荐配置。后续重新烧写时按板载实际容量选64M；当前已有编程校验成功，不要求仅为文档再烧一遍。

## 本机工具与来源

- 已安装`D:/TD/anlogic/TD6.2.1/bin/bw.exe`；TD菜单为 **Tools → BitWriter**。课程中的旧Download/Hardware Setup/Auto Detect名称不直接套用。
- 官方说明：`D:/TD/anlogic/TD6.2.1/doc/SWUG/SWUG110_BitWizard_User_Guide.pdf`，第4章。PDF第11–13页说明启动、Refresh和Run/Add；第20页Program Flash，第22页Verify Flash，第23页文件选择与信息栏。
- 官方支持直接选择`.bit`，无需本任务另生成BIN、SVF或合并文件。
- 本机`doc/config/flash.json`有W25Q64FV/JV/FW/JW配置项，ID字段相同而部分操作参数不同。若界面要求细分型号，按芯片丝印/板卡资料选择；EG4实际界面可能仅显示MemorySize，无需寻找不存在的型号框。

## 如需重新烧写，按实际BitWriter操作

1. 板卡供电，连接原先验证正常的AL-LINK/JTAG。打开Tools → BitWriter，点击Refresh，确认识别EG4S20BG256。
2. 用Add选择上述S2固定bit；核对文件路径、器件EG4S20BG256。不要换成TD运行目录或旧S1 bit。
3. Mode选择 **Program Flash**，MemorySize按W25Q64选择 **64Mbit**（8MB）。TCK可沿用成功日志对应5MHz，不把Flash芯片最大SPI频率当作下载器速率。
4. 单一启动镜像使用默认主区；若出现StartAddress，选择`0x000000`。不启用Dual Boot/Multi Boot，也不改变当前位流配置。
5. 启用界面提供的Verify选项并Run。若该界面没有合并校验选项，编程成功后用 **Verify Flash** 对同一文件运行一次。确认信息栏编程与校验成功；本次已保存的日志包含这两个步骤。
6. 固化会更新现有启动镜像。恢复方式见下方，不额外执行Erase Flash整片擦除操作。

## 当前只需完成的独立上电检查

1. 保持正常测试TF卡和HDMI连接，关闭开发板电源。
2. 移除下载器与板卡的JTAG连接，保证不通过下载器连接给板卡供电。
3. 用板卡正常供电方式重新上电，不点击任何下载按钮。
4. 等待原有扫描时间，确认自动出现首图、图片编号正确，出现一次首图提示音并播放对应旋律；可再按一次下一张确认运行。
5. 反馈“脱离下载器断电上电后，首图/声音正常”，或记录黑屏、数码管状态及其他现象。

启动模式以实际板卡为准：如果本来已固定为Flash/MSPI启动且上述检查通过，不需要改跳线；如果不启动，再按具体板卡原理图确认模式选择，不能猜跳线位置。用户提供的配置引脚（CS=P8、HOLD=R9、SDO=N8、SCLK=M9、WP=P9、SDI=P7）作为板卡资料保留，不添加到业务顶层或ADC。

## 通过条件、恢复与下一步

S3要求编程校验成功加至少一次独立冷启动成功。当前前者有日志证据，后者待用户确认；S2的整体通过不自动等于S3冷启动通过。

恢复运行可用[S1固定bit](../../releases/v0.5.0/v0.5.0-s1-local.1/demo.bit)或[v0.4.0](../../releases/v0.4.0/demo.bit)做Program SRAM；要恢复掉电启动镜像，则对相应文件做Program Flash和校验。

用户确认S3后建立本地`v0.5.0-s3-board.1`，进入S4对同一固定bit进行10轮断电启动、10轮复位、30分钟AUTO及100次有效翻图；目前不预记这些结果。最终S5前不上传GitHub。
