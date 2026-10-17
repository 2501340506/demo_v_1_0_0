"""Freeze M5 only after successful simulations, timing, area and reviewed audit."""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('m6_checks', ROOT / 'diagnostics/mountain_scene/package_m6.py')
checks = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checks)


def check_log(path, marker=None):
    text = checks.read_log(path)
    assert 'Errors: 0,' in text and not re.search(r'\*\* (Fatal|Error)', text), path
    if marker:
        assert marker in text, (path, marker)
    for line in text.splitlines():
        if '** Warning:' in line:
            assert checks.known_warning(line), (path, line)


def warnings(path):
    result = set()
    for line in checks.read_log(path).splitlines():
        if re.search(r'WARNING|Warning|WARN-', line):
            line = re.sub(r'publicity_m[345]_td_attempt\d+', 'BUILD', line)
            result.add(re.sub(r'\(\d+\)', '(line)', line).strip())
    return result


def package(build_name, config, review):
    output = ROOT / 'diagnostics/output'
    build = output / build_name
    phy = build / 'TD_project/demo_Runs/phy_1'
    release = ROOT / 'releases/v0.18.0/m5-local.1'
    assert not release.exists(), 'Never overwrite a candidate'
    margins = {}
    timing = checks.read_log(phy / 'final_timing.rpt')
    for field in ('SWNS', 'HWNS', 'STNS', 'HTNS'):
        margins[field] = float(re.search(field + r':\s*([-\d.]+)ns', timing)[1])
        assert margins[field] > 0 if field.endswith('WNS') else margins[field] == 0, margins
    area = checks.read_log(phy / 'demo_phy.area')
    lut = int(re.search(r'(?m)^#lut\s+(\d+)', area)[1])
    assert lut <= 16660, lut
    bit_bytes = (phy / 'demo.bit').stat().st_size
    assert bit_bytes > 0
    for run in ('syn_1', 'phy_1'):
        text = checks.read_log(build / f'TD_project/demo_Runs/{run}/build_{build_name}.log')
        assert not re.search(r'\bERROR[: ]', text, re.I), run
        # Reject combinational-loop timing cuts, including the M4 AUTO path.
        assert not re.search(r'\bTMR-250[79]\b', text), 'Combinational-loop timing cut remains'
        if run == 'phy_1':
            assert 'Generate bitstream completely' in text
    inputs = [Path('TD_project/demo.al')]
    inputs += [(ROOT / 'TD_project' / p).resolve().relative_to(ROOT)
               for p in re.findall(r'<File Path="([^"]+)"', (ROOT / inputs[0]).read_text(encoding='utf-8'))]
    for name in inputs + [Path('diagnostics/run_td_build.ps1')]:
        assert (ROOT / name).read_bytes() == (build / name).read_bytes(), name
    assert (ROOT / '问题小记录.txt').read_bytes() == (output / 'publicity_m5_baseline01/personal_original.bin').read_bytes()
    logs = json.loads(config.read_text(encoding='utf-8'))
    assert logs
    for name, marker in logs.items():
        check_log(output / name, marker)
    compile_logs = []
    for folder in sorted({Path(n).parent for n in logs}):
        for path in sorted((output / folder).glob('*.log')):
            if 'compile' in path.name or path.name in ('vendor.log', 'encrypted.log', 'pll.log'):
                check_log(path)
                compile_logs.append(path.relative_to(output))
    audit = build / 'timing_audit'
    prior = ROOT / 'releases/v0.18.0/m4-local.1/reports'
    delta = {}
    for run in ('syn_1', 'phy_1'):
        now = warnings(build / f'TD_project/demo_Runs/{run}/build_{build_name}.log')
        old = warnings(prior / f'{run}_build.log')
        delta[run] = {'new': sorted(now - old), 'gone': sorted(old - now)}
    actual_review = {'audit_summary': checks.audit_summary(audit / 'check_timing.txt'), 'warning_delta': delta}
    assert actual_review == json.loads(review.read_text(encoding='utf-8')), 'Audit differs from reviewed diagnostics'
    changed = subprocess.check_output(['git', '-c', 'core.quotepath=false', 'diff', 'v0.18.0-m4-local.1', '--name-only', '--', 'user_source', 'TD_project'], cwd=ROOT).decode('utf-8').splitlines()
    saved = [p for p in inputs if p.as_posix() in changed]
    assert len(saved) == 3 and len(changed) == 3, changed
    release.mkdir(parents=True)
    (release / '.gitattributes').write_text('** -text whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol\nreports/** -text -whitespace\nvalidation/** -text -whitespace\nsources/** -text -whitespace\n', encoding='utf-8')

    def copy(src, dst):
        target = release / dst
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, target)
        assert src.read_bytes() == target.read_bytes(), target

    copy(phy / 'demo.bit', Path('demo.bit'))
    for name in ('final_timing.rpt', 'demo_phy.area'):
        copy(phy / name, Path('reports') / name)
    for run in ('syn_1', 'phy_1'):
        folder = build / f'TD_project/demo_Runs/{run}'
        copy(folder / f'build_{build_name}.log', Path('reports') / f'{run}_build.log')
        copy(folder / 'settings.cfg', Path('reports') / f'{run}_settings.cfg')
    for name in ('check_timing.txt', 'audit.timing'):
        copy(audit / name, Path('reports') / name)
    copy(review, Path('reports/audit_review.json'))
    for name in list(logs) + compile_logs:
        copy(output / name, Path('validation') / name)
    copy(config, Path('validation/logs.json'))
    for name in saved:
        copy(ROOT / name, Path('sources') / name)
    for name in ('diagnostics/run_td_build.ps1', 'diagnostics/mountain_scene/build_m5.ps1', 'diagnostics/publicity_mode/run_m4_audit.ps1', 'diagnostics/publicity_mode/package_m5.py'):
        copy(ROOT / name, Path('reproduce') / name)
    manifest = ['# M5 构建与源码清单', '', f'Build: {build_name}',
                f'{len(inputs)} 个工程输入及根构建脚本与隔离快照逐字节一致。',
                f'Bit: {bit_bytes} bytes; LUT {lut}/19600; timing {margins}.',
                f'{len(logs)} 份仿真及 {len(compile_logs)} 份编译/模型日志通过核验。',
                f'仅备份相对 v0.18.0-m4-local.1 实际变化的{len(saved)}个生产文件；其他输入引用该标签。',
                '个人问题记录与M5开始副本逐字节一致，不纳入交付；无文件哈希。', '', '## 工程输入（变化项标为 saved）', '']
    manifest += [f'- {p.as_posix()} ({(ROOT / p).stat().st_size} bytes)' + (' [saved]' if p in saved else '') for p in inputs]
    (release / 'MANIFEST.md').write_text('\n'.join(manifest) + '\n', encoding='utf-8')
    print(f'PASS M5 package: {len(inputs)} equal inputs; {len(saved)} saved; {len(logs)} simulations; {len(compile_logs)} compiler logs; bit {bit_bytes}; LUT {lut}; {margins}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('build')
    parser.add_argument('config', type=Path)
    parser.add_argument('review', type=Path)
    args = parser.parse_args()
    package(args.build, args.config, args.review)
