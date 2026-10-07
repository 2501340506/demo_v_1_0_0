"""Check real TD paths and HDMI edge coverage, not process exit codes alone."""
import pathlib
import re
import sys

out = pathlib.Path(sys.argv[1])
summary = (out/'timing.timing').read_text()
exc = (out/'exceptions.timing').read_text()
edges = (out/'hdmi_edges.timing').read_text()
checks = (out/'check_timing.txt').read_text()
setup = float(re.search(r'SWNS:\s*([-\d.]+)', summary)[1])
hold = float(re.search(r'HWNS:\s*([-\d.]+)', summary)[1])
assert setup >= 0 and hold >= 0, (setup, hold)
assert not re.search(r'\b[1-9]\d* Viol Endpoints', summary)
for label in ('no clock', 'clock definition', 'invalid constraint', 'no path constraints', 'partial input delay', 'partial output delay'):
    assert re.search(r'checking '+re.escape(label)+r'\(0\)', checks), label

def paths(text):
    result=[]
    for b in re.split(r'(?=Slack\s+:)',text)[1:]:
        head=b.split('Delay Type')[0]
        begin=re.search(r'Begin Point\s+: (.*)',head)
        end=re.search(r'End Point\s+: (\S+)',head)
        if not begin or not end: continue
        result.append(dict(begin=begin[1],end=end[1],
            kind=re.search(r'Check Type\s+: (\w+)',head)[1],
            delay=float(re.search(r'Data Path Delay\s+: ([-\d.]+)',head)[1]),
            slack=float(re.search(r'Slack\s+: ([-\d.]+)',head)[1]),block=b))
    return result

ep=paths(exc)
for port in ['sd_mosi','sd_ncs']:
    assert {p['kind'] for p in ep if p['end']==port} >= {'setup','hold'}, port
for kind in ['setup','hold']:
    assert any(p['begin'].startswith('sd_miso ') and p['kind']==kind for p in ep),kind
assert all(p['slack']>=0 for p in ep)
assert any(p['end']=='sd_dclk' for p in ep)
# Reported input delay includes external 21 ns; require the physical input cone
# plus setup + uncertainty to fit the independent 4.2 ns bench envelope.
mi=next(p for p in ep if p['begin'].startswith('sd_miso ') and p['kind']=='setup')
setup_pin=float(re.search(r'^setup\s+([-\d.]+)',mi['block'],re.M)[1])
input_budget=mi['delay']-21+abs(setup_pin)+0.1
assert input_budget<=4.2,input_budget

hp=[p for p in paths(edges) if re.fullmatch(r'HDMI_(CLK|D[012])_P',p['end'])]
ports=['HDMI_CLK_P','HDMI_D0_P','HDMI_D1_P','HDMI_D2_P']
arrivals=[]
table=[]
for port in ports:
    for kind in ['setup','hold']:
        for edge in ['rising','falling']:
            ps=[p for p in hp if p['end']==port and p['kind']==kind and f'({edge} edge' in p['begin']]
            assert ps,(port,kind,edge)
            p=ps[0]
            arrival=float(re.search(r'^Arrival\s+([-\d.]+)',p['block'],re.M)[1])
            arrivals.append(arrival)
            table.append(f'|{port}|{kind}|{edge}|{p["delay"]:.3f}|{arrival:.3f}|')
            assert 0<=p['delay']<=3.5
# Both measurement constraints use launch@0, so arrival already excludes UI offset.
span=max(arrivals)-min(arrivals)
assert span+0.25+0.5<=2.0,span
report=['# Candidate timing checks','',f'- Setup {setup:+.3f} ns; Hold {hold:+.3f} ns.',
        f'- MISO internal path + setup + 0.100 ns uncertainty: {input_budget:.3f} ns <= 4.200 ns.',
        f'- HDMI full corner/edge arrival spread: {span:.3f} ns; +0.250 ns board mismatch +0.500 ns reserve <= 2 ns engineering aperture.',
        '- HDMI measurement limits are diagnostic only; production path limit is 3.500 ns.', '',
        '|Port|Check/corner|Launch edge|Clock-to-pad ns|Arrival from reference ns|','|---|---|---|---:|---:|']+table
(out/'CHECK_RESULTS.md').write_text('\n'.join(report)+'\n')
print('\n'.join(report[:6]))
