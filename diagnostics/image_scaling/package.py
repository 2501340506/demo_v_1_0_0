"""Freeze only a fully validated S2 candidate; never overwrite a candidate."""
from pathlib import Path
import argparse,re,shutil,subprocess
p=argparse.ArgumentParser();p.add_argument('build');p.add_argument('--candidate',default='s2-local.1');a=p.parse_args()
root=Path(__file__).resolve().parents[2];output=root/'diagnostics/output';build=output/a.build
phy=build/'TD_project/demo_Runs/phy_1';release=root/'releases/v0.14.0'/a.candidate
timing=(phy/'final_timing.rpt').read_text(errors='replace')
for m in ('SWNS','HWNS'):
    value=re.search(m+r':\s*([-\d.]+)ns',timing)
    assert value and float(value[1])>=0,f'Timing failed: {m}'
inputs=[Path('TD_project/demo.al')]
for name in re.findall(r'<File Path="([^"]+)"',(root/inputs[0]).read_text(encoding='utf-8')):
    inputs.append((root/'TD_project'/name).resolve().relative_to(root))
for name in inputs:assert (root/name).read_bytes()==(build/name).read_bytes(),f'Changed build input {name}'
logs={
 'scale_unit2/sim.log':'PASS scaler suite',
 'scale_stream2/sim.log':'PASS byte stream suite',
 'scale_geometry2/sim.log':'PASS range header',
 'scale_memory4/sim.log':'PASS thumbnail physical memory suite',
 'scale_decoder_legacy2/sim.log':'PASS decoder',
 'scale_s2_system4/system.log':'PASS cache system:',
 'scale_s2_mixed5/system.log':'PASS mixed physical system:',
 'scale_s2_paths1/paths.log':'PASS frame paths:',
 'scale_s2_hdmi_final1/tb_pcm_production.log':'PASS production PCM:',
 'scale_s2_fragment_final1/reader0_gap2_mode0.log':'PASS FAT32 reader',
}
for folder,glob,marker in [('scale_s2_regression2','tb_*.log','PASS '),('scale_s2_fat32_final1','reader*_gap2_mode0.log','PASS FAT32 reader')]:
    found=[f for f in (output/folder).glob(glob) if '.console.' not in f.name]
    assert len(found)==(21 if 'regression' in folder else 42),(folder,len(found))
    for f in found:logs[f.relative_to(output).as_posix()]=marker
for name,marker in logs.items():
    text=(output/name).read_text(errors='replace')
    assert marker in text and 'Errors: 0,' in text and not re.search(r'\*\* (Fatal|Error):',text),name
assert (build/'timing_audit/check_timing.txt').exists(),'Missing timing audit'
assert not release.exists(),'Never overwrite a candidate'
release.mkdir(parents=True)
def copy(src,dst):
    target=release/dst;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,target)
    assert src.read_bytes()==target.read_bytes(),str(dst)
copy(phy/'demo.bit',Path('demo.bit'))
for name in ['final_timing.rpt','demo_phy.area']:copy(phy/name,Path('reports')/name)
copy(phy/f'build_{a.build}.log',Path('reports/build_phy.log'))
copy(build/f'TD_project/demo_Runs/syn_1/build_{a.build}.log',Path('reports/build_syn.log'))
for name in ['check_timing.txt','audit.timing']:copy(build/'timing_audit'/name,Path('reports')/name)
for name in logs:copy(output/name,Path('validation')/name)
changed=subprocess.check_output(['git','diff','v0.13.0','--name-only','--','user_source','TD_project'],cwd=root,text=True).splitlines()
changed=[Path(n) for n in changed if Path(n) in inputs]
for name in changed:copy(root/name,Path('sources')/name)
copy(root/'diagnostics/image_scaling/S2_VALIDATION.md',Path('VALIDATION.md'))
copy(root/'diagnostics/image_scaling/BOARD_GUIDE.md',Path('BOARD_VALIDATION.md'))
copy(output/'scale_board_samples1/board_samples.zip',Path('board_samples.zip'))
for f in (output/'scale_board_samples1').glob('*_expected.png'):copy(f,Path('preview')/f.name)
manifest=['# S2 candidate inputs','',f'Baseline v0.13.0; build {a.build}; bit {(phy/"demo.bit").stat().st_size} bytes.',
          f'{len(inputs)} project inputs compared byte-for-byte with build; {len(changed)} changed production inputs copied.',
          f'{len(logs)} verified simulation logs. Remaining inputs referenced through baseline.','']
manifest += [f'- {n.as_posix()} ({(root/n).stat().st_size} bytes)' for n in inputs]
(release/'MANIFEST.md').write_text('\n'.join(manifest)+'\n',encoding='utf-8')
print(f'Packaged {release}: {len(inputs)} inputs, {len(logs)} logs, {len(changed)} changed inputs')
