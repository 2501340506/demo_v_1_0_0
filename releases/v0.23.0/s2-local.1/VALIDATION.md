# 本地验证（2026-10-19）

冻结构建 `fast_start_td23`，Setup +0.046ns / Hold +0.085ns，STNS/HTNS=0；18176 LUT、12052 寄存器、53 BRAM9k、2 BRAM32k、13 DSP。原 SPI 频率和时序约束未放宽。134 个生产快照文件逐字节一致，20 个生产增量文件备份在 sources/，bit/报告/资源复制后逐字节核对。完整提交和证据范围见 MANIFEST.json。

## 实际执行的仿真

下列 88 份有效日志均 PASS、Errors: 0、无 Fatal/Error。不是板测次数。全部保存在 validation/。

| 范围 | 日志数 | 内容 |
|---|---:|---|
| 控制器 fast_controller49/50 | 19 | 四类16图、PIC1先进入、新/旧/坏THUMB回退、四阶段预检拒绝、确认/取消/失败恢复、可选资源清除、根目录/宣传子目录/旧图回退；case16先提交首帧再FONT/TEXT；case18两次坏PIC2保留PIC1，其他预取继续，手动重试完整提交 |
| 目录 fast_directories08 | 19 | FAT32分区/卷/长目录及资源扫描 |
| 缓存/参数/预览/字幕/转场等 fast_unit05 | 22 | 原情景、CDC、按键、fade、AUTO、参数、PCM、预览、gap2/5背压 |
| 音频 fast_m4_04 | 7 | 播放器、metadata、AUTO、stream及共享通路 |
| 应用/缓存/图层等价 | 3 | fast_app_equivalence05、fast_cache_equivalence10、fast_layer_equivalence04；应用20万周期×四个MENU/FAST_BOOT配置；缓存20万周期×四个PAUSE/STRICT_FIRST配置，含每拍空槽分配/占用及摘要不变量 |
| 播放器逐周期等价 | 1 | fast_player_equivalence03；20万周期×16个周期/UI/PAUSE配置，另含定向AUTO到期，全部状态/输出不变 |
| 文件续读等价 | 1 | fast_stream_equivalence03；20/32位文件大小×门控开关四配置，916文件（含512个随机32位范围边界）、末字节与sector_done同拍/分拍、跨扇区/FAT、失败及中途复位逐周期等价 |
| 情景计数等价/阈值 | 2 | fast_scenario_equivalence02；30万周期×16配置，全部输出与内部状态等价；1/2/4倍速阈值、AUTO终帧和警告保持定向测试 |
| 菜单后端/按键 | 4 | fast_backend05、fast_ui01、fast_key_equivalence02 两项；6组频率/预览配置的全部输出/计数器逐周期等价、生产宽度进位/到期与原M3长短按阈值专项；缓存复用、拒绝重选、取消、上电SW3高/按住确认释放 |
| 内存/最终像素 | 3 | fast_display10生产SDRAM完整帧、fast_writer01四旧/四原生菜单槽及刷新/取消、fast_pixels01最终菜单RGB/时序 |
| 宣传宋体字幕 | 1 | fast_narration01；1,773,418次比较、599字/276字形、黑色透明/波形间距及隐藏 |
| 缩放逐像素/头地址前瞻 | 4 | fast_scaler04、fast_header09；10种尺寸缩放、5种BMP字节流、取消及16种通用解码场景，头地址前瞻与基线默认路径逐周期比较 |
| 视频延迟逐周期等价 | 1 | fast_video_equivalence02；30万周期、301次异步复位，全部输出与原21拍移位链比较 |
| 预览目标仲裁 | 1 | fast_preview05；请求阻止/取消保持原语义，4,096种仲裁组合验证有效请求目标不变 |

控制器使用真实 scanner/reader/BMP/scaler/controller，扇区传输和外部写完成握手由模型提供；原生256×192每像素颜色/顺序及7/11背压验证。真实SDRAM专项验证存储与最终显示，不能据此声称实体卡/显示器链路通过。编译/厂商模型日志一并收录；控制器加载时39个未连接的不用输出端口提示保留，未把仿真称为零警告。

上述为本轮所选有效证据。时序修复后的应用、菜单后端、图层、生产显示及全部19控制器用例已重跑；其他直接相关回归在本轮功能实现后执行、其后未改对应功能逻辑。更早失败/被替代诊断不计通过，不进入发布目录。

资源工具 test_scene_pack.py 的8项测试通过，并实际执行 mountain_port CLI。四张THUMB重复生成全字节一致，固定256×192/24bpp/BI_RGB，每张147510字节；ZIP全部成员解压读回，50个源卡原文件共52407931字节再次读回一致。full包54个文件，增量包仅4个文件，本轮源卡只读。

## TD、告警与物理初始化

综合/布局布线/bitgen完成；最终报告为准：Setup +0.046ns / Hold +0.085ns，STNS/HTNS=0。资源未超限。采用已提交工程定义，用户 TD_project/demo.al 未覆盖。实际配置见 reproduce/ 和 reports/。

相对 song_td02：syn_1 73→73，新增类型 0，新增重复 0；phy_1 7→7，新增类型 0，新增重复 0。现有数组初始化提示、SDRAM放置回退/本地时钟、异步按键/DDC/数码管/UART IO延迟边界、SD输入延迟提示保留。check_timing 无缺失时钟、无效/无路径/被忽略约束及组合环；SW3端口与首级输入寄存器各1，UART默认关闭。SDC逐字节与基线一致；详细计数与重复项见 reports/audit/warning_review.json。

最终物理17个字体BRAM的INIT/INITP逐位解码，276字形×21行共5796行全部21位与v0.22字模相同。依据TD实测路径注册应用scene_enable、菜单退出摘要和宣传目录有效性，缓存标记改为逐项独立更新；预览目标使用已寄存的offer选择，重扫仍门控request_valid，有效请求目标不变；old_rgb[10]、缩放器输入位16及读FIFO本地复位增加恒等LUT，不增加图像流水周期；对应等价/存储专项通过。缩放器宽高比乘积与比较分级寄存，FAT低16位比较拆为8位摘要，宣传图头用sector响应预解码strobe，灾害图层write_slot[4]使用恒等LUT修复Hold；不改变像素流水和输出，缩放初始化增加1周期，逐像素及目录/控制器/显示回归通过。缓存就绪按四目标并行解码，场景使用自身目标判断，避开播放器wrap/预览目标路径；20万周期×2配置缓存等价及19控制器用例的新旧场景握手断言通过。播放器请求接受时的AUTO计数器重复清零已去除，避免缓存/预览仲裁反馈到32位计数器；20万周期×四个UI/PAUSE配置逐周期等价及定向AUTO到期通过。针对TD10实测短路径，缩放行RAM写地址位3和读FIFO写地址位7增加恒等LUT，无额外时钟延迟。TD11后将BIN加载器epoch复位寄存到本地，扫描接受到BIN加载之间已有目录/图头状态；应用边界输出按当前状态与实际转移条件计算，四配置逐周期等价及全部控制器用例通过。TD12后播放器索引改为逐位等价布尔式，FAT签名在接收时分字节比较并寄存，菜单old_rgb[13]增加恒等LUT；播放器/图层等价、19目录、19控制器及计时均重跑通过。TD13后将AUTO到期比较按计数器下一值前瞻并寄存，保持全部输出逐周期等价；写FIFO地址位2增加恒等LUT，生产SDRAM完整帧回归通过。TD14后菜单入口缓存判断单独寄存/检查、场景存在位提前选择；应用busy按本地转移条件计算，四配置等价通过；音频低字节bit2增加恒等LUT，7项音频与19控制器回归通过。旧卡菜单模型新增2个控制周期，新卡菜单和启动模型不变。TD15后独立解码情景采样计数更新使能，30万周期×16配置及倍速阈值定向测试通过；图头灾害/阶段比较在HEADER_CHECK之前寄存，19控制器和计时重跑通过。TD16后FAT目录续读判断在DIR_WAIT提前寄存；多次布局暴露同类直接寄存器/RAM短路径，因此统一给旧情景RGB、缩放行地址和读写FIFO写地址总线加恒等LUT，保持所有流水周期不变；图层等价、缩放逐像素、生产SDRAM、目录和控制器通过。TD17 Setup +0.019ns、STNS=0，仅BIN复位释放Removal -0.052ns；其后在本地epoch复位输出增加恒等LUT，控制器/计时复测通过。TD18 Hold已通过（+0.021ns），Setup -0.154ns；按实测路径拆出宣传长按计数器更新，六组频率/预览配置逐周期等价及原M3按键阈值专项通过；菜单确认先锁存focus，再独立一拍选择场景信息，确认后的目录检查增加1个控制周期，菜单/首图模型计时不变，19控制器及计时重跑通过。TD19 Setup -0.415ns、STNS=-1.475ns，Hold +0.014ns；按实测路径将缓存空槽可用位与优先编码分离，音频文件结束条件在剩余字节更新时提前寄存，不增加控制周期。缓存20万周期×2配置、文件续读四配置逐周期等价、7音频用例及19控制器回归通过。TD20 Setup -0.814ns/STNS=-8.960ns，Hold +0.071ns；缓存忙/请求窗口摘要和每槽占用在原状态更新边沿同步寄存，目录根选择在scan_start锁存，切断实际报告中的反馈路径，不增加接口周期。缓存以c742df6生产快照为参考，20万周期×四个PAUSE/STRICT_FIRST配置逐拍等价，摘要不变量及占用/分配一致；19目录、19控制器和计时重跑通过。TD21 Setup -1.474ns/STNS=-7.033ns、Hold -0.020ns；按实测共享读卡仲裁到扫描接受的路径，寄存音频排空确认，并保留当前audio_run的即时阻止。菜单只在quiesce后采样读卡器空闲，当前读图/重扫请求继续即时阻止接管。场景类型直接使用所选目录有效性，避开32位目录mux后的零比较；视频延迟输入12位总线增加不改变周期的恒等LUT。19控制器的接管断言、30万周期视频延迟等价与计时重跑通过。TD22 Setup -1.041ns/STNS=-5.140ns、Hold +0.057ns；reader/streamer范围比较按四字节分级，在原校验周期合并，缓存候选并行计算并统一分配写路径。缓存四配置、stream四配置916文件（含512个随机32位范围边界）、19控制器、7音频和计时回归通过，接口周期不变。

历史 fast_start_td01：Setup −3.376ns/STNS −109.161ns、Hold −0.020ns/HTNS −0.032ns，失败bit未交付。controller08/09的物理超时注入不符合可重试文件错误模型，之后case18改为两次实际BMP文件内容损坏；10已通过。unit01/02等历史适配器失败保留本地，不计本轮有效通过。

其他布局诊断（含此前源码版本）：fast_start_td02：旧源码布线仍拥塞且无最终报告，已停止，未用于本候选。 fast_start_td03：SWNS=-1.564ns, HWNS=-0.020ns, STNS=-22.303ns, HTNS=-0.020ns，未用于本候选。 fast_start_td04：SWNS=-5.213ns, HWNS=-0.011ns, STNS=-365.530ns, HTNS=-0.026ns，未用于本候选。 fast_start_td05：SWNS=-0.028ns, HWNS=0.030ns, STNS=-0.040ns, HTNS=0.000ns，未用于本候选。 fast_start_td06：SWNS=-1.504ns, HWNS=0.021ns, STNS=-11.013ns, HTNS=0.000ns，未用于本候选。 fast_start_td07：旧源码布线仍拥塞且无最终报告，已停止，未用于本候选。 fast_start_td08：SWNS=-1.224ns, HWNS=-0.004ns, STNS=-22.177ns, HTNS=-0.004ns，未用于本候选。 fast_start_td09：SWNS=-0.302ns, HWNS=0.024ns, STNS=-0.302ns, HTNS=0.000ns，未用于本候选。 fast_start_td10：SWNS=-1.563ns, HWNS=-0.020ns, STNS=-33.797ns, HTNS=-0.032ns，未用于本候选。 fast_start_td11：SWNS=-1.188ns, HWNS=0.004ns, STNS=-44.567ns, HTNS=0.000ns，未用于本候选。 fast_start_td12：SWNS=-0.860ns, HWNS=-0.020ns, STNS=-13.620ns, HTNS=-0.020ns，未用于本候选。 fast_start_td13：SWNS=-1.505ns, HWNS=-0.004ns, STNS=-8.717ns, HTNS=-0.004ns，未用于本候选。 fast_start_td14：SWNS=-0.515ns, HWNS=-0.004ns, STNS=-1.238ns, HTNS=-0.004ns，未用于本候选。 fast_start_td15：SWNS=-1.081ns, HWNS=0.011ns, STNS=-4.248ns, HTNS=0.000ns，未用于本候选。 fast_start_td16：SWNS=-0.355ns, HWNS=-0.020ns, STNS=-0.732ns, HTNS=-0.043ns，未用于本候选。 fast_start_td17：SWNS=0.019ns, HWNS=-0.052ns, STNS=0.000ns, HTNS=-0.052ns，未用于本候选。 fast_start_td18：SWNS=-0.154ns, HWNS=0.021ns, STNS=-0.357ns, HTNS=0.000ns，未用于本候选。 fast_start_td19：SWNS=-0.415ns, HWNS=0.014ns, STNS=-1.475ns, HTNS=0.000ns，未用于本候选。 fast_start_td20：SWNS=-0.814ns, HWNS=0.071ns, STNS=-8.960ns, HTNS=0.000ns，未用于本候选。 fast_start_td21：SWNS=-1.474ns, HWNS=-0.020ns, STNS=-7.033ns, HTNS=-0.020ns，未用于本候选。 fast_start_td22：SWNS=-1.041ns, HWNS=0.057ns, STNS=-5.140ns, HTNS=0.000ns，未用于本候选。

## S0 与实板边界

validation/fast_metrics_baseline03 和 fast_metrics_current21 为可重复模型周期基线，case0/11/16。PIC为2×3测试图缩放640×480，THUMB为实际256×192，模型不模拟SPI初始化/Flash/显示器，不能换算卡上秒数。该证据已对最终生产源码重新测量。

实体上电/复位/菜单/确认耗时、屏幕显示、长时运行、声音/字幕听审尚未执行。目标1s/1.5s/2s不是验收结果；实板每项10次，记录中位数/最大值，并核查SW3快速拨动/加载中取消/上电高、四场景/后台未缓存阶段、坏资源与所有原功能。无board标签、无正式发布、不合main。
