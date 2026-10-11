"""Freeze verified reset-recovery build into the unpublished local.2 staging area."""
from pathlib import Path
import re
import shutil
import subprocess

root = Path(__file__).resolve().parents[2]
output = root / 'diagnostics/output'
build = output / 'pcm_s3_reset_retry2'
release = root / 'releases/v0.12.0/s3-local.2'
phy = build / 'TD_project/demo_Runs/phy_1'
timing = (phy / 'final_timing.rpt').read_text(errors='replace')
for marker in ('SWNS', 'HWNS'):
    match = re.search(marker + r':\s*([-\d.]+)ns', timing)
    assert match and float(match[1]) >= 0, marker
inputs = [Path('TD_project/demo.al')]
for name in re.findall(r'<File Path="([^"]+)"', (root / inputs[0]).read_text(encoding='utf-8')):
    inputs.append((root / 'TD_project' / name).resolve().relative_to(root))
for name in inputs:
    assert (root / name).read_bytes() == (build / name).read_bytes(), name
logs = []
for run, count in [('reset_final_units1', 4), ('reset_retry_exact1', 1),
                   ('reset_final_regression1', 21), ('reset_final_production1', 1)]:
    found = [p for p in (output / run).glob('tb_*.log')
             if not p.name.endswith(('_compile.log', '.console.log'))]
    assert len(found) == count, (run, len(found))
    for path in found:
        content = path.read_text(errors='replace')
        assert 'PASS ' in content and 'Errors: 0, Warnings: 0' in content, path
        assert not re.search(r'\*\* (Fatal|Error):', content), path
    logs.extend(found)
changed = subprocess.check_output(['git', 'diff', 'v0.12.0-s3-local.1', '--name-only', '--',
                                   'user_source', 'TD_project'], cwd=root, text=True).splitlines()
assert len(changed) == 2, changed
def copy(source, name):
    target = release / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    assert source.read_bytes() == target.read_bytes(), target
copy(phy / 'demo.bit', 'demo.bit')
for name in ('final_timing.rpt', 'demo_phy.area'):
    copy(phy / name, 'reports/' + name)
for name in ('check_timing.txt', 'audit.timing'):
    copy(build / 'timing_audit' / name, 'reports/' + name)
copy(build / 'pcm_cdc_audit/pcm_cdc.timing', 'reports/pcm_cdc.timing')
for run in ('syn_1', 'phy_1'):
    for path in (build / 'TD_project/demo_Runs' / run).glob('*.logw'):
        copy(path, 'reports/' + run + '/' + path.name)
for name in changed:
    copy(root / name, 'changes/' + name)
for path in logs:
    copy(path, Path('simulation') / path.relative_to(output))
lines = ['Baseline: v0.12.0-s3-local.1', 'Build: diagnostics/output/pcm_s3_reset_retry2',
         f'Compared {len(inputs)} project/source inputs byte for byte.',
         f'Passed {len(logs)} simulation logs.', 'Changed production files:'] + changed
lines += ['', 'Files and sizes:'] + [f'{p.relative_to(release).as_posix()} {p.stat().st_size}'
                                    for p in sorted(release.rglob('*')) if p.is_file()]
(release / 'SOURCE_MANIFEST.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
print(f'Packaged {len(inputs)} inputs, {len(changed)} changed files, {len(logs)} simulation logs')
