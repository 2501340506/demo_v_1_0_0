"""Freeze an M3 candidate after simulation, TD and audit; compare bytes, no hashes."""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess


ROOT = Path(__file__).resolve().parents[2]


def read_log(path):
    raw = path.read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8', errors='replace')


def known_warning(line):
    if re.search(r'(vopt-(2685|2718|2121)|vsim-(3017|3722)|vlog-2121)', line):
        return True
    if re.search(r'(vopt-2241|vsim-3015)', line):
        return 'sys_pll_s3.v(89)' in line and 'load_reg' in line
    if '(vlog-2275)' in line:
        return 'al_phy_glbl.v(23)' in line and "'glbl' already exists and will be overwritten." in line
    return line.strip() == '** Warning: (vlog-13288) Multiple macros defined in +define+ command line switch.'


def check_log(path, marker=None):
    text = read_log(path)
    assert 'Errors: 0,' in text and not re.search(r'\*\* (Fatal|Error)', text), path
    if marker:
        assert marker in text, (path, marker)
    for line in text.splitlines():
        if '** Warning:' in line:
            assert known_warning(line), (path, line)


def audit_summary(path):
    return [line.strip() for line in read_log(path).splitlines()
            if re.search(r'There (are|is)|DummyNode|set_(multicycle_path|max_delay|input_delay)', line)]


def package(build_name, candidate):
    output = ROOT / 'diagnostics/output'
    build = output / build_name
    phy = build / 'TD_project/demo_Runs/phy_1'
    release = ROOT / 'releases/v0.17.0' / candidate
    assert not release.exists(), 'Never overwrite a candidate'
    timing = read_log(phy / 'final_timing.rpt')
    for field in ('SWNS', 'HWNS'):
        value = re.search(field + r':\s*([-\d.]+)ns', timing)
        assert value and float(value[1]) > 0, f'Nonpositive {field}'
    for run in ('syn_1', 'phy_1'):
        text = read_log(build / f'TD_project/demo_Runs/{run}/build_{build_name}.log')
        assert not re.search(r'\bERROR:', text, re.I)
        if run == 'phy_1':
            assert 'Generate bitstream completely' in text
    inputs = [Path('TD_project/demo.al')]
    inputs += [(ROOT / 'TD_project' / n).resolve().relative_to(ROOT)
               for n in re.findall(r'<File Path="([^"]+)"', (ROOT / inputs[0]).read_text(encoding='utf-8'))]
    for name in inputs:
        assert (ROOT / name).read_bytes() == (build / name).read_bytes(), f'Build input mismatch: {name}'
    log_config = ROOT / 'diagnostics/mountain_scene/m3_logs.json'
    logs = json.loads(log_config.read_text(encoding='utf-8'))
    assert len(logs) == 8
    for name, marker in logs.items():
        check_log(output / name, marker)
    compile_logs = []
    for folder in sorted({Path(name).parent for name in logs}):
        for path in sorted((output / folder).glob('*.log')):
            if 'compile' in path.name or path.name in ('vendor.log', 'encrypted.log', 'pll.log'):
                check_log(path)
                compile_logs.append(path.relative_to(output))
    audit = build / 'timing_audit'
    baseline = ROOT / 'releases/v0.17.0/m1-local.1/reports/check_timing.txt'
    assert audit_summary(audit / 'check_timing.txt') == audit_summary(baseline), 'Changed audit categories/exceptions'
    changed = set(subprocess.check_output(['git', 'diff', 'v0.17.0-m1-local.1', '--name-only', '--',
                                          'user_source', 'TD_project'], cwd=ROOT).decode('utf-8').splitlines())
    saved = [p for p in inputs if p.as_posix() in changed]
    assert len(saved) == 4, saved
    release.mkdir(parents=True)

    def copy(src, name):
        dst = release / name
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)
        assert src.read_bytes() == dst.read_bytes(), name

    copy(phy / 'demo.bit', Path('demo.bit'))
    for name in ('final_timing.rpt', 'demo_phy.area'):
        copy(phy / name, Path('reports') / name)
    for run in ('syn_1', 'phy_1'):
        folder = build / 'TD_project/demo_Runs' / run
        copy(folder / f'build_{build_name}.log', Path('reports') / f'{run}_build.log')
        copy(folder / 'settings.cfg', Path('reports') / f'{run}_settings.cfg')
    for name in ('check_timing.txt', 'audit.timing'):
        copy(audit / name, Path('reports') / name)
    for name in list(logs) + compile_logs:
        copy(output / name, Path('validation') / name)
    copy(log_config, Path('validation/logs.json'))
    for name in saved:
        copy(ROOT / name, Path('sources') / name)
    copy(ROOT / 'diagnostics/mountain_scene/BOARD_VALIDATION_M3.md', Path('BOARD_VALIDATION.md'))
    assets = ROOT / 'tools/scenes/demo_village/generated'
    for path in assets.rglob('*'):
        if path.is_file():
            copy(path, Path('board_samples') / path.relative_to(assets))
    manifest = ['# M3 build inputs', '', f'Build: {build_name}; {len(inputs)} inputs compared byte-for-byte.',
                f'Bit: {(phy / "demo.bit").stat().st_size} bytes; {len(saved)} changed inputs saved.',
                f'{len(logs)} simulation and {len(compile_logs)} compiler logs checked and retained.',
                'Unchanged inputs reference v0.17.0-m1-local.1; M2 assets reference commit 3535c0b.',
                'Hardware fallback remains board-confirmed v0.16.0. M1 and M3 board confirmation pending.',
                'Timing audit categories/exception summaries equal M1; original known tool warnings preserved.',
                'TD E:/TD v6.2; ModelSim SE-64 10.6e F:/modelsim/win64; no file hashes.', '']
    manifest += [f'- {p.as_posix()} ({(ROOT / p).stat().st_size} bytes)' + (' [changed]' if p in saved else '')
                 for p in inputs]
    (release / 'MANIFEST.md').write_text('\n'.join(manifest)+'\n', encoding='utf-8')
    print(f'PASS M3 package: {release}; {len(inputs)} equal inputs, {len(logs)} passing simulations')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('build')
    parser.add_argument('--candidate', default='m3-local.1')
    args = parser.parse_args()
    package(args.build, args.candidate)
