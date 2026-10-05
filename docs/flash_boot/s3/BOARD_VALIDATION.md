# S3验收记录

状态：执行中，等待用户独立冷启动确认。

## 已有证据

- 2026-10-05用户确认S2通过并授权进入S3；S2 bit不变。
- 本轮通过Windows UI Automation只读提取已打开BitWriter的信息栏，保存为[bitwriter_observed.log](bitwriter_observed.log)。未发送下载命令、未重复烧写。
- 日志包含S1与S2历史操作；用于S3的是文件路径含`v0.5.0-s2-local.1/demo.bit`的最后一组。
- 该组显示芯片验证EG4S20BG256成功、Flash厂商字节ef、program_spi与verify_spi完成、最终Downloading succeeded；界面状态PROGRAM_FLASH success，下载器AL-LINK。
- 日志使用flashsize 128，与用户W25Q64/64Mbit资料不一致，不能由ef推断完整型号。后续重烧按实际容量64M设置，不将128写成推荐值。

## 待用户提供

| 项目 | 结果 |
|---|---|
| 不依赖下载器，真正断电后重新上电 | 待确认 |
| 自动首图、编号正常 | 待确认 |
| 首图提示音与旋律正常 | 待确认 |
| 启动模式/跳线（如已知） | 未提供；不猜测 |
| Flash完整丝印（如已知） | 用户资料为W25Q64；后缀未提供 |

见[操作指南](../S3_FLASH_GUIDE.md)。未建立S3 board标签，不进入S4、不发布最终版本、不上传。
