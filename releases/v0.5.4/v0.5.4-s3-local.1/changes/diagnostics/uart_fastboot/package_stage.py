"""Package changed code only, relative to an explicit accepted Git baseline."""
from pathlib import Path
import argparse
import re
import shutil
import subprocess

ap = argparse.ArgumentParser()
ap.add_argument('--baseline', required=True)
ap.add_argument('--version', required=True)
ap.add_argument('--build', required=True)
ap.add_argument('--simulation', action='append', default=[])
args = ap.parse_args()
root = Path.cwd()
dest = root / 'releases/v0.5.4' / args.version
build = root / 'diagnostics/output' / args.build
assert not dest.exists(), 'Use a new candidate directory; do not overwrite releases'

def git(*parts):
    return subprocess.run(['git', *parts], check=True, stdout=subprocess.PIPE).stdout

def cp(src, dst):
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)
    assert src.read_bytes() == dst.read_bytes(), str(src)

def read(path):
    raw = path.read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig', errors='replace')

git('rev-parse', '--verify', args.baseline)
names = set(git('diff', '--name-only', '-z', args.baseline, '--', 'user_source', 'diagnostics').decode().split('\0'))
names.update(git('ls-files', '--others', '--exclude-standard', '-z', '--', 'user_source', 'diagnostics/uart_fastboot').decode().split('\0'))
names = sorted(n for n in names if n and Path(n).suffix in ('.v', '.sv', '.py', '.ps1', '.do', '.adc', '.sdc'))
for name in names:
    src = root / name
    assert src.is_file(), 'File removal needs an explicit release note: ' + name
    cp(src, dest / 'changes' / name)
source_count = 0
for src in (build / 'user_source').rglob('*'):
    if src.is_file():
        assert src.read_bytes() == (root / src.relative_to(build)).read_bytes(), str(src)
        source_count += 1
cp(build / 'TD_project/demo_Runs/phy_1/demo.bit', dest / 'demo.bit')
# The generated TD project/constraints are unchanged in S3, so refer to S2.
prior_project = git('show', args.baseline + ':releases/v0.5.4/v0.5.4-s2-local.2/sources/TD_project/demo.al')
assert prior_project == (build / 'TD_project/demo.al').read_bytes(), 'Project changed; package the changed project explicitly'
for run in ('syn_1', 'phy_1'):
    for src in (build / f'TD_project/demo_Runs/{run}').iterdir():
        if src.is_file() and src.suffix in ('.log', '.logw', '.area', '.timing', '.ts', '.cfg', '.rpt', '.qor'):
            cp(src, dest / 'timing' / (run + '_' + src.name))
for name in args.simulation:
    src = root / 'diagnostics/output' / name
    if src.is_file():
        cp(src, dest / 'simulation' / src.name)
    else:
        assert src.is_dir(), name
        for log in src.rglob('*.log'):
            cp(log, dest / 'simulation' / name / log.relative_to(src))
def warning_ids(folder):
    return sorted(set(re.findall(r'((?:SYN|PHY)-\d+)\s+(?:CRITICAL-)?WARNING:', '\n'.join(read(p) for p in folder.glob('*build*.log')))))
old = warning_ids(root / 'releases/v0.5.4/v0.5.4-s2-local.2/timing')
new = warning_ids(dest / 'timing')
(dest / '.gitattributes').write_text('* -text\n', encoding='utf-8')
(dest / 'CHANGES.txt').write_text('Baseline: ' + args.baseline + '\nOverlay these changed/new code files onto that checkout:\n' + '\n'.join(names) + '\n', encoding='utf-8')
(dest / 'BUILD.md').write_text(f'''# Build and reconstruction

Baseline: `{args.baseline}`. Copy `changes/` over that repository checkout; no full source backup is included here.
The TD project is byte-identical to the S2 local.2 sources/TD_project/demo.al at the baseline tag. Constraints and unchanged code come from the baseline.
Build: `diagnostics/uart_fastboot/run_td.ps1 -BuildName {args.build}`.
TD 6.2.168116; HighFanoutOptimization; TimingOptimization ultra; PostPlaceOptimization high; default seed.
ModelSim D:/modelsim/win64. Reproduction requires the baseline repository's unchanged dependencies and runners.
{source_count} build source/constraint files checked byte-for-byte against workspace. Only changed/new code is copied into changes/ and compared byte-for-byte.
Bit is byte-identical to diagnostics/output/{args.build}/TD_project/demo_Runs/phy_1/demo.bit; { (dest / 'demo.bit').stat().st_size } bytes.
Old warning IDs: {', '.join(old)}.
Current warning IDs: {', '.join(new)}.
Added warning IDs: {', '.join(sorted(set(new)-set(old))) or 'none'}.
Full warnings, resource usage, clock and I/O reports are retained in timing/. Existing warnings are not claimed resolved.
''', encoding='utf-8')
print('Packaged', len(names), 'changed/new code files; checked', source_count, 'build inputs')
print('New warning IDs:', sorted(set(new)-set(old)))
