"""Freeze an actually verified candidate; compare every build input by bytes."""
from pathlib import Path
import argparse
import re
import shutil
import subprocess

p = argparse.ArgumentParser()
p.add_argument('build')
p.add_argument('--candidate', default='s2-local.1')
p.add_argument('--top-run', default='adjust_top5')
a = p.parse_args()
root = Path(__file__).resolve().parents[2]
output = root / 'diagnostics/output'
build = output / a.build
phy = build / 'TD_project/demo_Runs/phy_1'
release = root / 'releases/v0.15.0' / a.candidate
timing = (phy / 'final_timing.rpt').read_text(errors='replace')
for field in ('SWNS', 'HWNS'):
    value = re.search(field + r':\s*([-\d.]+)ns', timing)
    assert value and float(value[1]) >= 0, f'Timing failed: {field}'
inputs = [Path('TD_project/demo.al')]
inputs += [(root / 'TD_project' / n).resolve().relative_to(root)
           for n in re.findall(r'<File Path="([^"]+)"', (root / inputs[0]).read_text(encoding='utf-8'))]
for name in inputs:
    assert (root / name).read_bytes() == (build / name).read_bytes(), f'Changed build input: {name}'
logs = {}
for test in ('tb_adjust','tb_volume','tb_adjust_cdc','tb_adjust_keys','tb_adjust_osd','tb_adjust_decimal'):
    logs[f'adjust_unit5/{test}.log'] = 'PASS '
for module in ('brightness_contrast_adjust', 'pcm_master_volume'):
    logs[f'adjust_gate3/{module}/gate.log'] = 'PASS '
for run in ('adjust_regression2', 'adjust_regression_tail1'):
    for f in (output / run).glob('tb_*.log'):
        if '.console.' not in f.name:
            # The corrected reset assertion is validated in the tail run.
            if run == 'adjust_regression2' and f.name == 'tb_flash_reset.log':
                continue
            logs[f.relative_to(output).as_posix()] = 'PASS '
for f in (output / 'adjust_control_final1').glob('tb_*.log'):
    if '.console.' not in f.name:
        logs[f.relative_to(output).as_posix()] = 'PASS '
logs['adjust_preview_keys1/sim.log'] = 'PASS preview keys:'
logs['adjust_system1/system.log'] = 'PASS cache system:'
logs['adjust_preview_final1/system.log'] = 'PASS preview system:'
logs[f'{a.top_run}/top.log'] = 'PASS production top'
for name, marker in logs.items():
    text = (output / name).read_text(errors='replace')
    assert marker in text and 'Errors: 0,' in text and not re.search(r'\*\* (Fatal|Error):', text), name
assert (build / 'timing_audit/check_timing.txt').exists(), 'Missing timing audit'
assert not release.exists(), 'Never overwrite an existing candidate'
release.mkdir(parents=True)

def copy(src, name):
    dst = release / name
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)
    assert src.read_bytes() == dst.read_bytes()

copy(phy / 'demo.bit', Path('demo.bit'))
for name in ('final_timing.rpt','demo_phy.area'):
    copy(phy / name, Path('reports') / name)
for run in ('syn_1','phy_1'):
    run_dir = build / 'TD_project/demo_Runs' / run
    copy(run_dir / f'build_{a.build}.log', Path('reports') / f'{run}_build.log')
    copy(run_dir / 'settings.cfg', Path('reports') / f'{run}_settings.cfg')
for name in ('check_timing.txt','audit.timing'):
    copy(build / 'timing_audit' / name, Path('reports') / name)
for name in logs:
    copy(output / name, Path('validation') / name)
changed = set(subprocess.check_output(['git','diff','v0.14.0','--name-only','--','user_source','TD_project'], cwd=root, text=True).splitlines())
baseline = set(subprocess.check_output(['git','ls-tree','-r','--name-only','v0.14.0'], cwd=root, text=True).splitlines())
saved = []
for name in inputs:
    if name.as_posix() in changed or name.as_posix() not in baseline:
        copy(root / name, Path('sources') / name)
        saved.append(name)
for name in ('S2_VALIDATION.md','BOARD_VALIDATION.md'):
    copy(root / 'diagnostics/media_adjust' / name, Path(name))
manifest = ['# S2 candidate inputs','',f'Baseline v0.14.0; build {a.build}.',
            f'Bit {(phy / "demo.bit").stat().st_size} bytes; {len(inputs)} inputs compared byte-for-byte.',
            f'{len(saved)} changed production inputs; {len(logs)} passing simulation logs.','']
manifest += [f'- {n.as_posix()} ({(root / n).stat().st_size} bytes)' for n in inputs]
(release / 'MANIFEST.md').write_text('\n'.join(manifest)+'\n', encoding='utf-8')
print(f'Packaged {release}: {len(inputs)} inputs, {len(saved)} changed inputs, {len(logs)} logs')
