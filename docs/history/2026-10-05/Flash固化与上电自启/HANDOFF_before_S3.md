# 当前交接记录

2026-10-05。分支feature/flash-boot-v0.5.0。**S1用户已确认通过；S2本地完成，固定候选待用户SRAM上板。确认S2前不得进入S3，所有本任务提交/标签仅本地，S5才统一上传。**

## 已完成

- 用户回复“确认通过，进入 S2”，按S1整体通过记录，不补造次数/设备；本地v0.5.0-s1-board.1已建立，固定S1 bit不变。先前交接保存docs/flash_boot/HANDOFF_before_S2.md。
- S2生产改动仅top的Sdr_init_done两拍同步/连接及sd_card_bmp新增sdram_ready、首次扫描条件；rst_sd清零同步级，TF/SDRAM初始化并行，等待不复位SD。其他RTL、PLL、ADC/SDC和TD清单不变。
- 七个直接实例测试显式接sdram_ready=1（含两个历史可执行入口），历史证据快照不修改。
- 真实top四场景启动专项通过：TF先就绪、内存先就绪、近同时、等待期间复位；两拍同步独立参考、未就绪无业务活动、就绪后只扫描一次。绕过门控的负对照按预期在提前扫描断言失败。五轮PLL/音频复位专项重新通过。
- 七项稳定性专项（全尺寸307200 RGB等）、真实解析器异步交接三配置、八个既有音视频/控制/复位入口本轮全部通过，正向编译/仿真零错误零警告。
- TD最终flash_boot_s2_local4通过，3926 LUT/2902寄存器/4 BRAM/4 DSP/2 PLL。SD+0.170ns、内存→SD+0.725ns、像素→串行+5.900ns。全局Setup−6.565ns/TNS−251.158ns、Hold+0.003ns；原64个SDRAM接口负端点及本轮旧frame_fifo_read内部3个负端点（最差−0.084ns）保留，总67个，未全局收敛。新增同步/启动逻辑无负端点。
- [S2固定候选](../../../../releases/v0.5.0/v0.5.0-s2-local.1/README.md)：629624字节bit与最终运行产物逐字节一致，附源清单、工程/约束/参数、仿真与TD报告和逐组时序对比。未上板、未烧Flash、未推送，未做最终结项归档。

## 阻塞与下一步

等待用户按[S2上板步骤](../../../../releases/v0.5.0/v0.5.0-s2-local.1/BOARD_VALIDATION.md)SRAM下载固定bit，检查首图、四图、MAN/AUTO、音频、5轮复位。仅有整体通过回复就仅记录整体结论。通过后建立本地v0.5.0-s2-board.1，进入S3按实际TD工具核实W25Q64启动设置与固化流程；S3/S4复用已验收S2 bit。

## 踩坑与范围

- S2首次沿用S1物理参数出现3个SD扫描负端点−0.071ns；opt_timing high仍有SD/内存负端点；ultra消除SD违例，post_place_opt high没有进一步改善原frame_fifo_read的3个内部负端点。各轮诊断见diagnostics/flash_boot/evidence/s2_build1至s2_build3。按用户选定的时序审查范围披露旧路径变化，不扩展帧缓存整改或掩盖违例。
- 最终复现：diagnostics/run_td_build.ps1 -BuildName flash_boot_s2_local4 -HighFanoutOptimization -TimingOptimization ultra -PostPlaceOptimization high。GUI需设置Phy/Place hfn_opt_effort=high、opt_timing=ultra、post_place_opt=high；demo.al快照仍保留原默认，不能直接以默认构建代表同参数复现。
- ModelSim初始化完成电平注入、行为PLL/FIFO/存储不替代物理TF/SDRAM/Flash验证。原SD初始化及免复位热插拔限制不变。TD既有警告及板级IO约束边界保留。
- PLL reset只接外部~rst_n，不接未锁定组合复位；首扫描等待SDRAM就绪，不能反过来复位SD初始化。request为toggle，不以电平1判断在途。
- 用户releases/v0.3.0/demo.al原修改未提交；UTF-8读写中文，不批量删除任何文件/目录。最终S5才归档完成计划并统一上传。
