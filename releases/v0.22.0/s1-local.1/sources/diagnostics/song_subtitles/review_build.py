"""Review a Song subtitle build against the preceding accepted local candidate."""
import argparse
import collections
import json
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]


def read(path):
    raw=path.read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig',errors='replace')


def review(name):
    build=ROOT/'diagnostics/output'/name
    baseline=ROOT/'diagnostics/output/narration_subtitles_td01'
    font=json.loads((build/'timing_audit/font_rom_check.json').read_text(encoding='utf-8'))
    assert font['passed'] and font['font_size']==21 and font['rows_compared']==5796
    report=dict(reviewed=True,font_rom_initialization_verified=True,baseline=baseline.name,comparisons={})
    for stage in ('syn_1','phy_1'):
        def warnings(folder):
            log=read(folder/f'TD_project/demo_Runs/{stage}/build_{folder.name}.log')
            assert not re.search(r'\bERROR:',log)
            return collections.Counter(re.sub(r'\.v\(\d+\)', '.v(LINE)',s) for s in log.splitlines() if re.search(r'\b(?:CRITICAL-)?WARNING:',s))
        now=warnings(build);old=warnings(baseline)
        new_signatures=set(now)-set(old)
        assert not new_signatures,sorted(new_signatures)
        added=list((now-old).elements());removed=list((old-now).elements())
        report['comparisons'][stage]=dict(current_warning_count=sum(now.values()),baseline_warning_count=sum(old.values()),
            new_signatures=sorted(new_signatures),additional_repetitions=added,removed=removed)
        print(stage,'warnings',sum(now.values()),'new signatures',len(new_signatures),'additional repetitions',len(added))
    check=read(build/'timing_audit/check_timing.txt')
    for item in ('no clock','invalid constraint','combinational loops','no path constraints','shadowed/ignored timing exception constraints'):
        assert f'checking {item}(0)' in check,item
    report['review_notes']=[
        'No new normalized warning signatures relative to narration_subtitles_td01. Repetition counts recorded separately.',
        'Initialized font array rows warning retained. All 5796 rows / 21 bits decoded from final physical BRAM INIT/INITP and match generated Song font exactly.',
        'Existing SDRAM placement fallback, local SDRAM clock and unsupported pre-route hold fixing remain. Final routed timing must independently pass setup/hold and zero TNS.',
        'Existing optimized dangling pins, PLL/clock-buffer and asynchronous keys/DDC/segment/UART IO delay omissions plus SD input delay warning retained; no invalid/no-path/ignored constraints or combinational loops.',
        'TF/SDRAM physical loading, screen visibility and speech synchronization remain board validation tasks.'
    ]
    (build/'timing_audit/warning_review.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--build',required=True)
    review(p.parse_args().build)
