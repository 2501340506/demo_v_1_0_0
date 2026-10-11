"""Freeze S1 only after final-source simulation and routed timing pass."""
from pathlib import Path
import re
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
build = root / 'diagnostics/output' / sys.argv[1]
release = root / 'releases/v0.12.0' / sys.argv[2]
if release.exists():
    raise SystemExit('Use a new candidate number')
phy = build / 'TD_project/demo_Runs/phy_1'
timing = (phy / 'final_timing.rpt').read_text(errors='replace')
for marker in ('SWNS', 'HWNS'):
    match = re.search(marker + r':\s*([-\d.]+)ns', timing)
    if not match or float(match[1]) < 0:
        raise SystemExit('Routed timing has not passed')
inputs = [Path('TD_project/demo.al')]
for name in re.findall(r'<File Path="([^"]+)"', (root / inputs[0]).read_text(encoding='utf-8')):
    inputs.append((root / 'TD_project' / name).resolve().relative_to(root))
for name in inputs:
    if (root / name).read_bytes() != (build / name).read_bytes():
        raise SystemExit(f'Build input changed: {name}')

evidence = []
def verify(path, marker, allow_warnings=False):
    text = path.read_text(errors='replace')
    if marker not in text or re.search(r'\*\* (Fatal|Error):', text) or 'Errors: 0,' not in text:
        raise SystemExit(f'Failed or unfinished simulation: {path}')
    if not allow_warnings and 'Errors: 0, Warnings: 0' not in text:
        raise SystemExit(f'Unexpected warning: {path}')
    evidence.append(path)

output = root / 'diagnostics/output'
verify(output / 'pcm_s1_service3/service.log', 'PASS sector service:')
for case in range(42):
    verify(output / f'pcm_s1_reader2/reader{case}_gap2_mode0.log', 'PASS FAT32 reader')
logs = [p for p in (output / 'pcm_s1_regression1').glob('tb_*.log') if not p.name.endswith('.console.log')]
if len(logs) != 21:
    raise SystemExit('Expected 21 regression results')
for path in logs:
    verify(path, 'PASS ')
system = output / 'pcm_s1_system1/system.log'
verify(system, 'PASS cache system:', True)
system_text = system.read_text(errors='replace')
for marker in ('PASS S2 origin:', 'PASS transition system:', 'Timestamp system observations:', 'UART system observations: 4 serial command stages'):
    if marker not in system_text:
        raise SystemExit(f'Missing system observation: {marker}')
for line in system_text.splitlines():
    if '** Warning:' in line and not re.search(r'vopt-(2685|2718|2121)', line):
        raise SystemExit(f'Unexpected system warning: {line}')

changed = subprocess.check_output(['git', 'diff', 'v0.11.0', '--name-only', '--', 'user_source', 'TD_project'], cwd=root, text=True).splitlines()
untracked = subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard', '--', 'user_source', 'TD_project'], cwd=root, text=True).splitlines()
changed = sorted(set(changed + untracked))
release.mkdir(parents=True)
def copy(source, destination):
    target = release / destination
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    if source.read_bytes() != target.read_bytes():
        raise SystemExit(f'Copy mismatch: {target}')

copy(phy / 'demo.bit', 'demo.bit')
for name in ('final_timing.rpt', 'demo_phy.area'):
    copy(phy / name, 'reports/' + name)
for path in phy.glob('*.logw'):
    copy(path, 'reports/' + path.name)
for name in ('check_timing.txt', 'audit.timing'):
    copy(build / 'timing_audit' / name, 'reports/' + name)
for name in changed:
    copy(root / name, 'changes/' + name)
for path in evidence:
    copy(path, Path('simulation') / path.relative_to(output))
lines = ['Baseline: v0.11.0 / ff1c138', f'Build: {build.relative_to(root)}',
         f'Compared {len(inputs)} project/source inputs byte for byte.',
         'Changed production files:'] + changed
lines += ['', 'Files and sizes:'] + [f'{p.relative_to(release).as_posix()} {p.stat().st_size}' for p in sorted(release.rglob('*')) if p.is_file()]
(release / 'SOURCE_MANIFEST.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
print(f'Packaged {len(inputs)} inputs, {len(changed)} changed files, {len(evidence)} simulation logs')
