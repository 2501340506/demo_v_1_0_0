# v0.5.0 Flash与启动验证

在项目根目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/flash_boot/run_baseline.ps1 -Stage s0
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/flash_boot/run_reset_tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/flash_boot/run_reset_tests.ps1 -BaselineTop
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_td_build.ps1 -BuildName flash_boot_s1_local5 -HighFanoutOptimization
```

基线脚本复用当前稳定性七项解析器/控制专项、真实解析器异步缓冲三配置及八个旧入口（当前控制/缓冲版本）。输出到`diagnostics/output/flash_boot_s0`，固定证据在本目录evidence。不要并行执行会共用仿真工作库的旧入口。

S1仅改顶层PLL复位，新增专项验证模型必须实际响应reset并等待重新锁定；其他生产模块不变时复用本轮S0证据，不反复执行无关回归。ModelSim行为PLL/存储不证明实际冷启动，用户SRAM上板通过后才进入S2。

`tb_flash_reset.sv`基于既有S9顶层测试扩展，不改历史原件。新模型用参考时钟计数重锁，reset撤销旧锁定并停止输出；两个时钟树可分别停钟。五轮覆盖系统先锁、视频先锁、两个PLL各自停钟恢复及在途提交中复位，逐域检查三拍释放，复位后静音且新提交只产生一次提示音。锁定周期为测试参数，不代表实际PLL模拟特性。

`-BaselineTop`使用S0顶层执行相同测试，必须在“两颗PLL未接收到按键复位”断言处失败；该负对照日志中的一次Fatal是预期结果，不混入正向通过统计。测试曾把toggle请求位为1误当作在途条件，已改为检查ready变低（请求与应答不一致），不修改产品握手逻辑。

最终构建使用TD的place hfn_opt_effort=high，解决默认布局出现的两个SD复位recovery负端点。复位RTL属性尝试均已撤回。旧调用不带开关仍用默认medium；GUI复现必须手动设置同一物理参数。最终证据见releases/v0.5.0/v0.5.0-s1-local.1，未上板。

## S2启动顺序

S1已获用户整体上板通过。S2运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/flash_boot/run_reset_tests.ps1 -Suite startup
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/flash_boot/run_reset_tests.ps1 -Suite startup -BypassReady
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/flash_boot/run_reset_tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/flash_boot/run_baseline.ps1 -Stage s2
```

新tb_startup使用真实顶层、sd_card_bmp与bmp_read，复用S1的PLL/FIFO/存储模型，仅控制两种初始化完成电平。独立逐拍参考检查两拍同步；TF先就绪、内存先就绪、近同时、等待期间复位四种场景均检查未就绪无业务活动、就绪后一次扫描、等待不复位SD初始化。BypassReady只强制忽略门控，必须在提前扫描断言失败，是预期负对照。

七个直接实例化sd_card_bmp的当前及历史可执行测试入口显式接sdram_ready=1，保留各自原测试语义；历史证据快照不改。测试日志分别输出flash_boot_startup、flash_boot_startup_negative、flash_boot_reset、flash_boot_s2。恢复/像素/缓冲等实际数据路径由完整回归验证；专项初始化电平注入不替代物理TF初始化或Flash上板。

S2最终构建：`powershell -NoProfile -ExecutionPolicy Bypass -File diagnostics/run_td_build.ps1 -BuildName flash_boot_s2_local4 -HighFanoutOptimization -TimingOptimization ultra -PostPlaceOptimization high`。物理参数详见固定候选；保留原64个SDRAM接口与本轮旧内存内部3个负端点，不宣称收敛。
