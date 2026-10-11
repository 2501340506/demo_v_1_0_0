"""Freeze a validated transition candidate, comparing inputs byte for byte."""
from pathlib import Path
import re, shutil, subprocess, sys
root=Path(__file__).resolve().parents[2]
build=root/'diagnostics/output'/sys.argv[1]
release=root/'releases/v0.11.0'/sys.argv[2]
if release.exists(): raise SystemExit('Use a new candidate number')
phy=build/'TD_project/demo_Runs/phy_1'
report=(phy/'final_timing.rpt').read_text(errors='replace')
for marker in ('SWNS','HWNS'):
    found=re.search(marker+r':\s*([-\d.]+)ns',report)
    if not found or float(found[1])<0: raise SystemExit('Timing not passed')
inputs=[Path('TD_project/demo.al')]
for name in re.findall(r'<File Path="([^"]+)"',(root/inputs[0]).read_text(encoding='utf-8')):
    inputs.append((root/'TD_project'/name).resolve().relative_to(root))
for name in inputs:
    if (root/name).read_bytes() != (build/name).read_bytes(): raise SystemExit(f'Input differs: {name}')
runs={'transition_s2_fade1':('unit.log','PASS transition S1:'),
      'transition_s2_player1':('unit.log','PASS transition player:'),
      'transition_s2_wipe1':('unit.log','PASS S2 wipe:'),
      'transition_s2_full1':('system.log','PASS S2 origin:')}
for run,(name,marker) in runs.items():
    text=(root/'diagnostics/output'/run/name).read_text(errors='replace')
    if marker not in text or re.search(r'\*\* (Fatal|Error):',text) or 'Errors: 0,' not in text:
        raise SystemExit(f'Failed or unfinished run: {run}')
regression=root/'diagnostics/output/transition_s2_regression1'
logs=list(regression.glob('tb_*.log'))
logs=[p for p in logs if not p.name.endswith('.console.log')]
if len(logs)!=21: raise SystemExit('Expected 21 regression logs')
for p in logs:
    text=p.read_text(errors='replace')
    if 'PASS ' not in text or 'Errors: 0, Warnings: 0' not in text: raise SystemExit(f'Regression incomplete: {p}')
changed=subprocess.check_output(['git','diff','v0.11.0-s1-board.1','--name-only','--','user_source','TD_project'],cwd=root,text=True).splitlines()
release.mkdir(parents=True)
def copy(source,target):
    target=release/target;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
    if source.read_bytes()!=target.read_bytes(): raise SystemExit(f'Copy differs: {target}')
copy(phy/'demo.bit','demo.bit')
for name in ('final_timing.rpt','demo_phy.area'): copy(phy/name,'reports/'+name)
for name in ('check_timing.txt','audit.timing'): copy(build/'timing_audit'/name,'reports/'+name)
for name in changed: copy(root/name,'changes/'+name)
for run in runs:
    for name in ('compile.log',runs[run][0]): copy(root/'diagnostics/output'/run/name,'simulation/'+run+'/'+name)
for p in logs: copy(p,'simulation/regression/'+p.name)
lines=['Baseline: v0.11.0-s1-board.1',f'Build: {build.relative_to(root)}',
       f'Compared {len(inputs)} project/source inputs byte for byte.','Changed production files:']+changed
lines+=['','Files and sizes:']+[f'{p.relative_to(release).as_posix()} {p.stat().st_size}' for p in sorted(release.rglob('*')) if p.is_file()]
(release/'SOURCE_MANIFEST.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(f'Packaged {len(inputs)} inputs; {len(changed)} changed production files; bit { (release/"demo.bit").stat().st_size} bytes')
