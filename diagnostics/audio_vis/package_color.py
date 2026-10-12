"""Package the color-only revision after its own routed build and pixel tests."""
from pathlib import Path
import re
import shutil
import subprocess

root=Path(__file__).resolve().parents[2]
output=root/'diagnostics/output'
build=output/'ring_color_attempt1'
release=root/'releases/v0.13.0/s2-local.2'
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
logs=['ring_color_unit1/tb_audio_ring.log','ring_color_unit1/tb_ring_pixels.log',
      'ring_color_osd1/osd.log','ring_color_music1/music.log']
for name in logs:
    text=(output/name).read_text(errors='replace')
    assert 'PASS ' in text and 'Errors: 0, Warnings: 0' in text and not re.search(r'\*\* (Fatal|Error):',text),name
changed=subprocess.check_output(['git','diff','v0.13.0-s2-local.1','--name-only','--','user_source','TD_project'],cwd=root,text=True).splitlines()
assert changed==['user_source/hdl_source/audio_vis/audio_ring_overlay.v'],changed
assert not release.exists(),'Never overwrite a candidate'
release.mkdir(parents=True)
def copy(source,target):
    dest=release/target;dest.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(source,dest)
    assert source.read_bytes()==dest.read_bytes(),dest
copy(phy/'demo.bit',Path('demo.bit'))
for name in ('final_timing.rpt','demo_phy.area'):
    copy(phy/name,Path('reports')/name)
copy(phy/'build_ring_color_attempt1.log',Path('reports/build_phy.log'))
copy(build/'TD_project/demo_Runs/syn_1/build_ring_color_attempt1.log',Path('reports/build_syn.log'))
copy(build/'timing_audit/check_timing.txt',Path('reports/check_timing.txt'))
copy(build/'timing_audit/audit.timing',Path('reports/audit.timing'))
for name in logs:copy(output/name,Path('validation')/name)
for name in ('ring_0.png','ring_1.png','ring_2.png','ring_3.png'):
    copy(output/'ring_color_unit1'/name,Path('preview')/name)
for name in ('music.gif','music.png','SOURCE.txt'):
    copy(output/'ring_color_music1'/name,Path('preview')/name)
for name in changed:copy(root/name,Path('sources')/name)
manifest=['# Color candidate inputs','',
          'Baseline: v0.13.0-s2-local.1; candidate: v0.13.0-s2-local.2.',
          f'Build: ring_color_attempt1; bit: {(phy/"demo.bit").stat().st_size} bytes.',
          f'{len(inputs)} inputs compared byte-for-byte with isolated build.',
          'Only audio_ring_overlay.v changed; remaining production sources are referenced by baseline.','']
manifest += [f'- {p.as_posix()} ({(root/p).stat().st_size} bytes)' for p in inputs]
(release/'MANIFEST.md').write_text('\n'.join(manifest)+'\n',encoding='utf-8')
print(f'Packaged color candidate: {len(inputs)} inputs, 4 current simulation logs, one changed production file')
