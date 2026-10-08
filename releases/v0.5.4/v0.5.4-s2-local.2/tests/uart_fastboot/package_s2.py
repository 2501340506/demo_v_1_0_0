from pathlib import Path
import shutil

root=Path.cwd()
build=root/'diagnostics/output/v054_s2_attempt1'
dest=root/'releases/v0.5.4/v0.5.4-s2-local.1'
assert not (dest/'demo.bit').exists()

def cp(s,t):
    t.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(s,t)
    assert s.read_bytes()==t.read_bytes()

for f in (build/'user_source').rglob('*'):
    if f.is_file(): cp(f,dest/'sources/user_source'/f.relative_to(build/'user_source'))
cp(build/'TD_project/demo.al',dest/'sources/TD_project/demo.al')
cp(build/'TD_project/demo_Runs/phy_1/demo.bit',dest/'demo.bit')
for run in ('syn_1','phy_1'):
    d=build/f'TD_project/demo_Runs/{run}'
    for f in d.iterdir():
        if f.is_file() and (f.suffix in ('.area','.timing','.ts','.cfg') or f.name.startswith('build_')):
            cp(f,dest/'timing'/f'{run}_{f.name}')
for name in ('run_sim.ps1','run_td.ps1','tb_uart_boot.sv','tb_uart_event_logger.sv'):
    cp(root/'diagnostics/uart_fastboot'/name,dest/'tests'/name)
for name in ('run_reset_tests.ps1','tb_flash_reset.sv','tb_startup.sv'):
    cp(root/'diagnostics/flash_boot'/name,dest/'tests/flash_boot'/name)
for f in (root/'diagnostics/output/v054_s2_uart_sim').glob('*.log'):
    cp(f,dest/'simulation/uart'/f.name)
for name in ('v054_s2_reset.log','v054_s2_recovery.log','v054_s2_timeout_control.log','v054_s2_regression.log'):
    cp(root/'diagnostics/output'/name,dest/'simulation'/name)
(dest/'sources.txt').write_text('\n'.join(f.as_posix()+'\t'+str(f.stat().st_size) for f in sorted((dest/'sources').rglob('*')) if f.is_file())+'\n',encoding='utf-8')
print('Packaged',dest,'bit bytes',(dest/'demo.bit').stat().st_size)
