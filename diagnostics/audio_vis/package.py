"""Freeze the verified candidate and only changed production sources."""
from pathlib import Path
import re
import shutil
import subprocess

root=Path(__file__).resolve().parents[2]
output=root/'diagnostics/output'
build=output/'ring_s2_attempt1'
release=root/'releases/v0.13.0/s2-local.1'
phy=build/'TD_project/demo_Runs/phy_1'
timing=(phy/'final_timing.rpt').read_text(errors='replace')
for marker in ('SWNS','HWNS'):
    m=re.search(marker+r':\s*([-\d.]+)ns',timing)
    assert m and float(m[1])>=0,f'Timing failed: {marker}'

inputs=[Path('TD_project/demo.al')]
for name in re.findall(r'<File Path="([^"]+)"',(root/inputs[0]).read_text(encoding='utf-8')):
    inputs.append((root/'TD_project'/name).resolve().relative_to(root))
for name in inputs:
    assert (root/name).read_bytes()==(build/name).read_bytes(),f'Build input changed: {name}'

logs=[]
def verify(relative, marker, warnings=()):
    path=output/relative
    text=path.read_text(errors='replace')
    assert marker in text and 'Errors: 0,' in text and not re.search(r'\*\* (Fatal|Error):',text),f'Unfinished/failed: {path}'
    for line in text.splitlines():
        if '** Warning:' in line:
            assert any(code in line for code in warnings),f'Unclassified warning: {line}'
    logs.append(path)

verify('ring_s1_unit3/tb_audio_ring.log','PASS levels:')
verify('ring_s1_unit3/tb_ring_pixels.log','PASS pixels:')
verify('ring_s1_music3/music.log','PASS music:')
verify('ring_s2_osd1/osd.log','PASS ring + all OSD:')
verify('ring_s2_production1/tb_pcm_production.log','9279 exact comparisons')
for name in ('tb_audio_scan','tb_audio_mux','tb_audio_stream'):
    verify(f'ring_s2_audio_units1/{name}.log','PASS ')
regression=sorted(p for p in (output/'ring_s2_regression1').glob('tb_*.log') if '.console.' not in p.name)
assert len(regression)==21,'Incomplete regression set'
for path in regression:verify(path.relative_to(output),'PASS ')
verify('ring_s2_gate5/gate.log','PASS synthesized',('vopt-2675','vopt-2685','vopt-2718','vsim-3016'))
verify('ring_s2_system1/system.log','PASS cache system:',('vopt-2685','vopt-2718','vopt-2121'))
system=(output/'ring_s2_system1/system.log').read_text(errors='replace')
for marker in ('PASS S2 origin:','PASS transition system:','Timestamp system observations:',
               'UART system observations: 4 serial command stages','PCM system observations:'):
    assert marker in system,marker

assert not release.exists(),'Use a new candidate; never overwrite a release'
release.mkdir(parents=True)
def copy(source,target):
    dest=release/target;dest.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(source,dest)
    assert source.read_bytes()==dest.read_bytes(),f'Copy mismatch: {dest}'
copy(phy/'demo.bit',Path('demo.bit'))
for name in ('final_timing.rpt','demo_phy.area'):
    copy(phy/name,Path('reports')/name)
copy(build/'timing_audit/check_timing.txt',Path('reports/check_timing.txt'))
copy(build/'timing_audit/audit.timing',Path('reports/audit.timing'))
for path in logs:copy(path,Path('validation')/path.parent.name/path.name)
for name in ('ring_0.png','ring_1.png','ring_2.png','ring_3.png'):
    copy(output/'ring_s1_unit3'/name,Path('preview')/name)
for name in ('music.gif','music.png','SOURCE.txt'):
    copy(output/'ring_s1_music3'/name,Path('preview')/name)
changed=subprocess.check_output(['git','diff','v0.12.0','--name-only','--','user_source','TD_project'],cwd=root,text=True).splitlines()
for name in changed:copy(root/name,Path('sources')/name)
revision=subprocess.check_output(['git','describe','--always','--dirty'],cwd=root,text=True).strip()
manifest=['# Candidate input manifest','',f'Baseline: v0.12.0; source revision: {revision}',
          f'Build: ring_s2_attempt1; bit: {(phy/"demo.bit").stat().st_size} bytes',
          f'{len(inputs)} project inputs compared byte-for-byte against the isolated build.',
          'Unchanged sources are referenced by v0.12.0; only changed production files are copied.','',
          '## Project inputs','']
manifest += [f'- {name.as_posix()} ({(root/name).stat().st_size} bytes)' for name in inputs]
manifest += ['','## Changed production inputs','']+[f'- {name}' for name in changed]
(release/'MANIFEST.md').write_text('\n'.join(manifest)+'\n',encoding='utf-8')
copy(root/'diagnostics/audio_vis/VALIDATION.md',Path('VALIDATION.md'))
print(f'Packaged {release}: {len(inputs)} inputs, {len(logs)} simulation logs, {len(changed)} changed production files')
