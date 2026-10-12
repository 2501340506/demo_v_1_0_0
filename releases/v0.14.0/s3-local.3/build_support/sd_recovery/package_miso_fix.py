"""Freeze MISO fix evidence against the immutable S3 local.2 source baseline."""
from pathlib import Path
import argparse, re, shutil, subprocess

p=argparse.ArgumentParser()
p.add_argument('build')
p.add_argument('gate_run')
p.add_argument('--candidate', default='s3-local.3')
a=p.parse_args()
root=Path(__file__).resolve().parents[2]
output=root/'diagnostics/output'
build=output/a.build
phy=build/'TD_project/demo_Runs/phy_1'
release=root/'releases/v0.14.0'/a.candidate
baseline='v0.14.0-s3-local.2'
timing=(phy/'final_timing.rpt').read_text()
for field in ('SWNS','HWNS'):
    m=re.search(field+r':\s*([-\d.]+)ns',timing)
    assert m and float(m[1])>=0, f'Failed {field}'
inputs=[Path('TD_project/demo.al')]
inputs += [(root/'TD_project'/name).resolve().relative_to(root)
           for name in re.findall(r'<File Path="([^"]+)"',(root/inputs[0]).read_text(encoding='utf-8'))]
for name in inputs:
    assert (root/name).read_bytes()==(build/name).read_bytes(),f'Input differs: {name}'
logs={
 'miso_eqn_protocol1/tb_sd_protocol.log':'PASS ',
 'miso_eqn_protocol1/tb_rescan_key.log':'PASS ',
 'miso_eqn_protocol1/tb_sd_initialization.log':'PASS ',
 'miso_eqn_protocol1/tb_sd_spi_pins.log':'PASS pin-level CRC7',
 'miso_eqn_protocol1/tb_sd_init_retry.log':'PASS bounded initialization recovery',
 'miso_eqn_io1/slow.log':'PASS SPI budget',
 'miso_eqn_io1/data.log':'PASS SPI budget',
 'miso_eqn_io1/fast.log':'PASS SPI budget',
 'miso_eqn_io1/pins_delayed.log':'PASS pin-level CRC7',
 'miso_eqn_sector1/test.log':'PASS sector adapter all scenarios',
 'miso_eqn_sector1/driver.log':'PASS sector real driver all scenarios',
 f'{a.gate_run}/sim.log':'PASS routed MISO identity 0/1',
 'miso_local2_zero/sim.log':'PASS routed MISO constant-zero negative control',
}
for name,marker in logs.items():
    s=(output/name).read_text(errors='replace')
    assert marker in s and 'Errors: 0,' in s and not re.search(r'\*\* (Fatal|Error):',s),name
for name in ('old25','overbudget'):
    assert 'Fatal: byte mismatch' in (output/f'miso_eqn_io1/{name}.log').read_text()
assert (build/'timing_audit/check_timing.txt').exists()
assert not release.exists(),'Do not overwrite candidates'
release.mkdir(parents=True)
def copy(src,dst):
    dst=release/dst;dst.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(src,dst)
    assert src.read_bytes()==dst.read_bytes()
copy(phy/'demo.bit',Path('demo.bit'))
for name in ('final_timing.rpt','demo_phy.area'):
    copy(phy/name,Path('reports')/name)
for name in ('check_timing.txt','audit.timing'):
    copy(build/'timing_audit'/name,Path('reports')/name)
for stage in ('syn_1','phy_1'):
    run=build/'TD_project/demo_Runs'/stage
    copy(run/'settings.cfg',Path('reports')/f'{stage}_settings.cfg')
    copy(run/f'build_{a.build}.log',Path('reports')/f'{stage}_build.log')
for name in logs:copy(output/name,Path('validation')/name)
for name in ('old25','overbudget'):
    copy(output/f'miso_eqn_io1/{name}.log',Path('negative_controls')/f'{name}.log')
for run in (a.gate_run,'miso_local2_zero'):
    copy(output/run/'tb_miso_gate.v',Path('validation')/run/'tb_miso_gate.v')
changed=subprocess.check_output(['git','diff',baseline,'--name-only','--','user_source','TD_project'],cwd=root,text=True).splitlines()
assert changed==['user_source/hdl_source/SD/sd_card_top.v'],changed
for name in changed:copy(root/name,Path('sources')/name)
for name in ('check_miso_gate.py','run_miso_gate.ps1','package_miso_fix.py','run_tests.ps1'):
    copy(root/'diagnostics/sd_recovery'/name,Path('build_support/sd_recovery')/name)
copy(root/'diagnostics/io_timing/run_sim.ps1',Path('build_support/io_timing/run_sim.ps1'))
copy(root/'diagnostics/image_scaling/S3_BOARD_GUIDE.md',Path('BOARD_VALIDATION.md'))
manifest=['# MISO candidate inputs','',f'Source baseline: {baseline}; build: {a.build}.',
 f'Bit: {(phy/"demo.bit").stat().st_size} bytes; {len(inputs)} inputs compared byte-for-byte.',
 'Only sd_card_top.v differs from the source baseline. The baseline bit failed board testing.',
 f'{len(logs)} successful logs including the old constant-zero negative control; 2 expected-failure logs.',
 'Unchanged image/audio system evidence is referenced from s3-local.2; it was not rerun here.','']
manifest += [f'- {name.as_posix()} ({(root/name).stat().st_size} bytes)' for name in inputs]
(release/'MANIFEST.md').write_text('\n'.join(manifest)+'\n',encoding='utf-8')
print(f'Packaged {release}: {len(inputs)} inputs; one changed production input')
