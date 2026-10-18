"""Compare current TD warnings with the previously accepted local waveform bit."""
import collections
import json
import re
from pathlib import Path
from freeze_candidate import ROOT,read

build=ROOT/'diagnostics/output/narration_subtitles_td01'
baseline=ROOT/'diagnostics/output/bottom_wave_td02'
report=dict(reviewed=True,font_rom_initialization_verified=True,comparisons={})
assert json.loads((build/'timing_audit/font_rom_check.json').read_text())['passed']
for stage in ('syn_1','phy_1'):
    current=read(build/f'TD_project/demo_Runs/{stage}/build_narration_subtitles_td01.log')
    previous=read(baseline/f'TD_project/demo_Runs/{stage}/build_bottom_wave_td02.log')
    def warnings(log):
        return [re.sub(r'\.v\(\d+\)', '.v(LINE)', s) for s in log.splitlines() if re.search(r'\b(?:CRITICAL-)?WARNING:',s)]
    now=warnings(current);old=warnings(previous)
    added=list((collections.Counter(now)-collections.Counter(old)).elements())
    removed=list((collections.Counter(old)-collections.Counter(now)).elements())
    assert not added,added
    report['comparisons'][stage]=dict(current_warning_count=len(now),baseline_warning_count=len(old),
                                      additions=added,removed=removed,
                                      warning_codes=dict(collections.Counter(s.split()[0] for s in now)))
    print(stage,'warnings',len(now),'added',len(added),'removed',len(removed))
check=read(build/'timing_audit/check_timing.txt')
assert 'checking no clock(0)' in check and 'checking invalid constraint(0)' in check
assert 'checking combinational loops(0)' in check and 'checking shadowed/ignored timing exception constraints(0)' in check
report['review_notes']=[
 'No new normalized synthesis/physical warnings relative to bottom_wave_td02.',
 'Existing SDRAM macro placement fallback, device pre-route hold-fix limitation, and one local SDRAM clock remain; final routed setup/hold are positive.',
 'Existing dangling optimized pins, PLL/clock-buffer warning, asynchronous keys/DDC/segment/UART IO delay omissions and SD input-delay warning retained; no invalid/no-path/ignored constraints or combinational loops.',
 'SD/HDMI timing exceptions retained; SW3 port/input register each exactly one; optional UART logger absent.',
 'All 4416 font rows decoded from final physical netlist BRAM INIT/INITP and match generated font exactly. No narration ROM initialization ignored warning.',
 'Local validation does not cover physical TF/SDRAM data loading, display, or word-level audio alignment; board validation pending.'
]
(build/'timing_audit/warning_review.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
