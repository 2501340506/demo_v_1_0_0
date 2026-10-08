"""Package the fixed S2 candidate; never overwrite the original candidate."""
from pathlib import Path
import shutil
import re

root = Path.cwd()
build = root / 'diagnostics/output/v054_s2fix_final'
dest = root / 'releases/v0.5.4/v0.5.4-s2-local.2'
assert not (dest / 'demo.bit').exists(), 'Candidate already packaged'

def cp(src, dst):
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)
    assert src.read_bytes() == dst.read_bytes(), str(src)

def read(p):
    b = p.read_bytes()
    return b.decode('utf-16' if b.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig', errors='replace')

count = 0
for f in (build / 'user_source').rglob('*'):
    if f.is_file():
        rel = f.relative_to(build)
        assert f.read_bytes() == (root / rel).read_bytes(), str(rel)
        cp(f, dest / 'sources' / rel)
        count += 1
cp(build / 'TD_project/demo.al', dest / 'sources/TD_project/demo.al')
cp(build / 'TD_project/demo_Runs/phy_1/demo.bit', dest / 'demo.bit')
for run in ('syn_1', 'phy_1'):
    for f in (build / f'TD_project/demo_Runs/{run}').iterdir():
        if f.is_file() and (f.suffix in ('.area', '.timing', '.ts', '.cfg', '.rpt', '.log', '.logw', '.qor')):
            cp(f, dest / 'timing' / f'{run}_{f.name}')
for folder in ('uart_fastboot', 'stability', 'sd_recovery', 'single_pll', 'flash_boot'):
    for f in (root / 'diagnostics' / folder).iterdir():
        if f.is_file() and f.suffix in ('.sv', '.ps1', '.py', '.do'):
            cp(f, dest / 'tests' / folder / f.name)
for folder in ('v054_s2fix_uart_final', 'flash_boot_v054_s2fix'):
    for f in (root / 'diagnostics/output' / folder).rglob('*.log'):
        cp(f, dest / 'simulation' / folder / f.relative_to(root / 'diagnostics/output' / folder))
for name in ('v054_s2fix_rescan.log', 'v054_s2fix_recovery.log'):
    cp(root / 'diagnostics/output' / name, dest / 'simulation' / name)
old = root / 'releases/v0.5.4/v0.5.4-s2-local.1/timing'
def warnings(folder):
    result = {}
    for f in folder.glob('*build*.log'):
        for line in read(f).splitlines():
            m = re.search(r'((?:SYN|PHY)-\d+)\s+(?:CRITICAL-)?WARNING:', line)
            if m:
                result.setdefault(m[1], set()).add(line)
    return result
a, b = warnings(old), warnings(dest / 'timing')
lines = ['# TD warning comparison', '', 'Old IDs: ' + ', '.join(sorted(a)), 'New IDs: ' + ', '.join(sorted(b)), 'Added IDs: ' + (', '.join(sorted(b.keys() - a.keys())) or 'none'), '', 'Current warning messages (including existing PLL/SDRAM warnings):']
for key in sorted(b):
    lines.extend(sorted(b[key]))
(dest / 'timing/WARNINGS.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')
(dest / 'BUILD.md').write_text(f'''# Build record

TD 6.2.168116; ModelSim D:/modelsim/win64.
Build directory: diagnostics/output/v054_s2fix_final.
Command: diagnostics/uart_fastboot/run_td.ps1 -BuildName v054_s2fix_final
HighFanoutOptimization; TimingOptimization ultra; PostPlaceOptimization high; default seed.
{count} source/constraint files compared byte-for-byte against workspace and packaged snapshots.
Bit compared byte-for-byte against final build, { (dest / 'demo.bit').stat().st_size } bytes.
Setup +0.168 ns; Hold +0.019 ns; STA coverage 99.92%; 5911 LUT, 3757 registers, 4 BRAM, 4 DSP, 1 PLL.
Final timing report includes clocks and I/O checks. Existing PLL/SDRAM warnings remain; see timing/WARNINGS.md.
Reproduction requires the repository dependencies referenced by the saved scripts. The saved TD project uses the same relative source tree.
''', encoding='utf-8')
print('Packaged', count, 'source/constraint files;', 'new warning IDs:', sorted(b.keys() - a.keys()))
