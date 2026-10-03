# 图片请求与按键回归测试

## 当前基线

v0.1.0（2026-10-03）已获用户板级功能和稳定性认可。ModelSim SE-64 10.6e 最近一次回归为 14 组 PASS，编译、仿真均 0 errors、0 warnings。本次仅整理文档，没有重新执行测试。

测试入口为 [tb_picture_requests.sv](tb_picture_requests.sv)。旧诊断过程已归档至 [历史记录](../docs/history/2026-10-03/DIAGNOSTICS_HISTORY.md)，后续以本文件说明为准。

## 验证范围

1. 首图图头失败后重试，成功前不提交。
2. 连续同方向请求合并为当前加载与一个 pending。
3. 双向请求排空，长按不启动轮播。
4. 20 轮连续加载。
5. 图头失败释放忙状态、保留原图，后续按键可恢复。
6. 失败期间已挂起请求保留。
7. 已开始写入时等待 SDRAM 完成，不提前提交。
8. KEY1 等效按住 2 秒仅触发一次，释放再按可再次触发。
9. KEY2 阈值两侧分类正确，长短按互斥。
10. 延迟写完成期间 KEY2 长按仅挂起一次。
11. 自动到期与 KEY1 稳定按下同拍时手动优先。
12. 四图 next/next/previous 实际加载顺序正确。
13. 同方向 pending 消费同拍的新事件保留。
14. KEY2 长按阈值及短按释放与自动到期冲突时不启动自动加载。

实际控制器、消抖模块及 BMP 解析器参与仿真。CLK_FREQ_HZ=1000，20/1000/3000 周期分别代表消抖/长按/轮播；2 秒保持以 2000 周期缩放。扫描四张 4×1、24 位 BMP，按扇区生成不同像素。写应答延迟四个控制周期，写完成可以单独延迟。

按键测试驱动实际输入；同拍仲裁测试局部 force 事件，自动边界测试设置计数器。模型未包含真实异步 SDRAM/FIFO、亚稳态或布线延迟。板级验收与仿真通过不等于时序收敛：本次 TD 构建 Setup WNS -6.699 ns、Hold WNS +0.011 ns。

## 重跑方法（PowerShell）

在项目根目录执行；ModelSim 默认安装路径为 D:/modelsim/win64。运行库写入本地忽略目录，可重复使用。

```powershell
$simTools = 'D:/modelsim/win64'
$simDir = 'diagnostics/modelsim_check'
$simLib = "$simDir/work"
New-Item -ItemType Directory -Path $simDir -Force | Out-Null
if (-not (Test-Path -LiteralPath "$simLib/_info")) {
    & "$simTools/vlib.exe" $simLib
    if ($LASTEXITCODE -ne 0) { throw 'vlib failed' }
}
$rtlFiles = @(
    'user_source/hdl_source/SD/media_player_control.v'
    'user_source/hdl_source/SD/media_policy.v'
    'user_source/hdl_source/SD/dual_key_event_router.v'
    'user_source/hdl_source/SD/sd_card_bmp.v'
    'user_source/hdl_source/SD/bmp_read.v'
    'user_source/hdl_source/SD/sd_card_top.v'
    'user_source/hdl_source/SD/sd_card_sec_read_write.v'
    'user_source/hdl_source/SD/sd_card_cmd.v'
    'user_source/hdl_source/SD/spi_master.v'
    'diagnostics/tb_picture_requests.sv'
)
& "$simTools/vlog.exe" -work $simLib -sv @rtlFiles
if ($LASTEXITCODE -ne 0) { throw 'vlog failed' }
& "$simTools/vsim.exe" -c -quiet -voptargs=+acc -lib $simLib tb_picture_requests -l "$simDir/regression.log" -do 'run -all; quit -f'
```

检查完整日志中 14 条 PASS、正常结束以及 Errors/Warnings；不能只看进程退出码，也不能将旧日志视为新代码的验证结果。

## 本地文件管理

| 文件或目录 | 用途与处理 |
| --- | --- |
| README.md、tb_picture_requests.sv | 当前说明与回归源码，纳入 Git |
| modelsim_check/ | 当前回归编译库及重跑日志，留本地，可重新生成 |
| modelsim_work/、modelsim_work_4img/、modelsim_work_delay/ | 旧验证产物，仅本地保留，不作为当前验证依据 |

上述 ModelSim 目录均已被 Git 忽略。原 HANDOFF 编码备份已移到 docs/history/2026-10-03/HANDOFF.before_event_refactor.bin，并继续忽略。无需为文档整理删除仿真库；如果后续需要批量清理目录，按项目约定由用户手动处理。
## Media control extraction (2026-10-03)
The 14 integration cases pass using the extracted controller. Hierarchical injection
now targets u_media_player_control; no legacy pending registers remain.
Compile diagnostics/tb_media_player_control.sv with the same RTL list and run
 tb_media_player_control for acceptance, current committed index, direction priority,
same-cycle capture, single-image wrapping, and exact autoplay boundary checks.
Latest logs: modelsim_check/control_fixed.log and control_unit_fixed.log.
Both simulations finished with 0 errors and 0 warnings. TD synthesis and board tests
have not been run for this change.
