"""Freeze a verified M1 bit and only changed baseline sources; no file hashes."""
from pathlib import Path
import argparse
import json
import re
import shutil
import subprocess

def read_log(path):
    data = path.read_bytes()
    return data.decode('utf-16' if data.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8', errors='replace')

p = argparse.ArgumentParser()
p.add_argument('build')
p.add_argument('--logs', required=True, help='JSON map of output-relative transcript path to required PASS marker')
p.add_argument('--samples', default='mountain_m1_samples01')
p.add_argument('--candidate', default='m1-local.1')
a = p.parse_args()
root = Path(__file__).resolve().parents[2]
output = root / 'diagnostics/output'
build = output / a.build
phy = build / 'TD_project/demo_Runs/phy_1'
release = root / 'releases/v0.17.0' / a.candidate
assert not release.exists(), 'Never overwrite a candidate'
timing = (phy / 'final_timing.rpt').read_text(errors='replace')
for field in ('SWNS', 'HWNS'):
    value = re.search(field + r':\s*([-\d.]+)ns', timing)
    assert value and float(value[1]) > 0, f'Nonpositive timing: {field}'
for run in ('syn_1', 'phy_1'):
    log = (build / f'TD_project/demo_Runs/{run}/build_{a.build}.log').read_text(errors='replace')
    assert not re.search(r'\bERROR:', log, re.I)
    if run == 'phy_1':
        assert 'Generate bitstream completely' in log
inputs = [Path('TD_project/demo.al')]
inputs += [(root / 'TD_project' / n).resolve().relative_to(root)
           for n in re.findall(r'<File Path="([^"]+)"', (root / inputs[0]).read_text(encoding='utf-8'))]
for name in inputs:
    assert (root / name).read_bytes() == (build / name).read_bytes(), f'Build input mismatch: {name}'
logs = json.loads(Path(a.logs).read_text(encoding='utf-8'))
assert len(logs) >= 144, 'Incomplete M1 simulation matrix'
allowed = re.compile(r'(vopt-(2685|2718|2121)|vsim-(3017|3722)|Design size of .*recommended capacity)')
for name, marker in logs.items():
    text = read_log(output / name)
    assert marker in text and 'Errors: 0,' in text and not re.search(r'\*\* (Fatal|Error)', text), name
    for line in text.splitlines():
        if '** Warning:' in line:
            assert allowed.search(line), f'Unexpected warning: {name}: {line}'
compile_logs = []
for folder in sorted({Path(name).parent for name in logs}):
    for path in sorted((output / folder).glob('*compile*.log')):
        text = read_log(path)
        assert 'Errors: 0,' in text and not re.search(r'\*\* (Fatal|Error)', text), path
        for line in text.splitlines():
            if '** Warning:' in line:
                assert 'vlog-2121' in line, f'Unexpected compile warning: {path}: {line}'
        compile_logs.append(path.relative_to(output))
audit = build / 'timing_audit'
assert (audit / 'check_timing.txt').exists() and (audit / 'audit.timing').exists()
baseline_audit = root / 'releases/v0.16.0/s2-local.1/reports/check_timing.txt'
def audit_summary(path):
    return [line.strip() for line in path.read_text().splitlines()
            if re.search(r'There (are|is)|DummyNode|set_(multicycle_path|max_delay|input_delay)', line)]
assert audit_summary(audit / 'check_timing.txt') == audit_summary(baseline_audit), 'Changed timing audit categories/exceptions'
release.mkdir(parents=True)


def copy(src, name):
    dst = release / name
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)
    assert src.read_bytes() == dst.read_bytes(), f'Copy mismatch: {name}'


copy(phy / 'demo.bit', Path('demo.bit'))
for name in ('final_timing.rpt', 'demo_phy.area'):
    copy(phy / name, Path('reports') / name)
for run in ('syn_1', 'phy_1'):
    folder = build / 'TD_project/demo_Runs' / run
    copy(folder / f'build_{a.build}.log', Path('reports') / f'{run}_build.log')
    copy(folder / 'settings.cfg', Path('reports') / f'{run}_settings.cfg')
for name in ('check_timing.txt', 'audit.timing'):
    copy(audit / name, Path('reports') / name)
for name in logs:
    copy(output / name, Path('validation') / name)
for name in compile_logs:
    copy(output / name, Path('validation') / name)
copy(Path(a.logs), Path('validation/logs.json'))
for path in (output / a.samples).glob('*'):
    if path.is_file():
        copy(path, Path('board_samples') / path.name)
changed = set(subprocess.check_output(['git', '-c', 'core.quotepath=false', 'diff', 'v0.16.0', '--name-only', '--', 'user_source', 'TD_project'], cwd=root, text=True).splitlines())
saved = []
for name in inputs:
    if name.as_posix() in changed:
        copy(root / name, Path('sources') / name)
        saved.append(name)
copy(root / 'diagnostics/mountain_scene/BOARD_VALIDATION_M1.md', Path('BOARD_VALIDATION.md'))
manifest = ['# M1 build inputs', '', f'Baseline v0.16.0; isolated build {a.build}.',
            f'Bit {(phy / "demo.bit").stat().st_size} bytes; {len(inputs)} build inputs compared byte-for-byte.',
            f'{len(saved)} changed production inputs under sources/; {len(logs)} passing simulation transcripts.',
            f'{len(compile_logs)} compiler transcripts retained separately; audit categories/exception summaries equal v0.16.0.',
            'Unchanged user_source inputs reference v0.16.0; unchanged demo.al references v0.17.0-plan.1 (user project snapshot).',
            'Tool roots: E:/TD; F:/quartus18.1/modelsim_ase/win32aloem. No source/configuration changes after build.', '']
manifest += [f'- {n.as_posix()} ({(root / n).stat().st_size} bytes)' + (' [changed]' if n in saved else '') for n in inputs]
(release / 'MANIFEST.md').write_text('\n'.join(manifest) + '\n', encoding='utf-8')
print(f'PASS packaged {release}: {len(inputs)} byte-identical inputs, {len(saved)} changed inputs, {len(logs)} logs')
