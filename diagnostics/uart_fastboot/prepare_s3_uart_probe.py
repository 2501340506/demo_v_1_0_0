"""Isolate S3 build failure: accepted S2 sources plus the exact S3 UART banner."""
from pathlib import Path
import shutil

r=Path.cwd()
base=r/'releases/v0.5.4/v0.5.4-s2-local.2/sources'
failed=r/'releases/v0.5.4/v0.5.4-s3-local.1/changes/user_source/hdl_source/uart/uart_event_logger.v'
out=r/'diagnostics/output/v054_s3_uart_only_probe'
assert not out.exists(), 'Preserve previous experiment; select a new output name'
shutil.copytree(base/'user_source',out/'user_source')
(out/'TD_project').mkdir()
shutil.copyfile(base/'TD_project/demo.al',out/'TD_project/demo.al')
shutil.copyfile(failed,out/'user_source/hdl_source/uart/uart_event_logger.v')
(out/'diagnostics').mkdir()
shutil.copyfile(r/'diagnostics/run_td_build.ps1',out/'diagnostics/run_td_build.ps1')
changed=[]
for f in (base/'user_source').rglob('*'):
    if f.is_file() and f.read_bytes()!=(out/f.relative_to(base)).read_bytes():
        changed.append(f.relative_to(base).as_posix())
assert changed==['user_source/hdl_source/uart/uart_event_logger.v'], changed
(out/'README.md').write_text('''# S3 UART-only isolation probe (not a release or claimed fix)

Accepted S2 local.2 source/project/constraints snapshot, changing only the exact
UART banner used by failing S3 local.1. The parser and wrapper are the accepted
S2 versions. No clock, pin, timing constraint or memory settings changed.
BOOT intentionally remains v0.5.4-s3-local.1 so the experiment removes exactly
the S3 parser/interface changes while retaining the failed build's UART logic.
Use this directory's bit, not the original failing S3 release bit.
If this also corrupts the picture, parser pause semantics cannot explain that
failure; investigate implementation/physical timing. A passing result narrows
the fault to the parser/interface synthesis change or its placement impact.
Neither outcome alone establishes the underlying cause or accepts S3.
''',encoding='utf-8')
print('Prepared probe: exactly one changed production file relative to accepted S2')
