import argparse, pathlib, subprocess
p=argparse.ArgumentParser();p.add_argument('name');p.add_argument('top');p.add_argument('sources',nargs='+');a=p.parse_args()
root=pathlib.Path(__file__).resolve().parents[2];out=root/'diagnostics/output'/a.name
out.mkdir(parents=True,exist_ok=False)
def run(exe,args,log):
    with (out/log).open('w') as f:
        r=subprocess.run([str(pathlib.Path('D:/modelsim/win64')/exe),*[x.replace('\\','/') for x in args]],cwd=root/'TD_project',stdout=f,stderr=subprocess.STDOUT)
    if r.returncode: raise SystemExit(f'FAIL {log}: {out}')
run('vlib.exe',[str(out/'work')],'library.log')
run('vlog.exe',['-sv','-work',str(out/'work'),*[str(root/s) for s in a.sources]],'compile.log')
run('vsim.exe',['-c','-quiet','-lib',str(out/'work'),a.top,'-l',str(out/'sim.log'),'-do','run -all; quit -f'],'console.log')
s=(out/'sim.log').read_text(errors='replace')
if '** Error:' in s or '** Fatal:' in s or 'PASS' not in s:raise SystemExit(f'FAIL simulation: {out}')
print(s[-2200:])
