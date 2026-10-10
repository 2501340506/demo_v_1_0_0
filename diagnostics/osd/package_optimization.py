"""Freeze the validated v0.9.1 candidate, preserving only changed sources."""
from pathlib import Path
import shutil
import subprocess
import re

root = Path(__file__).resolve().parents[2]
build = root / 'diagnostics/output/osd_opt_attempt1'
release = root / 'releases/v0.9.1/s3-local.1'
if release.exists():
    raise SystemExit('Candidate already exists; preserve it and use a new number.')
project = root / 'TD_project/demo.al'
inputs = [Path('TD_project/demo.al')]
for name in re.findall(r'<File Path="([^"]+)"', project.read_text(encoding='utf-8')):
    inputs.append((project.parent / name).resolve().relative_to(root))
for name in inputs:
    if (root / name).read_bytes() != (build / name).read_bytes():
        raise SystemExit(f'Build input differs: {name}')
changed = subprocess.check_output(
    ['git', 'diff', 'v0.9.0', '--name-only', '--', 'user_source', 'TD_project'],
    cwd=root, text=True).splitlines()
release.mkdir(parents=True)

def copy(source, target):
    target = release / target
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    if source.read_bytes() != target.read_bytes():
        raise SystemExit(f'Copy differs: {target}')

phy = build / 'TD_project/demo_Runs/phy_1'
copy(phy / 'demo.bit', 'demo.bit')
for name in ('demo_phy.area', 'final_timing.rpt'):
    copy(phy / name, 'reports/' + name)
for name in ('check_timing.txt', 'audit.timing'):
    copy(build / 'timing_audit' / name, 'reports/' + name)
copy(root / 'releases/v0.9.0/s2-local.1/reports/check_timing.txt',
     'reports/baseline_s2_check_timing.txt')
for name in changed:
    copy(root / name, 'changes/' + name)
for run in ('osd_opt_status2', 'osd_opt_scroll1', 'osd_opt_alpha1',
            'osd_opt_params1', 'osd_opt_system1', 'osd_opt_regression1'):
    for source in (root / 'diagnostics/output' / run).glob('*.log'):
        if not source.name.endswith('console.log') and source.name != 'library.log':
            copy(source, 'simulation/' + run + '/' + source.name)
lines = [f'Baseline: v0.9.0', f'Build: diagnostics/output/osd_opt_attempt1',
         f'Compared {len(inputs)} project inputs byte-for-byte against build snapshot.',
         'Changed production inputs:'] + changed
lines += ['', 'Delivered files (bytes):']
lines += [f'{p.relative_to(release).as_posix()} {p.stat().st_size}'
          for p in sorted(release.rglob('*')) if p.is_file()]
(release / 'files.txt').write_text('\n'.join(lines) + '\n', encoding='utf-8')
print(f'Packaged {len(inputs)} verified inputs, {len(changed)} changed source/config files, '
      f'{(release / "demo.bit").stat().st_size} byte bitstream.')
