"""Freeze the per-page diagnostic candidate; never modifies media or old releases."""
import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASELINE = '8a1dda5'
TESTS = (
    'page_fix_concurrent01/detail_final.log',
    'page_fix_concurrent01/diag_final_case0.log',
    'page_fix_concurrent01/diag_final_case16.log',
    'page_fix_concurrent01/diag_final_case18.log',
    'page_fix_concurrent01/diag_final_case19.log',
    'page_fix_concurrent01/diag_spi_audio19_final.log',
    'page_fix_concurrent01/case23.log',
    'page_fix_concurrent01/frame19_retry.log',
)


def read(path):
    raw = path.read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig', errors='replace')


def freeze(name):
    build = ROOT / 'diagnostics/output' / name
    phy = build / 'TD_project/demo_Runs/phy_1'
    target = ROOT / 'releases/v0.23.0/s2-diagnostic.1'
    assert not target.exists(), 'Choose a new candidate; never overwrite a release'
    metrics = {k: float(re.search(k+r':\s*([-\d.]+)ns', read(phy/'final_timing.rpt'))[1])
               for k in ('SWNS', 'HWNS', 'STNS', 'HTNS')}
    assert metrics['SWNS'] > 0 and metrics['HWNS'] > 0 and metrics['STNS'] == metrics['HTNS'] == 0
    area = read(phy/'demo_phy.area')
    resources = {k: int(re.search(r'^#'+k+r'\s+(\d+)', area, re.M)[1])
                 for k in ('lut', 'reg', 'bram', 'bram32k', 'dsp')}
    assert all(resources[k] <= limit for k, limit in dict(lut=19600, reg=19600, bram=64, bram32k=16, dsp=29).items())
    review = json.loads((build/'timing_audit/warning_review.json').read_text(encoding='utf-8'))
    assert review['reviewed'] and review['font_rom_initialization_verified'] and review['constraints_byte_identical']
    for stage in ('syn_1', 'phy_1'):
        log = read(build/f'TD_project/demo_Runs/{stage}/build_{name}.log')
        assert not re.search(r'\bERROR:', log)
        if stage == 'phy_1':
            assert 'Generate bitstream completely' in log
    checked = []
    for source in sorted((build/'user_source').rglob('*')):
        if source.is_file():
            relative = source.relative_to(build)
            assert source.read_bytes() == (ROOT/relative).read_bytes(), str(relative)
            checked.append(relative.as_posix())
    assert len(checked) == 134
    assert not subprocess.check_output(['git', 'diff', 'HEAD', '--', 'user_source'], cwd=ROOT)
    changed = subprocess.check_output(['git', 'diff', '--name-only', BASELINE, 'HEAD'], cwd=ROOT,
                                      text=True, encoding='utf-8').splitlines()
    production = [p for p in changed if p.startswith('user_source/')]
    assert production == ['user_source/hdl_source/SD/sd_card_bmp.v'], production
    for relative in TESTS:
        log = read(ROOT/'diagnostics/output'/relative)
        assert 'PASS ' in log and 'Errors: 0,' in log and not re.search(r'\*\* (Fatal|Error):', log), relative

    def copy(source, relative):
        dest = target/relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, dest)
        assert dest.read_bytes() == source.read_bytes(), relative

    copy(phy/'demo.bit', 'demo.bit')
    for path in production + [p for p in changed if p.startswith('diagnostics/disaster_selector/')]:
        copy(ROOT/path, 'sources/'+path)
    for path in ('HANDOFF.md', 'CHANGELOG.md', 'docs/加速候选后续图片修复计划.md'):
        copy(ROOT/path, 'sources/'+path)
    copy(build/'TD_project/demo.al', 'reproduce/demo.al')
    for path in ('diagnostics/bottom_waveform/run_td.ps1', 'diagnostics/run_td_build.ps1',
                 'diagnostics/disaster_selector/audit_s2.ps1', 'diagnostics/publicity_mode/run_m4_audit.ps1',
                 'diagnostics/narration_subtitles/check_font_map.py', 'diagnostics/disaster_selector/review_fast_build.py'):
        copy(ROOT/path, 'reproduce/'+path)
    for path in ('final_timing.rpt', 'demo_phy.area', 'settings.cfg', f'build_{name}.log'):
        copy(phy/path, 'reports/'+path)
    for path in ('demo_gate.area', 'settings.cfg', f'build_{name}.log'):
        copy(build/'TD_project/demo_Runs/syn_1'/path, 'reports/synthesis/'+path)
    for path in ('audit.timing', 'check_timing.txt', 'exceptions.timing', 'sw3_sync.timing',
                 'console.log', 'exceptions.log', 'audit.tcl', 'exceptions.tcl',
                 'warning_review.json', 'font_rom_check.json'):
        copy(build/'timing_audit'/path, 'reports/audit/'+path)
    copy(build/'user_source/constraints_source/timing.sdc', 'reports/timing.sdc')
    (target/'reports/source_check.json').write_text(json.dumps(dict(method='full byte comparison', files=checked), indent=2)+'\n', encoding='utf-8')
    for path in TESTS:
        copy(ROOT/'diagnostics/output'/path, 'validation/'+path)
    copy(ROOT/'diagnostics/output/page_fix_concurrent01/combined19_retry.log',
         'validation/incomplete/combined19_retry.log')
    for path in ('detail_compile.log', 'regression_compile.log', 'frame_compile.log'):
        copy(ROOT/'diagnostics/output/page_fix_concurrent01'/path, 'validation/page_fix_concurrent01/'+path)
    metadata = dict(baseline=BASELINE, source_commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                    build=name, metrics_ns=metrics, resources=resources, tests=TESTS,
                    purpose='diagnosis only; board root cause and functional repair not confirmed')
    (target/'manifest.json').write_text(json.dumps(metadata, indent=2)+'\n', encoding='utf-8')
    (target/'README.md').write_text(f'''# 后续图片故障诊断候选

**仅用于定位，尚未修复或确认板上根因。** 基线 `v0.23.0-s2-local.1 / {BASELINE}`，源码提交 `{metadata['source_commit']}`；标签 `v0.23.0-s2-diagnostic-local.1`。

烧录本目录固定 `demo.bit`，沿用当前卡资源。复位后分别尝试宣传 EDU2、EDU3、EDU4，以及场景 PIC4 和预警；请记录每项屏幕上的 errors 十六进制值。不同目标请分别复位测试，避免旧错误保留造成混淆。数码管仍为0D，主要观察屏幕 errors。

新增逐图片错误保存，失败目标的原因不会被其他背景图片覆盖；成功重试/提交/重新扫描清除错误。缓存、读写和切页逻辑保持基线行为。

| errors | 含义 |
|---|---|
| 10 / 11 / 12 / 13 | 扇区读取失败 / 超时 / 字节数异常 / 取消 |
| 23 / 24 / 25 / 26 | FAT链循环 / 簇范围错误 / 提前EOF / 链长上限 |
| 41 / 42 / 43 | BMP头格式失败 / 上游错误 / 数据不完整或映射失败 |
| 81 / 82 / 83 | 内存写入溢出 / 像素数不符 / 写入停顿 |
| 03 | 仍未捕获到细分原因，目标请求失败 |

本地完整TD：Setup {metrics['SWNS']:+.3f}ns，Hold {metrics['HWNS']:+.3f}ns，STNS/HTNS=0；LUT {resources['lut']}、寄存器 {resources['reg']}、BRAM9k {resources['bram']}、BRAM32k {resources['bram32k']}、DSP {resources['dsp']}。约束、134源码/SDC和最终5796×21字模已核验。详细证据见 VALIDATION.md 和 reports。

回退：`../s2-local.1/demo.bit` 是已报告故障的加速基线；加速前版本为 `../../v0.22.0/s1-local.1/demo.bit`。旧候选均未覆盖。

复现：恢复基线完整工程，将 sources 的增量文件覆盖回原路径；构建配置见 reproduce/demo.al、reports/settings.cfg。源码包含诊断测试工具，不包含实体卡副本。用户自己的GUI工程未纳入。
''', encoding='utf-8')
    (target/'VALIDATION.md').write_text('''# 验证范围与限制

新增诊断 RTL：detail 专项验证逐图片隔离、请求关联、FAT/BMP/内存优先级及重试/提交/重扫清除；case0 四场景16图、菜单取消/持键等；case16首图先于FONT/TEXT；case18真实坏签名两次失败得到41并在成功重试后清除；case19真实25MHz pixel/音频分频、模拟外存，手动及AUTO四页、场景四阶段和预警PIC4通过。diag_spi_audio19额外使用BYTE_GAP48和真实HDMI音频桥背压。

frame19_retry增加接近真实的16.8ms帧周期，25MHz pixel及真实HDMI背压，外存模拟；测试在应用切换后等待场景首图/音频握手就绪再发导航，覆盖宣传手动四页、场景四阶段和预警PIC4，不覆盖AUTO。

case23是改诊断前相同业务逻辑的证据：完整640×480的24/32位图、64扇区/簇、BYTE_GAP48和持续PCM、真实音频静音反馈，内存writer/reader模拟；该次旧bench像素71.4MHz，音频分频参数25MHz，不能宣称板级音频速率。

真实SDRAM writer/controller/reader联合combined19_retry仅完成宣传手动四页；进入场景后持续等待，在5.4秒仿真处人工停止，未完成，不计PASS，记录放validation/incomplete。此前case21在3秒watchdog失败。上述联合覆盖仍有缺口，不能据此声称整体显示链路验证完成，也未将等待判为板上根因。独立reader逐RGB测试是此前分项验证。case18诊断断言初次误写43，实测坏签名为41，纠正测试预期后通过，生产RTL未因此改变。

上述测试均未复现用户板上的故障；实体卡FAT布局、物理SD传输、实板显示与启动性能尚待验证。不能把本地通过当作板级通过，不能把本候选称作修复版。本轮不写卡、不改资源、不提高SPI频率、不放宽SDC。
''', encoding='utf-8')
    print('Frozen diagnostic:', target)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build', required=True)
    freeze(parser.parse_args().build)
