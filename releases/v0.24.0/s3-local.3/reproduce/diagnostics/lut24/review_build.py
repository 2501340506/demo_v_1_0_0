"""v0.24: review a TD build against the v0.23 diagnostic release evidence.

Same checks as diagnostics/disaster_selector/review_fast_build.py, with the
fixed v0.23.0/s2-diagnostic.1 reports as baseline (the original song_td02 /
page_error_diag_td01 output directories are not on this machine).
"""
import argparse
import collections
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'releases/v0.23.0/s2-diagnostic.1/reports'


def read(path):
    raw = path.read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig', errors='replace')


def warnings(log):
    assert not re.search(r'\bERROR:', log)
    return collections.Counter(re.sub(r'\.v\(\d+\)', '.v(LINE)', s)
                               for s in log.splitlines() if re.search(r'\b(?:CRITICAL-)?WARNING:', s))


def review(name):
    build = ROOT / 'diagnostics/output' / name
    font = json.loads((build / 'timing_audit/font_rom_check.json').read_text(encoding='utf-8'))
    assert font['passed'] and font['font_size'] == 21 and font['rows_compared'] == 5796
    sdc = (build / 'user_source/constraints_source/timing.sdc').read_bytes()
    assert sdc == (ROOT / 'user_source/constraints_source/timing.sdc').read_bytes()
    assert sdc == (BASE / 'timing.sdc').read_bytes()
    adc = (build / 'user_source/constraints_source/pin.adc').read_bytes()
    assert adc == (ROOT / 'user_source/constraints_source/pin.adc').read_bytes()
    report = dict(reviewed=True, font_rom_initialization_verified=True, baseline='v0.23.0/s2-diagnostic.1 reports',
                  constraints_byte_identical=True, comparisons={})
    baseline_logs = {'syn_1': BASE / 'synthesis/build_page_error_diag_td01.log',
                     'phy_1': BASE / 'build_page_error_diag_td01.log'}
    for stage, old_path in baseline_logs.items():
        now = warnings(read(build / f'TD_project/demo_Runs/{stage}/build_{name}.log'))
        old = warnings(read(old_path))
        new = sorted(set(now) - set(old))
        report['comparisons'][stage] = dict(current_warning_count=sum(now.values()), baseline_warning_count=sum(old.values()),
            new_signatures=new, additional_repetitions=list((now - old).elements()), removed=list((old - now).elements()))
        print(stage, 'warnings', sum(now.values()), 'baseline', sum(old.values()), 'new signatures', len(new))
        for item in new:
            print('  NEW', item[:200])
    check = read(build / 'timing_audit/check_timing.txt')
    for item in ('no clock', 'invalid constraint', 'combinational loops', 'no path constraints',
                 'shadowed/ignored timing exception constraints'):
        assert f'checking {item}(0)' in check, item
    (build / 'timing_audit/warning_review.json').write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    return report


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--build', required=True)
    review(p.parse_args().build)
