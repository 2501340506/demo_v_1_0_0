"""Freeze the validated S3 build and only changed production inputs."""
from pathlib import Path
import argparse, re, shutil, subprocess

p = argparse.ArgumentParser()
p.add_argument('build')
p.add_argument('--candidate', default='s3-local.1')
a = p.parse_args()
root = Path(__file__).resolve().parents[2]
output = root / 'diagnostics/output'
build = output / a.build
phy = build / 'TD_project/demo_Runs/phy_1'
release = root / 'releases/v0.14.0' / a.candidate
timing = (phy / 'final_timing.rpt').read_text(errors='replace')
for field in ('SWNS', 'HWNS'):
    result = re.search(field + r':\s*([-\d.]+)ns', timing)
    assert result and float(result[1]) >= 0, f'Timing failed: {field}'
inputs = [Path('TD_project/demo.al')]
inputs += [(root / 'TD_project' / n).resolve().relative_to(root)
           for n in re.findall(r'<File Path="([^"]+)"', (root / inputs[0]).read_text(encoding='utf-8'))]
for name in inputs:
    assert (root / name).read_bytes() == (build / name).read_bytes(), f'Build input changed: {name}'
logs = {
    'scale_s3_loader2/sim.log': 'PASS dual loader:',
    'scale_s3_control4/sim.log': 'PASS preview control:',
    'scale_s3_keys1/sim.log': 'PASS preview keys:',
    'scale_s3_player1/sim.log': 'PASS preview player:',
    'scale_s3_osd1/osd.log': 'PASS preview OSD:',
    'scale_s3_uart1/sim.log': 'PASS UART subtitle:',
    'scale_s3_preview3/system.log': 'PASS preview system:',
    'scale_s3_preview_audio1/system.log': 'PCM system observations:',
    'scale_s3_preview_final11/system.log': 'PASS preview failure recovery:',
    'scale_s3_stream2/sim.log': 'PASS byte stream suite',
    'scale_s3_fragment1/reader0_gap2_mode0.log': 'PASS FAT32 reader',
    'scale_s3_regression1/system.log': 'PASS cache system:',
}
unit_logs = [f for f in (output / 'scale_s3_units1').glob('tb_*.log') if '.console.' not in f.name]
assert len(unit_logs) == 21
for f in unit_logs:
    logs[f.relative_to(output).as_posix()] = 'PASS '
fat_logs=list((output / "scale_s3_fat32_7").glob("reader*.log"))
assert len(fat_logs)==42
for f in fat_logs:
    logs[f.relative_to(output).as_posix()]="PASS FAT32 reader"
for name, marker in logs.items():
    text = (output / name).read_text(errors='replace')
    assert marker in text and 'Errors: 0,' in text and not re.search(r'\*\* (Fatal|Error):', text), name
assert (build / 'timing_audit/check_timing.txt').exists()
assert not release.exists(), 'Never overwrite an existing candidate'
release.mkdir(parents=True)

def copy(src, dst):
    dst = release / dst
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)
    assert src.read_bytes() == dst.read_bytes()

copy(phy / 'demo.bit', Path('demo.bit'))
for name in ('final_timing.rpt', 'demo_phy.area'):
    copy(phy / name, Path('reports') / name)
copy(phy / f'build_{a.build}.log', Path('reports/build_phy.log'))
copy(build / f'TD_project/demo_Runs/syn_1/build_{a.build}.log', Path('reports/build_syn.log'))
for run in ('syn_1', 'phy_1'):
    copy(build / f'TD_project/demo_Runs/{run}/settings.cfg', Path('reports') / f'{run}_settings.cfg')
copy(build / 'diagnostics/run_td_build.ps1', Path('build_support/run_td_build.ps1'))
copy(root / 'diagnostics/image_scaling/run_td.ps1', Path('build_support/image_scaling/run_td.ps1'))
for name in ('check_timing.txt', 'audit.timing'):
    copy(build / 'timing_audit' / name, Path('reports') / name)
for name in logs:
    copy(output / name, Path('validation') / name)
changed = []
tracked_changes = set(subprocess.check_output(
    ['git', 'diff', 'v0.13.0', '--name-only', '--', 'user_source', 'TD_project'], cwd=root, text=True).splitlines())
baseline_paths = set(subprocess.check_output(
    ['git', 'ls-tree', '-r', '--name-only', 'v0.13.0'], cwd=root, text=True).splitlines())
for name in inputs:
    if name.as_posix() in tracked_changes or name.as_posix() not in baseline_paths:
        changed.append(name)
        copy(root / name, Path('sources') / name)
copy(root / 'diagnostics/image_scaling/S3_VALIDATION.md', Path('VALIDATION.md'))
copy(root / 'diagnostics/image_scaling/S3_BOARD_GUIDE.md', Path('BOARD_VALIDATION.md'))
manifest = ['# S3 candidate inputs', '', f'Baseline v0.13.0; build {a.build}.',
            f'Bit {(phy / "demo.bit").stat().st_size} bytes; {len(inputs)} inputs compared byte-for-byte with build.',
            f'{len(changed)} changed production inputs copied; {len(logs)} passing simulation logs.', '']
manifest += [f'- {n.as_posix()} ({(root / n).stat().st_size} bytes)' for n in inputs]
(release / 'MANIFEST.md').write_text('\n'.join(manifest) + '\n', encoding='utf-8')
print(f'Packaged {release}: {len(inputs)} inputs, {len(changed)} changed inputs, {len(logs)} logs')
