# 当前验证结论：v0.19.0-s2-local.1

本地通过、板测待验收。唯一候选来源为 `disaster_s2_td_attempt35`：17525 LUT、11760 寄存器、57 BRAM9k、2 BRAM32k、14 DSP；Setup +0.047ns / Hold +0.030ns，STNS/HTNS 均 0。选定 120 份仿真及 86 份编译/模型日志已核验，精确清单和冻结日志在 releases/v0.19.0/s2-local.1/validation。

选定运行目录：disaster_menu_backend05, disaster_s2_app_equivalence01, disaster_s2_audio_control_equivalence01, disaster_s2_cache_equivalence01, disaster_s2_controller25, disaster_s2_decoder_equivalence09, disaster_s2_directories09, disaster_s2_display08, disaster_s2_header_equivalence03, disaster_s2_layer_equivalence04, disaster_s2_layers02, disaster_s2_lfn04, disaster_s2_m3_04, disaster_s2_m4_14, disaster_s2_m5_02, disaster_s2_mode02, disaster_s2_mode03, disaster_s2_mode04, disaster_s2_modes_remaining, disaster_s2_pixels05, disaster_s2_preview02, disaster_s2_rgba01, disaster_s2_ring04, disaster_s2_scaler11, disaster_s2_spi01, disaster_s2_status01, disaster_s2_system01, disaster_s2_ui04, disaster_s2_unit19, disaster_s2_voice_equivalence01, disaster_s2_voice_top07, disaster_s2_writer09。

后文按修改顺序保留验证范围和历史构建状态；早期的“运行中”及失败结论属于对应历史快照，不覆盖本段结果。选定清单包含未变化路径的继承证据，不声称全部测试在最终同一次源码快照重跑。完整音视频重跑覆盖音频/BIN响应修改；之后的decoder payload判断由最新逐拍等价、完整尺寸缩放和控制器测试覆盖。

# S2 验证范围与复现

本阶段输入为 `afffa80` / `v0.19.0-s1-local.1`，任务基线为 `7e3ac02`。实际候选的构建名称、资源、时序和日志清单以 releases 中的 `validation/results.json` 为准；本文说明测试范围，不替代候选结果或板测记录。

## 专项

- `run_decoder_equivalence.ps1`：目录文件长度边界分拍与修改前解码器逐拍比较，4000 组头部 × 4 种固定/范围尺寸及流控配置；含独立目录长度的等于/少一/多一/高半部/零/最大/随机值，验证 header_accepted、错误、ready 及像素时序。`run_scaler.ps1`：10 种尺寸共 3072000 精确像素、取消重用；5 种 24bpp 带填充字节流共 1536000 精确像素，包含横竖 1920 维度、奇数宽高、源/目标背压。

- `run_header_equivalence.ps1`：边界检查改为半字比较寄存，4000 组 BMP 头 × 3 配置与 S1 实现逐拍比较 header_complete 后的 header_match/skip_format；包含有效、截断、随机长度、像素偏移/DIB 溢出、非法格式、连续字节和字节间停顿。
- `run_layer_equivalence.ps1`：图层八拍旧 RGB / 十拍显示身份延迟改用 BRAM 环形缓存，与原移位链逐拍比较 100306 次，包含 303 次异步复位、未填满时再次复位、连续跨环读写、四类/旧类型/普通图/缩略图；填充屏蔽保持复位后精确零输出，不依赖 BRAM 初值。最终 top 像素及缓存读取另用 pixels05/display06 重测。
- `run_voice_equivalence.ps1`：宣传自动翻页条件同拍摘要寄存，与 TD16 原实现逐周期比较 200000周期 × 4个 MENU/最短停留配置；所有外部输出与内部状态、身份、停留、尾帧、advanced 完全相同，含实际自动请求、接收与异步复位。
- `run_application_equivalence.ps1`：应用边界输出由 next_state 同拍寄存，与 TD09 原时序实现比较 200000 周期 × 2 个 MENU 配置；覆盖全部 10 状态、复位、busy/stop_audio 及所有输出，不改变周期行为。
- `run_spi.ps1`：SD 初始化、协议、真实 MOSI/MISO 引脚以及初始化重试；MISO 全流程组合恒等延迟不改变采样边沿。
- `run_layers.ps1`：对新增常数乘法逐位展开穷举全部 65536 对输入，并重跑旧编码/旁路、四类全阶段逐像素参考向量和实际卡图向量；确认散列输出与 10 拍图层延迟不变。独立综合仅用于选择实现，资源以最终完整 TD 为准。
- `run_lfn.ps1`：5070 个目录项、180 次精确命中、30 种乱序；实际 UTF-16 中文、任意短别名、校验和、序号、删除项、普通文件、前后缀及目录边界停顿。
- `run_directories.ps1`：真实 FAT32 扇区服务与目录链；19 项：中文父目录、跨簇、目录乱序、根目录优先、不完整宣传目录与旧卡兼容；新增 FAT 零/小于 2/自循环/高低半部越界/最大合法簇/EOC 边界。
- `run_menu_ui.ps1`、`run_backend.ps1`：上电 SW3=1、上升沿、等待安全点、前后循环、无效项拒绝、确认/取消、保持高电平不重复、按键释放交接。
- `run_s2.ps1 -Suite controller` 的 11 个测试镜像：四类全部 16 张图与阶段循环；根目录完整集优先；缺图、类型不符、解码错误、头损坏、阶段不符、传输失败；取消恢复应用/页/AUTO/速度/参数；忙中取消；长按防串扰；可选 PCM/FONT/TEXT 实际加载、样本与旧有效标记清除。这里使用小型合成 BMP 和短 PCM，以覆盖控制事务。
- `run_writer.ps1`：真实 SDRAM BL4 模型，四独立菜单槽共 196608 像素，原预览共 384000 像素；背压、取消、刷新与地址隔离。
- `run_s2.ps1 -Suite display`：真实 SDRAM 读取，2457600 显示像素，其中 786432 菜单图像像素；全屏、旧阶段预览、四菜单槽切换及帧内描述符稳定。
- `run_s2.ps1 -Suite pixels`：生产 top 视频路径 1536000 最终像素，四种焦点、部分无效灰块、固定中文标签、原色旁路与 18 拍最终同步/坐标。测试注入 RGB/描述符并保持 SD/内存域复位，实际事务由前述 controller/display/writer 独立覆盖；输出图是合成梯度，不冒充 TF 卡灾害图片。

## 既有功能回归

选定日志清单为 `s2_logs.json`，包括 scenario/CDC/淡入/速度/预警、播放器/AUTO、参数/音量/OSD、双应用扫描与重载、FONT/TEXT、PCM/HDMI 音频、32 位 RGBA、真实 SDRAM 全系统及原阶段预览。使用 `diagnostics/publicity_mode/prepare_m5.py` 生成新测试副本，明确将历史测试中的 SW3 和新增 pause 置零，不覆盖历史测试输出。

最新控制与相关单元回归使用 LOAD_SELECT、寄存 quiesce/owner、player 交接 pause 的实现。TD09 进一步将页面输出、物理表索引及头响应整束寄存，避免状态译码进入宽元数据及字段写使能；菜单 UI、controller、unit 和 M3 重测其行为。测得的 FIFO 与缩放器 BRAM 地址短路径使用 keep 恒等 LUT，无时钟延迟，writer/display/preview/voice_top 验证实际存储与数据路径。较早编译的显示/音频/长系统回归覆盖对应数据通路；其后仲裁与索引分拍由最新 controller、backend、unit、M5 和 mode 回归补充验证。FAT 链范围比较新增一拍，目录专项及最新 controller/unit 验证跨簇和失败行为；音频写口使用标准 Gray 指针满比较，最新 M4/unit 验证 5300 个逐样本数据、指针多次回绕及停播重启。最后的 hash8 资源优化由穷举等价及图层全像素回归验证，未改变接口或流水。TD10 再将应用 busy/stop_audio 直接寄存，以等价比较证明周期不变；音频写域先寄存 Gray 解码后的读指针，扇区准入只会更保守，逐字节满保护不变，由最新 M4/unit 验证。MISO 初始化旁路的 Hold 通过与正常读取共用恒等延迟修复，SPI 四项专门验证。不能将所有日志写成同一次编译的精确源码快照。完整原尺寸音频测试使用 307200 像素实际写入，FastDebug 不作为验收证据。

TD13 根据 TD12 实测关键路径继续分拍：LFN 固定 UTF-16 常量在低字节时预解码并寄存，高字节比较；目录命中/簇号与高低半部范围条件整束寄存；BMP 头长度比较拆成高低半部谓词，字段在 header_complete 前稳定，原完成拍不变；情景音频可用性摘要寄存，active_sync 和样本 CDC 不变；音频 BRAM 读地址第 8/9 位加 keep 恒等 LUT 修复实际短路径，不增加周期延迟。新的 LFN/19 项目录、头判定等价、M4、unit、controller 和原尺寸顶层 VOI 回归单独记录，不能把仍运行的测试记为通过。

TD16 针对 TD15 实测路径修改缩放器：每个目标行增加一拍 ROW_CHECK，寄存行范围及 top 相等条件，输出像素和源/目标背压协议不变；BMP 解码器的目录长度比较拆成高/低半部谓词，头完成时序不变。对实际 PCM 写地址第 2/10 位及旧图层 BRAM 输入第 3/15 位保留组合恒等 LUT，不增加周期。缩放器多种尺寸/流式解码与背压、图层逐拍等价重测通过；M4/unit/controller 与原尺寸顶层音频重新运行，完成后才能选取对应日志。TD15 虽 bitgen 完成，但 Setup -7.313ns / STNS -781.502ns / 881端点、Hold -.020ns / HTNS -.062ns / 4端点，禁止交付。

TD18 根据 TD16 实测路径寄存宣传自动翻页就绪摘要，保留同周期外部 busy/pause/手动门控；decoder 用行边界完成标记替代每字节宽比较，像素协议不变。FIFO写地址6/7、PCM写地址9、图层sideband21、音频环读地址5、提示音FIFO写地址1保留恒等LUT，修复实测短路径且不增加时钟周期。voice/decoder/图层等价、scaler全部尺寸/字节流、M4及音频环单元/像素通过；最新unit14全部22项、controller19全部11例已通过，完整VOI仍运行，未完成不计为通过。TD16时序失败，TD17剩余两处布线冲突失败；TD18剩余3处布线冲突失败，资源17422 LUT、11654寄存器、57 BRAM9k、2 BRAM32k、16 DSP，未形成候选；TD19用此前完成布线的more_lut_pair/high post-place配置对当前RTL复测。

完整原尺寸 voice_top05 随后已通过：6次VOI会话、1536个精确源样本、PCM及HDMI各21948个精确样本；验证四页、AUTO等待实际传输尾样本、情景预警及返回，使用307200像素缩放器。所选清单已由voice_top04更新为05，118份仿真重新核验通过。

TD19 最后两处布线冲突失败，失败路由审计 Setup -7.084ns/STNS -630.159ns、Hold -.011ns/HTNS -.014ns，不交付。TD20 按实测路径寄存 parser cancel（原始 cancel 仍立即关闭写口）、reader 局部 decoder/streamer/scanner reset，既有 START_FILE/停止排空握手留出释放周期；情景音频 found 摘要在8周期 START 保护内稳定。`run_audio_control_equivalence.ps1` 比较80000周期、PUBLICITY 0/1，1250次选择（608缺失/642可用）、停止/启动保护、样本/错误/复位，全部输出逐拍一致。controller20全部11例、M3_04全部17项、M4_08全部7项和unit15全部22项已通过。宣传 AUTO 在完整四页集、无手动请求时目标已等于播放器默认 next，移除其重复 mux 以切断 busy→目标→ready 的长链；完整原尺寸 voice_top06 增加实际 AUTO 请求的目标断言，仍运行，不能计作通过。PCM 写数据第7位恒等 LUT 不增加周期，针对实测 BRAM Hold 路径。TD20 随后因 scanner 复位与 voi_invalid_b/selected_stage 的两处布线冲突失败，不交付；其失败路由诊断为 Setup -5.663ns/STNS -632.263ns、Hold -.012ns/HTNS -.016ns，资源17299 LUT、11643寄存器、57 BRAM9k、2 BRAM32k、16 DSP。失败路由诊断不等于完整可用物理实现。TD21 保持同一RTL和布局设置，仅修正 HighRouteEffort：TD 6.2 手册第282页（PDF第283页）规定 route effort 为 normal/routability；旧 high 值使日志仍显示普通强度。TD21 日志已确认 Routing in high effort: true；新构建正在执行，最终时序尚未通过，尚无本轮可交付S2候选。

所有选定仿真必须出现 PASS、Errors: 0 且没有 Fatal/Error；编译及模型告警逐条通过现有 allowlist，保留已知 vendor/model 告警，不宣称零告警。

## TD 与固定候选

完整构建使用 `diagnostics/mountain_scene/build_m5.ps1` 在独立输出目录运行。需要资源不超限、Setup/Hold 严格大于零、STNS/HTNS 均零、无 ERROR、完成 bitgen；仅退出码为零不够。失败构建保留 diagnostics/output，不进入 releases。

完成构建后运行 `audit_s2.ps1 -BuildName <构建名>`，核对无缺失时钟、无效约束、组合环；审阅实际 warning delta 与既有 IO/model 边界。SW3 仅豁免 C6 端口至首级 PAD FF，导出物理网表并检查 `sw3_syn_4` 对应菜单 switch_filter/sync0[0]；`sw3_sync.timing` 必须证实其至 sync1 的路径仍参与 STA。

运行 `package_s2.py review <构建名>` 后人工记录该构建的 `AUDIT_REVIEW.md`，再用 `package_s2.py package <构建名> --candidate s2-local.N` 冻结。脚本逐字节核对工程输入/根 TD runner 与构建快照、bit/报告/实际变化源码与固定副本，不写哈希、不覆盖旧候选。最终资源及相对基线/S1 的变化写入 results.json。

## 实板边界

G:\ 原卡仅读取。S1 已核对移植包及原卡 16 张 BMP 字节；S2 合成 FAT32 镜像验证目录协议，实际电视显示、卡吞吐、灾害图层、音频听审及持续运行仍需用户上板。操作见 `docs/灾害SW3操作与板测.md`。未获具体候选确认前只记“本地通过、板测待验收”，不建立 board 标签。


### TD21 / TD22 当前状态

TD21完成high effort布线与bitgen，但Setup -2.261ns/STNS -113.883ns（170端点），Hold -.004ns/HTNS -.008ns（2端点），资源17299 LUT、11643寄存器、57 BRAM9k、2 BRAM32k、16 DSP，未通过，不交付。voice_top06已完成PASS，包含新增实际AUTO目标断言，仍是后续响应管线修改前的证据。

TD22按上述报告修改：BPB范围校验拆半字与合并状态；mem域在S_ACK锁存burst目标，菜单长度/基址使用同步mode；源域独立保留49152像素校验；LFN常量ROM去除byte_valid CE、有效范围BMP行长度收窄13位（最大1920×4）；SD响应对音频/BIN整束寄存并将busy延伸到响应消费，保持lastbyte/done同拍和owner。FIFO写地址4、PCM读地址3加组合恒等LUT。directories09全部19例、writer08真实缓存隔离、decoder_equivalence06和lfn04通过，其他相关回归与完整TD22运行中，结果完成后更新。未改实际时钟或放宽时序门槛。

### TD22 结果与 TD23 修正

TD22最终Setup -.552ns/STNS -2.050ns（6端点），Hold +.024ns/HTNS 0；17321 LUT、11665寄存器、57 BRAM9k、2 BRAM32k、16 DSP。全部剩余违例为decoder行字节比较至col CE的7级组合路径，不交付。controller21全部11例、unit16全部22项、M4_09全部7项和scaler08已完成PASS；unit16情景音频核对173939样本/11会话。

TD23只修改范围尺寸decoder的行内payload判断：在接受当前字节时预判下个字节是否属于payload，行末复位为有效，背压时保持；传统固定尺寸仍走原比较。该标记与row_byte同拍推进，不改变外部ready/valid或像素输出周期。decoder_equivalence07全部4000头×4配置通过；scaler09/controller22运行中。voice_top07针对前一轮音频/BIN响应管线，仍运行，完成后才能记通过。

## TD23 与 TD24：实测路径继续收敛

TD23完成布线/bitgen，Setup -.433ns/STNS -1.862ns（13端点），Hold -.011ns/HTNS -.011ns；17332 LUT、11659寄存器、57 BRAM9k、2 BRAM32k、16 DSP。不满足门槛，未交付。TD22的decoder列CE路径已消除，当前最差为音频扇区地址更新，另有若干分散的小负裕量端点。

TD24在PCM短缓存replay_offset[1]到读地址的实测Hold路径增加保持恒等LUT，不增加时钟周期；placement seed改41，其他时钟/门槛不变，构建运行中。M4_10全部7项通过；unit17及原尺寸voice_top07仍运行中。

decoder_equivalence08通过4000组头×4配置逐拍比较，并新增8幅完整24/32bpp图（宽1/3/7/1920、高3），含源间隙、输出背压、行填充与精确像素/提交检查。scaler09及controller22全部通过；后者含可选PCM/FONT/TEXT及资源标志清除。

## TD24 与目录选择分拍

TD24最终Setup -.071ns/STNS -.142ns（2端点），Hold +.014ns/HTNS 0；构建仍不通过。负路径全部为app_target经desired_directory多路选择和32位比较到scan_state，8级LUT。新增SC_SELECT_DIRECTORY：在原扫描接受时锁存目标目录和类型，再下一拍比较/发起映射或目录扫描；仅菜单启用时的非物理重扫增加一拍，不改变事务握手。controller23运行验证确认/取消/根目录优先和资源交接。unit17全部22项通过，替换unit16证据；M4_10全部7项通过。

## 最后受影响路径回归

controller23全部11例PASS，包括新增目录选择拍、确认/取消/忙中请求、根资源优先、可选PCM/FONT/TEXT与标记清除。voice_top07完整PASS：1536精确VOI源样本/6会话，21948缩放PCM与21948 HDMI有效载荷样本；实际AUTO请求/尾样本/四页/情景预警返回，保留307200像素真实scaler。该音视频快照覆盖音频/BIN响应管线，后续decoder和目录分拍分别由decoder_equivalence08/scaler09/controller23覆盖；组合恒等Hold LUT由unit17/M4_10覆盖。清单119仿真和85编译模型日志全部重新核验。

## TD25 与缓存空槽并行解码

TD25完成布线/bitgen，Setup -.710ns/STNS -3.526ns（13端点）、Hold +.030ns/HTNS 0，失败不交付。新增目录分拍的原负路径已消除，当前主要为缓存bank_map经occupied/free priority到分配/控制。将逐项动态位写的占用构造改为每个物理bank的并行OR解码；不改变规则、握手或周期。cache_equivalence01已通过20万周期×两种PAUSE配置的每拍边界/分配比较，覆盖全部phase/load状态和异步复位；参考文件固定为TD25前缓存源码。controller24和TD26运行中。


## TD26 / TD27 与实测 BRAM Hold 修正

controller24 全部11例通过；cache_equivalence01 与选定清单120份仿真、86份编译模型日志已核验。TD26完成布线与bitgen，但Setup -3.094ns/STNS -128.577ns，Hold -.012ns/HTNS -.015ns，17542 LUT、11724寄存器、57 BRAM9k、2 BRAM32k、16 DSP，失败不交付。

相同RTL换placement seed43的TD27最终Setup +.102ns/STNS 0，Hold -.020ns/HTNS -.057ns（5端点），仍不通过。最终报告实际短路径为scaler输入RGB[1]/[28]至行BRAM数据、PCM写指针[3]/[7]至写地址，以及PCM读指针[7]至读地址（物理起点重命名rd_gray_reg[9]，实际网为rd_bin[7]）。在这些实测路径增加keep恒等LUT，不改变数据值或周期；TD28保持seed43重新完整构建，scaler10/unit18/M4_11验证中。不放宽时钟、Setup/Hold或TNS门槛。


TD28/29并行使用相同生产RTL，分别seed43/47。scaler10完整通过（10种尺寸3072000像素、5种实际24bpp流1536000像素）；M4_11全部7项通过。unit18误用旧run_m4入口，因未适配新增pause的旧缓存测试未能加载，不计验收；当前run_m5适配入口的unit19重跑中，失败原始日志留在诊断目录。既有unit17证据在重跑完成前仍保持原清单。


TD28最终Setup +.014ns/STNS0、Hold -.011ns/HTNS -.015ns（2端点），17508 LUT、11708寄存器、57 BRAM9k、2 BRAM32k、16 DSP，失败不交付。此前5条实测路径已消除，新短路径为PCM写指针实际网wr_bin[5]及图层旁带line_y[4]（至side_delay BRAM）；等待同RTL seed47的TD29最终结果，再决定后续修正。unit19情景音频173939精确样本/11会话已完成PASS。


TD29最终Setup -.782ns/STNS -11.174ns、Hold -.020ns/HTNS -.020ns（旁带side_in[31]），失败不交付。TD28和29反复在同一PCM地址/图层旁带总线的不同位出现BRAM短路径，因此TD30改为在这两类总线的每位RAM输入统一保留组合恒等LUT，替代逐位追补；增加少量LUT，不增加寄存器/周期，不改BRAM延迟或跨域同步。现有正裕量的Setup架构保持，继续完整构建并专项验证逐拍图层等价与PCM样本协议。unit19全部22项已通过，选定清单更新为unit19、M4_11、scaler10后120/86全部核验。

## TD30/31 对应直接回归

PCM全部读写地址及图层全部旁带位统一恒等LUT后，layer_equivalence04完成100306逐拍比较/303异步复位；M4_12全部7项完成，PCM播放器5300精确样本、指针回绕、停播/重启。选定清单已替换两组新证据，120份仿真/86份编译模型重新核验通过。unit19全部22项已完成，不再是运行中；其快照早于全部位恒等LUT，音频与图层后续修改由上述直接专项覆盖。TD30(seed43)与TD31(seed53)使用相同RTL快照并行完整构建，尚未有最终时序结论。

TD30最终失败：Setup -.365ns/STNS -.555ns（3端点），Hold -.004ns/HTNS -.004ns（1端点），17509 LUT、11744寄存器、57 BRAM9k、2 BRAM32k、16 DSP。PCM/图层旁带原Hold违例已消除；剩余Hold为audio_ring_levels的copy_pointer[2]直达history BRAM读地址。Setup最差为BMP头width经常数乘法/行跨度到DSP输入；另外两条为按键CE与音频簇范围比较。TD31同RTL seed53仍在布线，未通过不交付。

## TD31失败与TD32/33修正

TD31最终Setup -1.931ns/STNS -35.199ns，Hold +.086ns/HTNS0；主要负路径为backend目录CE与目录启动的布线延迟，不交付。根据TD30实测BMP头常数乘法→行跨度→DSP输入路径，header/decoder中的×3改为18位移位加法；18位完整覆盖65535×3+3，保留逐拍数值、所有旧/无效尺寸行为及原完成拍。audio_ring_levels读地址全部位加入组合恒等LUT，针对TD30实测copy_pointer[2]及此前[5]，不增加周期。

header_equivalence03、decoder_equivalence09、ring04两项全部通过；scaler11/controller25与TD32(seed43)/33(seed47)正在运行。全部测试/构建结束前不记候选。

TD32/33对应回归全部完成：controller25全部11例、scaler11两项通过；已选用header_equivalence03、decoder_equivalence09、ring04、scaler11和controller25，全部120仿真/86编译模型日志重新核验。layer_equivalence04/M4_12覆盖前一轮全部位恒等延迟；本轮无图层/PCM流水改动。完整TD32/33仍在运行，未通过前无S2候选。


### TD32/33 结果

TD32/33最终均失败：32 Setup -1.153ns/STNS -25.527ns、Hold -.012ns/HTNS -.016ns；33 Setup -.388ns/STNS -.406ns、Hold -.012ns/HTNS -.027ns。当前修复33实测的短音频缓存地址、读FIFO地址Hold及写FIFO复位Removal，均使用保留恒等LUT、不增加周期。专项与新完整TD待完成，不交付失败bit。


### TD34/35 修正验证

短文件缓存全部地址位、读FIFO地址及写FIFO同步复位释放的组合恒等LUT修正后，writer09、display08、m4_14全部通过。首次display07/m4_13因声明顺序编译错误失败，修正后重新运行，不计入验收。当前清单120仿真/86编译模型日志重新核验通过。TD34/35同RTL seed43/59完整构建中；仍待最终时序，不交付。

### TD35 最终通过与候选冻结

相同生产 RTL 的 TD34(seed43) 最终 Setup -.909ns/STNS -11.727ns、Hold -.020ns/HTNS -.031ns，失败产物仅留本地。TD35(seed59) 完成完整综合、布局布线与 bitgen，最终 Setup +.047ns、Hold +.030ns，STNS/HTNS 均 0；17525 LUT、11760 寄存器、57 BRAM9k、2 BRAM32k、14 DSP，无 ERROR，全部资源未超限。此后不再修改生产输入。

TD35 的实际 check_timing、exception 和物理网表审阅已完成。STA coverage 99.97%；无无时钟/无效约束/组合环/PLL 频率不匹配。10 个输入和17个输出无 IO delay 的既有边界（新增异步 SW3）如实保留，4类 dummy model 与新增/继承工具告警记录于候选 AUDIT_REVIEW。SW3 首级 PAD FF 到 sync1 的 Setup +7.848ns、Hold +1.056ns，未放宽内部路径。仅 TD35 固定为 S2 local.1，本地通过、板测待验收。
