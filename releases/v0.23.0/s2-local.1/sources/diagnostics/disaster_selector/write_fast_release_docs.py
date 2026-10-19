"""Write pre-tag fast-start delivery documentation from the audited manifest."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT/'releases/v0.23.0/s2-local.1'


def main():
    m = json.loads((TARGET/'MANIFEST.json').read_text(encoding='utf-8'))
    settings = (TARGET/'reports/settings.cfg').read_text(encoding='utf-8')
    seed = int(re.search(r'place seed (\d+)', settings)[1])
    extra_builds = []
    for folder in sorted((ROOT/'diagnostics/output').glob('fast_start_td[0-9][0-9]')):
        name = folder.name
        if name == 'fast_start_td01':
            continue
        if name == m['build']:
            continue
        report = ROOT/f'diagnostics/output/{name}/TD_project/demo_Runs/phy_1/final_timing.rpt'
        if report.exists():
            raw = report.read_bytes()
            s = raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig')
            values = ', '.join(f'{k}={re.search(k+":\\s*([-\\d.]+)ns", s)[1]}ns'
                               for k in ('SWNS', 'HWNS', 'STNS', 'HTNS'))
            extra_builds.append(f'{name}：{values}，未用于本候选。')
        elif (folder/'SUPERSEDED.txt').exists():
            extra_builds.append(f'{name}：旧源码布线仍拥塞且无最终报告，已停止，未用于本候选。')
        else:
            extra_builds.append(f'{name}：冻结时无最终验收报告，未用于本候选。')
    extra_status = ' '.join(extra_builds)
    t, r = m['timing_ns'], m['resources']
    timing = f"Setup +{t['SWNS']:.3f}ns / Hold +{t['HWNS']:.3f}ns，STNS/HTNS=0"
    resource = f"{r['lut']} LUT、{r['reg']} 寄存器、{r['bram']} BRAM9k、{r['bram32k']} BRAM32k、{r['dsp']} DSP"
    (TARGET/'README.md').write_text(f'''# 四宫格与开机加速本地候选

候选：`v0.23.0-s2-local.1`；基线 `31de2b0 / v0.22.0-s1-local.1`；首个功能实现提交 `b791d86`，含后续时序修正的冻结源码提交 `{m['source_commit']}`。功能分支 `feature/thumbnail-fast-start`。本地仿真和完整 TD 通过，实板显示与耗时待测。

## 使用

1. 烧录本目录固定的 [demo.bit](demo.bit)，不要使用会被覆盖的 TD 运行目录文件。
2. 现有配套卡只需将 [thumbnail_additions.zip](assets/thumbnail_additions.zip) 解压到 FAT32 卡根目录，增加四个场景的 THUMB.BMP。完整备卡使用 [full_sd_resources.zip](assets/full_sd_resources.zip)，包含原 50 文件和新增四图。两个 ZIP 任选一种；本轮没有写源卡。
3. 重插卡或 KEY3 复位。SW3=0 检查真实宣传首帧和随后音频/字幕；SW3=1 进入四宫格，KEY1/KEY2 选择、KEY4 确认，拨回 0 取消。确认后完整 PIC1 提交才进入，其余后台缓存。

菜单四图共 590,040 字节。无 THUMB 或其损坏时回退 PIC1，仍不读取 PIC2–4 完整像素。确认会检查四阶段目录与图头；缺阶段/错类型拒绝进入并标为不可用。后台文件失败保持当前完整帧，可手动重试；物理 SD 超时需返回菜单重扫或复位。取消发生在缓存替换后，会重新载入原应用首帧。

开机优先 EDU 图头和完整 EDU1，延后情景图头、FONT/TEXT 内容、后续图及音频，首次直接出图；根目录优先和宣传子目录回退保留，SPI 仍约 16.67 MHz。首帧显示后，字库/字幕就绪才打开覆盖层并从头启动讲解。

## 验证与计时

88 份有效 ModelSim 仿真日志及资源工具 8 项测试通过。完整 `{m['build']}`：{timing}；{resource}。134 个隔离源文件与工作区逐字节一致，最终物理字模全部 5796 行×21 位核对通过；实际 SDC 与前候选相同。见 [VALIDATION](VALIDATION.md) 和 [MANIFEST](MANIFEST.json)。

菜单 ≤1s、确认 ≤1.5s、开机争取 ≤2s 是实板目标，尚无测量结论。按 [计时与资源说明](board/四宫格与开机加速计时及资源说明.md) 同板同卡同显示器各测 10 次；[空白模板](board/四宫格与开机加速实板计时模板.csv) 未填入任何估测数据。上电总时长包含 Flash 配置和显示器锁定，须与复位后内部耗时分开。UART 默认关闭，分段日志需独立调试构建。

## 复现与回退

从基线恢复未改文件，将 `sources/` 覆盖回原路径；这里只备份相对基线修改的 20 个生产文件和本轮工具/测试。采用 `reproduce/demo.al`，保留用户自己的 GUI 工程；在仓库运行 `diagnostics/bottom_waveform/run_td.ps1 -BuildName <新名称> -Seed {seed}`，选项以 reports/settings.cfg 为准。构建后运行 audit_s2.ps1、check_font_map.py 和 review_fast_build.py。不能只凭 bitgen 判定验收。

回退烧录 [v0.22.0 固定 bit](../../v0.22.0/s1-local.1/demo.bit)；新增 THUMB 对旧固件无影响，原 PIC/EDU/PCM/FONT/TEXT 内容未改变。当前无 board 标签、未正式发布或合并 main。
''', encoding='utf-8')
    review = json.loads((TARGET/'reports/audit/warning_review.json').read_text(encoding='utf-8'))
    counts = '；'.join(f"{stage} {v['baseline_warning_count']}→{v['current_warning_count']}，新增类型 {len(v['new_signatures'])}，新增重复 {len(v['additional_repetitions'])}"
                      for stage, v in review['comparisons'].items())
    (TARGET/'VALIDATION.md').write_text(f'''# 本地验证（2026-10-19）

冻结构建 `{m['build']}`，{timing}；{resource}。原 SPI 频率和时序约束未放宽。134 个生产快照文件逐字节一致，20 个生产增量文件备份在 sources/，bit/报告/资源复制后逐字节核对。完整提交和证据范围见 MANIFEST.json。

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

综合/布局布线/bitgen完成；最终报告为准：{timing}。资源未超限。采用已提交工程定义，用户 TD_project/demo.al 未覆盖。实际配置见 reproduce/ 和 reports/。

相对 song_td02：{counts}。现有数组初始化提示、SDRAM放置回退/本地时钟、异步按键/DDC/数码管/UART IO延迟边界、SD输入延迟提示保留。check_timing 无缺失时钟、无效/无路径/被忽略约束及组合环；SW3端口与首级输入寄存器各1，UART默认关闭。SDC逐字节与基线一致；详细计数与重复项见 reports/audit/warning_review.json。

最终物理17个字体BRAM的INIT/INITP逐位解码，276字形×21行共5796行全部21位与v0.22字模相同。依据TD实测路径注册应用scene_enable、菜单退出摘要和宣传目录有效性，缓存标记改为逐项独立更新；预览目标使用已寄存的offer选择，重扫仍门控request_valid，有效请求目标不变；old_rgb[10]、缩放器输入位16及读FIFO本地复位增加恒等LUT，不增加图像流水周期；对应等价/存储专项通过。缩放器宽高比乘积与比较分级寄存，FAT低16位比较拆为8位摘要，宣传图头用sector响应预解码strobe，灾害图层write_slot[4]使用恒等LUT修复Hold；不改变像素流水和输出，缩放初始化增加1周期，逐像素及目录/控制器/显示回归通过。缓存就绪按四目标并行解码，场景使用自身目标判断，避开播放器wrap/预览目标路径；20万周期×2配置缓存等价及19控制器用例的新旧场景握手断言通过。播放器请求接受时的AUTO计数器重复清零已去除，避免缓存/预览仲裁反馈到32位计数器；20万周期×四个UI/PAUSE配置逐周期等价及定向AUTO到期通过。针对TD10实测短路径，缩放行RAM写地址位3和读FIFO写地址位7增加恒等LUT，无额外时钟延迟。TD11后将BIN加载器epoch复位寄存到本地，扫描接受到BIN加载之间已有目录/图头状态；应用边界输出按当前状态与实际转移条件计算，四配置逐周期等价及全部控制器用例通过。TD12后播放器索引改为逐位等价布尔式，FAT签名在接收时分字节比较并寄存，菜单old_rgb[13]增加恒等LUT；播放器/图层等价、19目录、19控制器及计时均重跑通过。TD13后将AUTO到期比较按计数器下一值前瞻并寄存，保持全部输出逐周期等价；写FIFO地址位2增加恒等LUT，生产SDRAM完整帧回归通过。TD14后菜单入口缓存判断单独寄存/检查、场景存在位提前选择；应用busy按本地转移条件计算，四配置等价通过；音频低字节bit2增加恒等LUT，7项音频与19控制器回归通过。旧卡菜单模型新增2个控制周期，新卡菜单和启动模型不变。TD15后独立解码情景采样计数更新使能，30万周期×16配置及倍速阈值定向测试通过；图头灾害/阶段比较在HEADER_CHECK之前寄存，19控制器和计时重跑通过。TD16后FAT目录续读判断在DIR_WAIT提前寄存；多次布局暴露同类直接寄存器/RAM短路径，因此统一给旧情景RGB、缩放行地址和读写FIFO写地址总线加恒等LUT，保持所有流水周期不变；图层等价、缩放逐像素、生产SDRAM、目录和控制器通过。TD17 Setup +0.019ns、STNS=0，仅BIN复位释放Removal -0.052ns；其后在本地epoch复位输出增加恒等LUT，控制器/计时复测通过。TD18 Hold已通过（+0.021ns），Setup -0.154ns；按实测路径拆出宣传长按计数器更新，六组频率/预览配置逐周期等价及原M3按键阈值专项通过；菜单确认先锁存focus，再独立一拍选择场景信息，确认后的目录检查增加1个控制周期，菜单/首图模型计时不变，19控制器及计时重跑通过。TD19 Setup -0.415ns、STNS=-1.475ns，Hold +0.014ns；按实测路径将缓存空槽可用位与优先编码分离，音频文件结束条件在剩余字节更新时提前寄存，不增加控制周期。缓存20万周期×2配置、文件续读四配置逐周期等价、7音频用例及19控制器回归通过。TD20 Setup -0.814ns/STNS=-8.960ns，Hold +0.071ns；缓存忙/请求窗口摘要和每槽占用在原状态更新边沿同步寄存，目录根选择在scan_start锁存，切断实际报告中的反馈路径，不增加接口周期。缓存以c742df6生产快照为参考，20万周期×四个PAUSE/STRICT_FIRST配置逐拍等价，摘要不变量及占用/分配一致；19目录、19控制器和计时重跑通过。TD21 Setup -1.474ns/STNS=-7.033ns、Hold -0.020ns；按实测共享读卡仲裁到扫描接受的路径，寄存音频排空确认，并保留当前audio_run的即时阻止。菜单只在quiesce后采样读卡器空闲，当前读图/重扫请求继续即时阻止接管。场景类型直接使用所选目录有效性，避开32位目录mux后的零比较；视频延迟输入12位总线增加不改变周期的恒等LUT。19控制器的接管断言、30万周期视频延迟等价与计时重跑通过。TD22 Setup -1.041ns/STNS=-5.140ns、Hold +0.057ns；reader/streamer范围比较按四字节分级，在原校验周期合并，缓存候选并行计算并统一分配写路径。缓存四配置、stream四配置916文件（含512个随机32位范围边界）、19控制器、7音频和计时回归通过，接口周期不变。

历史 fast_start_td01：Setup −3.376ns/STNS −109.161ns、Hold −0.020ns/HTNS −0.032ns，失败bit未交付。controller08/09的物理超时注入不符合可重试文件错误模型，之后case18改为两次实际BMP文件内容损坏；10已通过。unit01/02等历史适配器失败保留本地，不计本轮有效通过。

其他布局诊断（含此前源码版本）：{extra_status}

## S0 与实板边界

validation/fast_metrics_baseline03 和 fast_metrics_current21 为可重复模型周期基线，case0/11/16。PIC为2×3测试图缩放640×480，THUMB为实际256×192，模型不模拟SPI初始化/Flash/显示器，不能换算卡上秒数。该证据已对最终生产源码重新测量。

实体上电/复位/菜单/确认耗时、屏幕显示、长时运行、声音/字幕听审尚未执行。目标1s/1.5s/2s不是验收结果；实板每项10次，记录中位数/最大值，并核查SW3快速拨动/加载中取消/上电高、四场景/后台未缓存阶段、坏资源与所有原功能。无board标签、无正式发布、不合main。
''', encoding='utf-8')
    m['files'] = [dict(file=p.relative_to(TARGET).as_posix(), bytes=p.stat().st_size)
                  for p in sorted(TARGET.rglob('*')) if p.is_file() and p.name != 'MANIFEST.json']
    (TARGET/'MANIFEST.json').write_text(json.dumps(m, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print('PASS release documentation:', timing, resource)


if __name__ == '__main__':
    main()
