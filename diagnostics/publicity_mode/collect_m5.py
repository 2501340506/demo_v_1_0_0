"""Collect only the explicitly selected, complete M5 acceptance runs."""
import importlib.util
import json
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('m5package',ROOT/'diagnostics/publicity_mode/package_m5.py')
p=importlib.util.module_from_spec(spec);spec.loader.exec_module(p)
folders=['focused03','scan02','unit01','m401','m301','legacy_top01','flood01',
         'rgba01','system01','preview01','voice_top01','status01']
folders += [f'mode{i}01' for i in range(4)]
folders += [sys.argv[1]] # Successful final pixel run, e.g. pixels02.
logs={}
for folder in folders:
    paths=sorted((ROOT/'diagnostics/output'/f'publicity_m5_{folder}').glob('*.log'))
    chosen=[]
    for path in paths:
        if path.name.endswith('.console.log') or 'compile' in path.name or path.name in ('library.log','vendor.log','encrypted.log','pll.log','fixtures.log'):
            continue
        content=p.checks.read_log(path)
        markers=[line.removeprefix('# ').strip() for line in content.splitlines() if line.startswith(('# PASS ','PASS '))]
        assert markers,(path,'No completed PASS')
        p.check_log(path,markers[-1])
        logs[path.relative_to(ROOT/'diagnostics/output').as_posix()]=markers[-1]
        chosen.append(path)
    assert chosen,folder
# Additional current-set preview cases ran with the focused02 compiled library.
for case in (1,2,10):
    path=ROOT/f'diagnostics/output/publicity_m5_focused02/preview_case{case}.log'
    content=p.checks.read_log(path)
    marker=next(line.removeprefix('# ').strip() for line in content.splitlines() if line.startswith(('# PASS ','PASS ')))
    p.check_log(path,marker)
    logs[path.relative_to(ROOT/'diagnostics/output').as_posix()]=marker
assert len(logs)==183,(len(logs),'Review expected coverage before changing count')
target=ROOT/'diagnostics/publicity_mode/m5_logs.json'
assert not target.exists(),target
target.write_text(json.dumps(logs,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f'PASS {len(logs)} explicitly selected completed M5 simulation logs')
