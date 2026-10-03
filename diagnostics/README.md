# 图片请求与按键回归测试

## 当前验收基线：v0.1.8

2026-10-04 用户确认第四阶段板级功能正常，全部四阶段完成。固定测试与构建证据见 releases/v0.1.8；下方“工作版本”标题保留阶段实施背景，不表示仍待验收。后续修改等待用户安排。

## 历史实施记录：第四阶段

第三阶段已获用户板级验收并发布 v0.1.7。第四阶段新增读侧显示提交确认：写完不立即释放旧缓冲，读侧采用新地址后再确认。原 14 项保留，加上第 15 项延迟显示 ack 测试；6 个控制顶层通过。

新增 `run_buffer_handoff.ps1` 在独立仿真库运行三组异步读写测试，修复后全部通过。`-Baseline` 对照旧控制器，前两组复现提前覆盖和混合帧，最慢一组原本就通过。完整模型范围、结果与板测步骤见 [第四阶段报告](STAGE4_BUFFER_HANDOFF.md)。最新日志前缀 stage4；以下第三、第二阶段说明是历史记录。

## 历史实施记录：第三阶段

2026-10-04 第二阶段 v0.1.6 已由用户板级验收通过并上传。第三阶段增加轮播小数点提示；6 个仿真顶层全部重新通过，0 errors、0 warnings，日志 `modelsim_check/stage3_tb_*.log`，完整执行日志 `stage3_suite.log`。

显示专项增加复位/首图前关闭、正常开启/关闭、加载中保持、组合提示共存、诊断模式关闭检查。真实按键集成测试同时核对开启/关闭轮播时的提示输出。顶层将提示经两级同步送到 50 MHz 扫描域，连接图片编号位 bit7（低有效小数点）；引脚 A6，沿用现有约束。顶层接线由 TD 构建检查，实际亮灭与物理位置由板级验收确认。

运行 `./diagnostics/run_control_tests.ps1` 重跑当前全部测试。以下阶段内容均保留为历史验证说明，当前最终基线为 v0.1.8，后续修改暂停。

## 历史实施记录：第二阶段

2026-10-04，第一阶段 v0.1.5 已获用户板级功能验收并上传原开发分支。当前第二阶段改为稳定按下后计时，增加手势活动接口。6 个仿真顶层通过：原 14 项图片回归、4 组真实组合窗口集成检查、路由/播放/显示专项以及 5 组手势专项。日志为 `modelsim_check/stage2_tb_*.log`。

运行 `./diagnostics/run_control_tests.ps1` 可重新编译并执行全部 6 个顶层。脚本检查 Fatal/Error、PASS 和零错误警告摘要，不只检查进程退出码。`tb_key_gesture_control` 使用真实同步/消抖、默认等效 100 ms 窗口和实际播放控制，验证稳定沿后 1000 周期长按、999/1001 周期分类、自动到期与稳定沿/组合等待冲突、组合部分释放、完整 3000 周期重新计时、超窗重叠及复位恢复。到期碰撞通过设置播放计数器定位，其余按键从真实输入驱动。

## 课程对照改进：阶段一

新增顶层 `tb_picture_chord_integration`，与 `tb_picture_requests` 同文件，共用 SD 扇区和写完成模型。默认旧顶层保留原 14 项断言；新顶层使用等效 100 ms 组合窗口、20 ms 消抖、1000 ms 长按，验证快速短按、两种组合顺序、超窗重叠单键、操作后恢复。按键由真实输入驱动。

按下方清单编译后，将仿真顶层替换为 `tb_picture_chord_integration` 即可运行。阶段一 5 个顶层全部通过，日志为 `modelsim_check/stage1_*.log`。其中 `stage1_baseline.log`、`stage1_old_router.log` 是独立旧代码反证测试，预期失败，不属于修复后通过日志。实际异步 SDRAM/FIFO 验证仍留待专项阶段。

## 原始回归基线（历史说明）

v0.1.0（2026-10-03）建立了下列 14 项回归；目前已随第二阶段重新执行并通过，最新结果以上方说明为准。

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

按键测试驱动实际输入；同拍仲裁测试局部 force 事件，自动边界测试设置计数器。模型未包含真实异步 SDRAM/FIFO、亚稳态或布线延迟。板级验收与仿真通过不等于时序收敛，最新构建结果见对应阶段验收说明。

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
    'user_source/hdl_source/SD/media_display_control.v'
    'user_source/hdl_source/SD/media_player_control.v'
    'user_source/hdl_source/SD/media_policy.v'
    'user_source/hdl_source/SD/dual_key_event_router.v'
    'user_source/hdl_source/SD/key_gesture_control.v'
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
Both simulations finished with 0 errors and 0 warnings. This historical extraction
subsequently passed TD and user board acceptance in v0.1.3.

## 显示策略拆分专项测试
入口 tb_media_display_control.sv，使用同一 RTL 清单编译，仿真顶层为 tb_media_display_control。覆盖正常图片 1～4、首图前 BMP 状态、全部诊断优先级、组合提示保持周期、重复触发续时、计数饱和和提示期间异步复位。缩放 CLK_FREQ_HZ=4，4 个周期代表 1 秒。日志：modelsim_check/display_tb_media_display_control.log。原有三个 testbench 同时回归，日志前缀 display_。
