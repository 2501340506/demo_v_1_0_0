"""Print actual timing audit/warning delta for human review before packaging."""
import importlib.util
import json
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('m5package',ROOT/'diagnostics/publicity_mode/package_m5.py')
p=importlib.util.module_from_spec(spec);spec.loader.exec_module(p)
build=ROOT/'diagnostics/output'/sys.argv[1]
prior=ROOT/'releases/v0.18.0/m4-local.1/reports'
delta={}
for run in ('syn_1','phy_1'):
 now=p.warnings(build/f'TD_project/demo_Runs/{run}/build_{sys.argv[1]}.log')
 old=p.warnings(prior/f'{run}_build.log')
 delta[run]={'new':sorted(now-old),'gone':sorted(old-now)}
review={'audit_summary':p.checks.audit_summary(build/'timing_audit/check_timing.txt'),'warning_delta':delta}
target=build/'audit_review.json'
assert not target.exists(),target
target.write_text(json.dumps(review,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(target.read_text(encoding='utf-8'))
