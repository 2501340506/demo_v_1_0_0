"""Update the active handoff and archive the completed local implementation."""
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RELEASE = ROOT/'releases/v0.23.0/s2-local.1'
ARCHIVE = ROOT/'docs/history/2026-10-19/thumbnail-fast-start'


def main():
    m = json.loads((RELEASE/'MANIFEST.json').read_text(encoding='utf-8'))
    assert m['board_status'] == 'pending'
    t = m['timing_ns']
    timing = f"Setup +{t['SWNS']:.3f}ns / Hold +{t['HWNS']:.3f}ns，STNS/HTNS=0"
    r = m['resources']
    resources = f"{r['lut']} LUT、{r['reg']}寄存器、{r['bram']} BRAM9k、{r['bram32k']} BRAM32k、{r['dsp']} DSP"
    handoff = f'''# 当前交接：四宫格与开机加速本地通过，待烧录板测（2026-10-19）

- 当前任务：用户确认方案的本地实现已完成；原目录 feature/thumbnail-fast-start，基线 31de2b0 / v0.22.0-s1-local.1，候选 v0.23.0-s2-local.1。
- 已完成：四张 THUMB 原生直写、旧卡 PIC1 回退、确认四阶段图头校验、完整 PIC1 先进入、其余后台缓存/手动请求优先/文件失败重试、菜单缓存与取消恢复；EDU1 优先、FONT/TEXT 延后、初次无淡入淡出及音频等待、FAT 卷参数复用，SPI 频率保持。
- 本地验证：87 份有效 ModelSim 日志、8 项资源工具测试通过；完整 {m['build']}：{timing}，{resources}。134 个源文件逐字节一致，最终物理字模 5796行×21位一致，实际约束未放宽，告警已审阅。[固定候选](releases/v0.23.0/s2-local.1/README.md)。
- 资源：完整卡包保留原50文件，新增4个 THUMB；增量包仅4图，共590040字节。ZIP成员与源数据逐字节核对，G卡本轮只读、未安装新资源包。当前卡已含前版宋体宣传字幕资源。
- 当前问题：无本地阻塞；尚未烧录或取得实体屏幕/音频/性能测试。菜单≤1s、确认≤1.5s、上电争取≤2s仅为目标。S0模型周期不含SPI/Flash/显示器，不能换算板上秒数。
- 下一步：烧录固定 demo.bit，解压增量缩略图到卡根目录，重插卡或KEY3复位；同板同卡同显示器对照各测10次，记录中位数/最大值。核查SW3上电高/快拨/取消、四场景、后台阶段、坏资源及宣传/字幕/音频/AUTO/参数/预警/预览。用户确认具体候选后再建board记录；无正式发布、未合main。
- 踩坑：此前未通过最终时序的构建及已停止的拥塞构建均不交付，逐项记录见固定候选VALIDATION。按实测路径注册退出摘要、逐项缓存标记及恒等LUT修复；等价/显示/控制器已重跑。物理SD超时停止当前传输周期，需菜单重扫或复位；文件损坏可重试。取消替换缓存后须重载原应用；退出摘要须限定状态。UART计时默认关闭，须独立调试构建。PowerShell中文管道显式UTF-8。
- 保护：用户TD GUI工程、个人记录、六个旧日志、历史候选未提交；源卡未写，不写哈希、不批量删除。[计划](docs/四宫格与开机加速实施计划.md) · [计时/资源](docs/四宫格与开机加速计时及资源说明.md) · [本地归档](docs/history/2026-10-19/thumbnail-fast-start/README.md)。
'''
    path = ROOT/'HANDOFF.md'
    old = path.read_text(encoding='utf-8')
    assert old.startswith('# 当前交接：四宫格与开机加速')
    history = old[old.index('## 历史交接'):]
    path.write_text(handoff+'\n'+history, encoding='utf-8')
    path = ROOT/'README.md'
    old = path.read_text(encoding='utf-8')
    assert not old.startswith('# 当前开发阶段：四宫格与开机加速')
    path.write_text(f'''# 当前开发阶段：四宫格与开机加速本地通过

SW3四宫格只加载四张256×192缩略图，旧卡回退PIC1；确认检查四阶段图头，完整PIC1显示后进入，其余后台加载。开机优先完整宣传首图，随后准备字幕、字库、声音和后续图片，首次直接出图。

[固定bit及使用](releases/v0.23.0/s2-local.1/README.md) · [验证](releases/v0.23.0/s2-local.1/VALIDATION.md) · [计时与资源](docs/四宫格与开机加速计时及资源说明.md) · [本地归档](docs/history/2026-10-19/thumbnail-fast-start/README.md)。87份有效仿真日志、8项资源测试及完整TD通过：{timing}。新资源包已生成，本轮未写卡。实板速度与视觉/听审待测；1s/1.5s/2s为目标，无board标签、未正式发布或合main。

## 历史开发状态

'''+old, encoding='utf-8')
    path = ROOT/'CHANGELOG.md'
    old = path.read_text(encoding='utf-8')
    assert not old.startswith('# v0.23.0')
    path.write_text(f'''# v0.23.0 开发中（2026-10-19，未发布）

## v0.23.0-s2-local.1

- 四宫格新增THUMB.BMP原生256×192路径及自动生成工具；四图共590040字节。旧卡/坏缩略图回退PIC1，确认前不读取PIC2–4完整像素；确认校验四阶段头，首张完整提交后进入，其余后台缓存、请求优先、文件错误保留当前帧并可重试。
- EDU1首图优先，情景图头按需验证，FONT/TEXT内容首帧后加载，字库就绪才开字幕并从头讲解；首次直接出图、正常转场保留，复用已验证卷参数，SPI频率不改。
- 87份有效ModelSim日志、资源工具8项测试及完整 {m['build']} 通过；{timing}；{resources}。134源码与最终5796行×21位字模逐字节/逐位核对，约束未放宽，告警已审阅。
- [固定候选与资源](releases/v0.23.0/s2-local.1/README.md)。完整包原50文件加4图，增量包仅4图，源G卡本轮只读。板测尚未执行，性能目标不是实测结果；无board/正式发布/main合并。[本地归档](docs/history/2026-10-19/thumbnail-fast-start/README.md)。

'''+old, encoding='utf-8')
    path = ROOT/'docs/四宫格与开机加速实施计划.md'
    old = path.read_text(encoding='utf-8')
    assert '状态：实施中' in old
    old = old.replace('状态：实施中；无本轮实板测量。原候选保持可回退，不能用仿真或综合代替板测。',
        f'状态：S0计时工具/模型基线、S1菜单按需加载、S2宣传首帧加速的本地实现与验证已完成。固定候选 v0.23.0-s2-local.1，{m["build"]}：{timing}；87份有效仿真日志及8项资源测试通过。无本轮实板测量，板级验收待反馈。原候选保持可回退，不能用仿真或综合代替板测。\n\n[固定候选](../releases/v0.23.0/s2-local.1/README.md) · [本地归档](history/2026-10-19/thumbnail-fast-start/README.md)。')
    path.write_text(old, encoding='utf-8')
    assert not ARCHIVE.exists()
    ARCHIVE.mkdir(parents=True)
    (ARCHIVE/'最终交接.md').write_text(handoff.replace('](releases/', '](../../../../releases/').replace('](docs/', '](../../../'), encoding='utf-8')
    shutil.copyfile(path, ARCHIVE/'实施计划.md')
    for filename in ('README.md', 'VALIDATION.md'):
        shutil.copyfile(RELEASE/filename, ARCHIVE/('发布说明.md' if filename=='README.md' else '验收结论.md'))
    # Archived copies are self-contained text; active navigation is provided by
    # this index so release-relative links cannot resolve to another candidate.
    for filename in ('发布说明.md', '验收结论.md', '实施计划.md', '最终交接.md'):
        p = ARCHIVE/filename
        s = p.read_text(encoding='utf-8')
        import re
        s = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'\1（\2，路径相对原文）', s)
        p.write_text(s, encoding='utf-8')
    (ARCHIVE/'README.md').write_text('''# 四宫格与开机加速本地实现归档

本地候选 `v0.23.0-s2-local.1`，实体板测待反馈，未正式发布或合并main。

- [固定候选及资源](../../../../releases/v0.23.0/s2-local.1/README.md)
- [有效验证证据](../../../../releases/v0.23.0/s2-local.1/VALIDATION.md)
- [实施计划快照](实施计划.md)
- [最终交接快照](最终交接.md)
- [验收结论快照](验收结论.md)
- [发布说明快照](发布说明.md)

快照内保留原文路径文字，实际下载和相对链接以固定候选为准。板测结论后续按用户具体反馈补记，不追改本地候选标签。
''', encoding='utf-8')
    print('PASS active documentation and local archive', timing)


if __name__ == '__main__':
    main()
