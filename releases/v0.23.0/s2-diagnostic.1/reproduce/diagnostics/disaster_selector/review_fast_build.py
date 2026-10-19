"""Audit fast-start constraints, warnings, and mapped narration ROM."""
import argparse
import collections
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    raw = path.read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig', errors='replace')


def review(name):
    build = ROOT / 'diagnostics/output' / name
    baseline = ROOT / 'diagnostics/output/song_td02'
    font = json.loads((build / 'timing_audit/font_rom_check.json').read_text(encoding='utf-8'))
    assert font['passed'] and font['font_size'] == 21 and font['rows_compared'] == 5796
    actual = build / 'user_source/constraints_source/timing.sdc'
    assert actual.read_bytes() == (ROOT / 'user_source/constraints_source/timing.sdc').read_bytes()
    assert actual.read_bytes() == (baseline / 'user_source/constraints_source/timing.sdc').read_bytes()
    report = dict(reviewed=True, font_rom_initialization_verified=True, baseline=baseline.name,
                  constraints_byte_identical=True, comparisons={})
    for stage in ('syn_1', 'phy_1'):
        def warnings(folder):
            log = read(folder / f'TD_project/demo_Runs/{stage}/build_{folder.name}.log')
            assert not re.search(r'\bERROR:', log)
            return collections.Counter(re.sub(r'\.v\(\d+\)', '.v(LINE)', s)
                                       for s in log.splitlines() if re.search(r'\b(?:CRITICAL-)?WARNING:', s))
        now, old = warnings(build), warnings(baseline)
        new = sorted(set(now) - set(old))
        assert not new, new
        report['comparisons'][stage] = dict(current_warning_count=sum(now.values()), baseline_warning_count=sum(old.values()),
            new_signatures=new, additional_repetitions=list((now-old).elements()), removed=list((old-now).elements()))
        print(stage, 'warnings', sum(now.values()), 'new signatures', len(new))
    check = read(build / 'timing_audit/check_timing.txt')
    for item in ('no clock', 'invalid constraint', 'combinational loops', 'no path constraints',
                 'shadowed/ignored timing exception constraints'):
        assert f'checking {item}(0)' in check, item
    report['review_notes'] = [
        'SDC bytes unchanged from song_td02; no relaxed clocks or new exceptions.',
        'Existing asynchronous IO delay omissions, SD input delay, local SDRAM clock and placement warnings retained.',
        'Font INIT/INITP decoded from final physical netlist: 17 BRAMs, 5796 rows x 21 bits match the preceding candidate.',
        'No new normalized warning signatures; repetition differences listed separately.',
        'Timing closure is assessed separately with strict positive setup/hold and zero TNS; board performance is pending.'
    ]
    (build / 'timing_audit/warning_review.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--build', required=True)
    review(p.parse_args().build)
