"""Compare current TD warnings with the previously accepted local waveform bit."""
import collections
import json
import re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


def read(path):
    raw=path.read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig',errors='replace')

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
    # TD warns about the initialized ROM array having no procedural driver.
    # Its final mapped INIT/INITP contents were decoded and checked separately.
    reviewed_additions=["HDL-5314 WARNING: net 'rows' does not have a driver in ../../../user_source/hdl_source/scene/scene_text_overlay.v(LINE)"] if stage=='syn_1' else ["PHY-7002 CRITICAL-WARNING: Instance U3/sdram location (164, 288) is not honored. Cell's initial location is not legal at the beginning of ECO placement, and will be moved during placement. Please verify user location constraints through the adc file."]
    assert added==reviewed_additions,added
    report['comparisons'][stage]=dict(current_warning_count=len(now),baseline_warning_count=len(old),
                                      additions=added,removed=removed,
                                      warning_codes=dict(collections.Counter(s.split()[0] for s in now)))
    print(stage,'warnings',len(now),'added',len(added),'removed',len(removed))
check=read(build/'timing_audit/check_timing.txt')
assert 'checking no clock(0)' in check and 'checking invalid constraint(0)' in check
assert 'checking combinational loops(0)' in check and 'checking shadowed/ignored timing exception constraints(0)' in check
report['review_notes']=[
 'One new synthesis HDL-5314 warning for initialized font ROM array rows; all 4416 rows verified against final physical BRAM INIT/INITP. Existing PHY-7002 at (164,288) repeated three times instead of twice; no other new normalized warnings relative to bottom_wave_td02.',
 'Existing SDRAM macro placement fallback, device pre-route hold-fix limitation, and one local SDRAM clock remain; final routed setup/hold are positive.',
 'Existing dangling optimized pins, PLL/clock-buffer warning, asynchronous keys/DDC/segment/UART IO delay omissions and SD input-delay warning retained; no invalid/no-path/ignored constraints or combinational loops.',
 'SD/HDMI timing exceptions retained; SW3 port/input register each exactly one; optional UART logger absent.',
 'All 4416 font rows decoded from final physical netlist BRAM INIT/INITP and match generated font exactly. No narration ROM initialization ignored warning.',
 'Local validation does not cover physical TF/SDRAM data loading, display, or word-level audio alignment; board validation pending.'
]
(build/'timing_audit/warning_review.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
