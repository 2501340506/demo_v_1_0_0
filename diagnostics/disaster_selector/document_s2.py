"""Write delivery notes from a frozen, validated S2 candidate; never label board pass."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]


def document(candidate):
    release = ROOT/'releases/v0.19.0'/candidate
    result = json.loads((release/'validation/results.json').read_text(encoding='utf-8'))
    assert result['board'] == 'pending'
    assert result['timing_ns']['SWNS'] > 0 and result['timing_ns']['HWNS'] > 0
    assert result['timing_ns']['STNS'] == result['timing_ns']['HTNS'] == 0
    assert not (release/'README.md').exists(), 'Delivery notes already written'
    tag = 'v0.19.0-'+candidate
    r, t = result['resources'], result['timing_ns']
    resource_text = f"{r['lut']} LUT、{r['reg']} 寄存器、{r['bram9k']} BRAM9k、{r['bram32k']} BRAM32k、{r['dsp']} DSP"
    timing_text = f"Setup {t['SWNS']:+.3f}ns / Hold {t['HWNS']:+.3f}ns，STNS/HTNS 均 0"
    table = '| 资源 | 基线 | S1 | S2 | 相对基线 | 相对 S1 | 上限 |\n|---|---:|---:|---:|---:|---:|---:|\n'
    for key, name, base, first, limit in (
        ('lut','LUT',14092,15780,19600), ('reg','寄存器',9530,10878,19600),
        ('bram9k','BRAM9k',46,52,64), ('bram32k','BRAM32k',2,2,16), ('dsp','DSP',13,26,29)):
        table += f"| {name} | {base} | {first} | {r[key]} | {r[key]-base:+d} | {r[key]-first:+d} | {limit} |\n"

    def write(path, text):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text.rstrip()+'\n', encoding='utf-8')

    write(release/'README.md', f'''# v0.19.0 {candidate} 灾害选择系统

本地通过、板测待验收。标签 `{tag}`，原目录分支 `feature/mountain-disaster-selector`；基线 `7e3ac02`，S1 输入 `afffa80`。固定 [demo.bit](demo.bit)，{result['bit_bytes']} 字节。

SW3=C6，拨上为 1，KEY3 仍复位。菜单四格为滑坡、泥石流、山洪、地震，各显示 256×192 首图和固定中文名称。KEY1 前一个、KEY2 后一个、KEY4 确认；灰色场景禁止确认。实际 VFAT 中文目录、任意短别名与跨簇扫描支持“情景模式”及“宣讲模式”，完整根目录资源保持优先；明确菜单选择采用对应子目录。

忙中等待安全交接，菜单停音频及自动推进。确认从第一阶段、非预警、AUTO 关闭开始，保留公共参数及速度，暂全屏直至 SW1/SW2 下一次实际拨动。未确认拨回 0 恢复原应用/页/AUTO并重启讲解或推演；保持 SW3=1 不重复打开。交接后释放按键再操作。原全屏/阶段预览缓存独立，旧编码、字幕、音频、参数、预警及数码管保留，UART 日志和在线字幕默认关闭。

完整 TD `{result['build']}`：{resource_text}；{timing_text}，无 ERROR、完整 bitgen。{len(result['simulations'])} 份选定仿真、{len(result['compile_logs'])} 份编译/模型日志通过。详见 [验证](VALIDATION.md)、[清单](MANIFEST.md) 和 [实际审计](reports/AUDIT_REVIEW.md)。

{table}

[完整操作与板测](../../../docs/灾害SW3操作与板测.md) · [板测记录](BOARD_RESULT.md) · [S1 回退](../s1-local.1/README.md)。已确认硬件回退为 M5 board.1 原 bit，正式回退 v0.16.0。未建立 board 标签、未正式发布、未合并 main。G:\\ 原卡及个人记录、旧 TD 状态未改写。
''')
    write(release/'VALIDATION.md', f'''# S2 本地验证

本候选 `{tag}`：本地通过、板测待验收。TD `{result['build']}`，{resource_text}；{timing_text}，资源未超限、无 ERROR、完成 bitgen。完整实际报告与配置见 reports。

本轮选定 {len(result['simulations'])} 份仿真和 {len(result['compile_logs'])} 份编译/模型日志全部核验，清单与每份原始证据在 validation；PASS、Errors: 0、无 Fatal/Error，已知 vendor/model 告警按既有 allowlist 审阅。

专项覆盖真实中文 LFN/校验和/乱序/跨簇目录、四类全部 16 图、缺损/错类型/失败、根目录与宣传回退、四首图/中文/焦点/灰块/原色、确认/取消/上电/忙中请求/按键防串扰、参数/AUTO/速度保留、可选 PCM/FONT/TEXT 与旧标记清除，以及独立 SDRAM 菜单写读和旧缓存隔离。

日志清单同时包含受影响模块的最新重跑和未变化路径的继承证据，不能描述为全部测试同次精确快照。最新目录/控制器覆盖 BPB 分拍、LFN 常量 ROM、目录乱序与跨簇、四类16图、可选 PCM/FONT/TEXT 和资源清除；真实 SDRAM writer 覆盖四菜单槽196608像素与旧缓存384000像素。最新 unit/M4/原尺寸 voice_top 覆盖音频/BIN 整束响应流水及排空，原尺寸顶层保留实际307200像素 scaler，核验实际AUTO目标及HDMI尾样本。decoder 的有效范围行长度与payload提前判断，经4000组头×4配置逐拍等价、8幅完整24/32bpp图（宽1/3/7/1920、含背压和行填充）、10种缩放尺寸3072000精确像素及5种实际24bpp字节流1536000精确像素验证；传统固定尺寸行为保留。最后的控制器/缩放重跑覆盖该payload修改，最终控制器重跑还覆盖MENU启用非物理扫描增加一拍的目录选择交接；之前的音频响应管线回归按其源码范围继承。

图层 hash8 常数乘法展开通过全部65536对输入与58982400个实际卡图像素比较；BRAM 延迟环经100306次逐拍等价含303次异步复位验证，生产 top 的pixels05及最终display重测最终18拍同步、坐标与原色。缓存空槽并行解码经20万周期×两种PAUSE配置逐拍等价，覆盖全部phase/load状态、分配及所有边界输出；应用边界及宣传AUTO摘要分别经40万/80万周期等价，情景音频可用性摘要经80000周期等价；SPI四项验证MISO恒等组合延迟。PCM全部地址、图层全部旁带和音频可视化读地址保留组合恒等LUT，不增加周期；最终图层等价、M4音频样本与音频环单元/像素分别重跑。BMP头/decoder的常数×3改为等价18位移位加法，避免DSP串接，头判定/解码逐拍等价、多尺寸完整缩放和控制器回归覆盖其正确性。TD33实测后短文件缓存全部地址位、读FIFO地址与写FIFO同步复位释放增加组合恒等LUT，不增加周期，最终writer/display/M4重跑覆盖缓存、显示及音频协议。详细复现、日志版本和历史失败边界见 [S2_VALIDATION.md](S2_VALIDATION.md)。

{result['input_count']} 个工程输入及根 TD runner 与隔离构建逐字节一致；bit、必要报告及相对 S1 实际变化的 {len(result['modified_sources'])} 个生产文件逐字节复制固定。其余源码从 S1 标签引用，再由任务基线追溯；不复制整棵 user_source，不生成哈希。菜单预览图是测试梯度的生产 top 输出，不是原卡图。

SW3 端口仅至首级 PAD FF 的异步输入例外经实际网表审阅，首级至 sync1 保持 STA，证据为 reports/sw3_sync.timing。既有 IO/model 边界、STA 覆盖率和 warning delta 见 reports/AUDIT_REVIEW.md，不宣称零告警或全 IO 覆盖。

TD attempt01/03/04/06/10/11/14/17/18/19/20 布线失败，attempt02/05/07/08/09/12/15/16/21/22/23/24/25/26/27/28/29/30/31/32/33/34 时序失败，均未交付；attempt13 布线修复工具崩溃。TD21 起修正增强布线参数为手册规定的 routability，日志确认 high effort true。其他尝试按实际报告留在 diagnostics/output，仅此处的构建是本候选来源。两阶段均保留各自 bit 和报告，S1 的 45 份仿真为独立继承证据，不计入上述 S2 数量。

G:\\ 原卡仅读取；软件 FAT32 镜像与短测试音只用于测试。实板四类选择、16 图、宣传、预览、参数、字幕、音频、预警、数码管及持续运行仍待用户验收，不继承前版板测结论。
''')
    scope_path = ROOT/'diagnostics/disaster_selector/S2_VALIDATION.md'
    evidence_runs = sorted({str(Path(name).parent) for name in result['simulations']})
    write(scope_path, f'''# 当前验证结论：{tag}

本地通过、板测待验收。唯一候选来源为 `{result['build']}`：{resource_text}；{timing_text}。选定 {len(result['simulations'])} 份仿真及 {len(result['compile_logs'])} 份编译/模型日志已核验，精确清单和冻结日志在 releases/v0.19.0/{candidate}/validation。

选定运行目录：{', '.join(evidence_runs)}。

后文按修改顺序保留验证范围和历史构建状态；早期的“运行中”及失败结论属于对应历史快照，不覆盖本段结果。选定清单包含未变化路径的继承证据，不声称全部测试在最终同一次源码快照重跑。完整音视频重跑覆盖音频/BIN响应修改；之后的decoder payload判断由最新逐拍等价、完整尺寸缩放和控制器测试覆盖。

'''+scope_path.read_text(encoding='utf-8'))
    shutil.copyfile(scope_path, release/'S2_VALIDATION.md')
    write(release/'BOARD_RESULT.md', f'''# {tag} 板测记录

状态：待用户验收。没有本候选的上板反馈，不预填通过、次数或时长，不建立 board 标签。

固定 bit：demo.bit，{result['bit_bytes']} 字节。使用 [操作与八项检查](../../../docs/灾害SW3操作与板测.md)，反馈候选标签、卡内容、显示器、实际操作与现象。

待验收：四类首图/中文选择及 16 图；宣传播放；原阶段预览；参数/速度/AUTO；讲解与灾害音频；预警/字幕；数码管；忙中切换、确认取消、冷启动及按键释放。

用户反馈：尚未收到。
''')
    overview = f'''# 当前开发阶段：灾害 S2 本地通过、板测待验收

原目录分支 `feature/mountain-disaster-selector`，基线 `7e3ac02`。S1 选择性移植后，S2 已接入 SW3=C6 四类中文菜单、真实长目录扫描和独立缓存；保留双应用、音频、字幕、参数、预警、阶段预览及数码管。UART 两项默认关闭。KEY1/KEY2 选择，KEY4 确认，未确认拨回 0 取消；KEY3 仍复位。

[S2 固定候选与 bit](releases/v0.19.0/{candidate}/README.md)：{resource_text}；DSP 相对基线 {r['dsp']-13:+d}、相对 S1 {r['dsp']-26:+d}。{timing_text}，{len(result['simulations'])} 份仿真及 {len(result['compile_logs'])} 份编译/模型日志通过。[S1 候选](releases/v0.19.0/s1-local.1/README.md) 保留。

[操作与板测](docs/灾害SW3操作与板测.md) · [分阶段计划](docs/灾害移植与SW3选择分阶段计划.md) · [验证](releases/v0.19.0/{candidate}/VALIDATION.md) · [交接](HANDOFF.md)。未建立 board 标签、未正式发布或合并 main。
'''
    path = ROOT/'README.md'
    write(path, overview+'\n## 历史开发状态\n\n'+path.read_text(encoding='utf-8'))
    path = ROOT/'CHANGELOG.md'
    change = f'''## {tag}（2026-10-18，本地通过、板测待验收）

- 完成 SW3 四类中文四宫格与实际 VFAT 目录识别，四独立缩略图槽、帧边界显示描述符、确认/取消/释放交接；完整根目录优先、缺损场景拒绝、可选资源标记清除。既有双应用/参数/字幕/音频/预警/预览/数码管保留。
- TD `{result['build']}`：{resource_text}；{timing_text}。{len(result['simulations'])} 份仿真、{len(result['compile_logs'])} 份编译/模型日志通过，审阅实际 SW3 首级例外及既有 IO/model 边界。[候选](releases/v0.19.0/{candidate}/README.md)。
- 相对基线 LUT {r['lut']-14092:+d}、寄存器 {r['reg']-9530:+d}、BRAM9k {r['bram9k']-46:+d}、DSP {r['dsp']-13:+d}；相对 S1 DSP {r['dsp']-26:+d}。源码/bit/报告逐字节固定，G:\\ 原卡和个人记录不改写。不建 board、未正式发布、未合并 main。

'''
    text = path.read_text(encoding='utf-8')
    write(path, text.replace('## v0.19.0-s1-local.1', change+'## v0.19.0-s1-local.1', 1))
    path = ROOT/'HANDOFF.md'
    handoff = f'''# 当前交接：灾害 S2 本地通过、板测待验收（2026-10-18）

- 当前任务：原目录 feature/mountain-disaster-selector；基线 7e3ac02，S1 afffa80。两阶段本地实现/仿真/TD 已完成，候选 `{tag}`，无 board、正式发布或 main 合并。
- 已完成：四类图层、SW3=C6 四图中文菜单、真实 VFAT 子目录、根目录优先及独立缓存；确认/取消/忙中安全接管与按键释放，保留既有功能。固定 releases/v0.19.0/{candidate}，{resource_text}，{timing_text}；{len(result['simulations'])} 份 S2 仿真及 {len(result['compile_logs'])} 份编译/模型日志通过，审计和证据范围见候选 VALIDATION。
- 当前待办：用户烧录固定候选，按 docs/灾害SW3操作与板测.md 检查四类选择、16 图、宣传、预览、参数、音频、预警与数码管。未收到具体候选板测反馈，不能记板级通过。
- 下一步：提交并同步 GitHub 功能分支及本阶段 local 标签，核对远程引用；具体板测确认后才补 board 记录和标签。失败修复递增 local 编号。前版内容听审及整机待办不补造结论。
- 踩过的坑：boot 高电平不得暂停未完成首图事务；AUTO 必须在整个按键释放交接期间保留 pause；扫描单拍错误需锁存；菜单原色旁路旧 OSD/参数；LOAD_SELECT 和寄存 quiesce/owner 缩短仲裁路径；FAT 范围比较分拍、FIFO Gray 满判断避免长组合使能；hash8 采用等价逐位展开减少 DSP。bitgen/exit0 不等于时序通过，失败构建保留本地。
- 保护：个人记录、用户 TD 日志/状态、best_result、旧 worktree、G:\\ 原卡不改不提交；不写哈希、不批量删除。[本地阶段归档](docs/history/2026-10-18/mountain-disaster-selector/README.md)。
'''
    write(path, handoff+'\n## 历史交接\n\n'+path.read_text(encoding='utf-8'))
    path = ROOT/'docs/灾害移植与SW3选择分阶段计划.md'
    text = path.read_text(encoding='utf-8')
    text = text[:text.index('## 交付状态')]+f'''## 交付状态

两阶段本地完成。S1 `afffa80` / `v0.19.0-s1-local.1`：15780 LUT、10878 寄存器、52 BRAM9k、2 BRAM32k、26 DSP，Setup +0.129ns/Hold +0.012ns、TNS0，45 份仿真通过。

S2 `{tag}`：{resource_text}；{timing_text}，{len(result['simulations'])} 份仿真及 {len(result['compile_logs'])} 份编译/模型日志通过。实际构建 `{result['build']}`，资源差值、审计及证据范围见 releases/v0.19.0/{candidate}。失败构建留本地，不作为候选。

本地通过、板测待验收。用户上板前不建立 board 标签、不正式发布或合并 main；G:\\ 原卡、个人记录及旧 TD 状态保留。本地阶段归档见 [归档](history/2026-10-18/mountain-disaster-selector/README.md)。
'''
    write(path, text)
    archive = ROOT/'docs/history/2026-10-18/mountain-disaster-selector'
    assert not archive.exists(), 'Do not overwrite local-stage archive'
    archive.mkdir(parents=True)
    for src, dest in ((path,'PLAN.md'), (ROOT/'HANDOFF.md','HANDOFF.md'),
                      (release/'README.md','RELEASE.md'), (release/'VALIDATION.md','VALIDATION.md'),
                      (release/'BOARD_RESULT.md','BOARD_RESULT.md')):
        def rebase(match):
            target = match[1]
            if re.match(r'(?:[a-z]+:|#|/)', target, re.I):
                return match[0]
            name, sep, fragment = target.partition('#')
            relative = Path(os.path.relpath((src.parent/name).resolve(), archive)).as_posix()
            return ']('+relative+sep+fragment+')'
        write(archive/dest, re.sub(r'\]\(([^)\n]+)\)', rebase, src.read_text(encoding='utf-8')))
    write(archive/'README.md', f'''# 灾害移植与 SW3 选择：本地阶段归档

2026-10-18，基线 7e3ac02，功能分支 feature/mountain-disaster-selector。S1 和 `{tag}` 本地通过，板测待验收；这里归档本地阶段，不代表任务硬件验收或正式结项。

[固定候选](../../../../releases/v0.19.0/{candidate}/README.md) · [计划快照](PLAN.md) · [交接快照](HANDOFF.md) · [本地验证](VALIDATION.md) · [待板测记录](BOARD_RESULT.md)。GitHub 推送结果以活动交接及实际远程引用为准。无 board 标签、未正式发布、未合并 main。
''')
    print(f'Wrote candidate notes and local-stage archive: {release}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', default='s2-local.1')
    document(parser.parse_args().candidate)
