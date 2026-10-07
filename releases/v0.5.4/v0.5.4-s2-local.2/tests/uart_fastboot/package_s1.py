"""Freeze the verified S1 source, bitstream and evidence without rebuilding."""
from pathlib import Path
import argparse
import re
import shutil

def read_log(path):
    data = path.read_bytes()
    # Windows PowerShell redirects native output as UTF-16; ModelSim uses UTF-8.
    return data.decode('utf-16' if data.startswith(b'\xff\xfe') else 'utf-8-sig', errors='replace')

p = argparse.ArgumentParser()
p.add_argument('--build', default='v054_s1_final')
args = p.parse_args()
root = Path(__file__).resolve().parents[2]
build = root / 'diagnostics/output' / args.build
dest = root / 'releases/v0.5.4/v0.5.4-s1-local.1'
phy = build / 'TD_project/demo_Runs/phy_1'
syn = build / 'TD_project/demo_Runs/syn_1'
timing = read_log(phy/'demo_pr.timing')
setup = float(re.search(r'SWNS:\s*([-.\d]+)ns', timing)[1])
hold = float(re.search(r'HWNS:\s*([-.\d]+)ns', timing)[1])
assert setup >= 0 and hold >= 0, 'Negative final timing'
assert 'Generate bitstream completely' in read_log(phy/f'build_{args.build}.log')
assert not dest.exists(), 'Candidate already exists; preserve it'

def copy(src, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, target)
    assert src.read_bytes() == target.read_bytes()

sources = []
for f in sorted((build/'user_source').rglob('*')):
    if f.is_file():
        rel = f.relative_to(build)
        current = root/rel
        assert current.read_bytes() == f.read_bytes(), f'Source changed: {rel}'
        copy(f, dest/'sources'/rel)
        sources.append(f'{rel.as_posix()}\t{f.stat().st_size}')
copy(build/'TD_project/demo.al', dest/'sources/TD_project/demo.al')
copy(phy/'demo.bit', dest/'demo.bit')
for folder, prefix in ((phy,''),(syn,'syn_')):
    for f in folder.iterdir():
        if f.is_file() and (f.suffix in ('.area','.timing','.ts','.rpt','.cfg') or f.name == f'build_{args.build}.log'):
            copy(f, dest/'timing'/(prefix+f.name))
for f in (root/'diagnostics/uart_fastboot').iterdir():
    if f.is_file(): copy(f, dest/'tests'/f.name)
copy(root/'diagnostics/run_td_build.ps1', dest/'tests/run_td_build.ps1')
for name in ('run_reset_tests.ps1','tb_flash_reset.sv','tb_startup.sv'):
    copy(root/'diagnostics/flash_boot'/name, dest/'tests/flash_boot'/name)

out = root/'diagnostics/output'
for f in (out/'flash_boot_v054_s1').glob('*.log'):
    copy(f, dest/'simulation/initial'/f.name)
reg = out/'stability_flash_boot_v054_s1/regression'
for f in reg.glob('*.log'):
    copy(f, dest/'simulation/initial/regression'/f.name)
    if f.name != 'run_s9_reset_tests.log':
        text = read_log(f)
        assert 'PASS' in text and '** Error:' not in text and '** Fatal:' not in text, f
        copy(f, dest/'simulation/final/regression'/f.name)
copy(out/'v054_s1_reset_final.log', dest/'simulation/final/regression/run_s9_reset_tests.log')
copy(out/'v054_s1_startup_final.log', dest/'simulation/final/startup.log')
for f in (out/'v054_s1_uart_final').glob('*.log'):
    copy(f, dest/'simulation/final/uart'/f.name)
for name in ('baseline','recovery','headers','scan','pixels','timeout','timeout_control','pixel_handoff'):
    copy(out/f'flash_boot_v054_s1/{name}.log', dest/f'simulation/final/{name}.log')
for f in (dest/'simulation/final').rglob('*.log'):
    text=read_log(f)
    assert 'Errors: 0, Warnings: 0' in text, f
    assert not re.search(r'\*\* (Error|Fatal|Warning):',text), f
    if f.name != 'compile.log': assert 'PASS' in text, f

# Preserve first-attempt tool warnings separately from final evidence.
first = out/'v054_s1_attempt1/TD_project/demo_Runs'
for run in ('syn_1','phy_1'):
    copy(first/run/'build_v054_s1_attempt1.log', dest/f'experiments/{run}_attempt1.log')

baseline = root/'releases/v0.5.3/v0.5.3-local.1/timing'
oldlogs = '\n'.join(read_log(baseline/n) for n in ('build_v053_final.log','syn_build_v053_final.log'))
newlogs = '\n'.join(read_log(d/f'build_{args.build}.log') for d in (syn,phy))
pattern = r'([A-Z]+-\d+) (?:CRITICAL-)?WARNING:'
oldcodes = set(re.findall(pattern,oldlogs))
newcodes = set(re.findall(pattern,newlogs))
(dest/'sources.txt').write_text('\n'.join(sources)+'\n',encoding='utf-8')
(dest/'timing/WARNING_REVIEW.md').write_text(
    '# TD告警对照\n\n对照v0.5.3最终综合/布局日志，不宣称历史告警已消除。\n\n'
    + '共同代码：'+', '.join(sorted(oldcodes & newcodes))+'\n\n'
    + '新增代码：'+(', '.join(sorted(newcodes-oldcodes)) or '无')+'\n\n'
    + '首轮PRJ-5611为新增文件CompileOrder重复；最终改为53/54，首轮日志保留在experiments。\n'
    + '既有USR-6135、PHY-5079为PLL反馈/时钟本地布线告警；PHY-7002为SDRAM单元位置在ECO中调整。保持实际报告，不把上板验收等同工具告警消失。\n',encoding='utf-8')
print('Packaged',dest,'setup',setup,'hold',hold,'bytes',(dest/'demo.bit').stat().st_size)
print('New warning codes:', sorted(newcodes-oldcodes))
