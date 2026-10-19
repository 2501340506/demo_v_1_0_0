"""Read-only byte/configuration comparison of the failed and working builds."""
import difflib
import json
import re
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'diagnostics/output/page_candidate_comparison01'
OUT.mkdir(exist_ok=True)
NAMES = ('fast_start_td23', 'page_error_diag_td01')
RELEASES = ('s2-local.1', 's2-diagnostic.1')
BUILDS = [ROOT / 'diagnostics/output' / n for n in NAMES]
PACKS = [ROOT / 'releases/v0.23.0' / n for n in RELEASES]


def read(p):
    raw = p.read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig').replace('\r\n', '\n')


def normalized(text):
    for name in NAMES:
        text = text.replace(name, '__BUILD__')
    return text


def project_xml(text):
    # TD writes literal '&' in attribute values such as UsedInP&R.
    node = ET.fromstring(re.sub(r'&(?!amp;|lt;|gt;|quot;|apos;|#)', '&amp;', normalized(text)))
    node.attrib.pop('RunTime', None)
    ET.indent(node)
    return ET.tostring(node, encoding='unicode')


def byte_result(a, b):
    x, y = a.read_bytes(), b.read_bytes()
    return dict(left_bytes=len(x), right_bytes=len(y), identical=x == y,
                differing_bytes=sum(i != j for i, j in zip(x, y)) + abs(len(x)-len(y)),
                first_difference=next((i for i, (u, v) in enumerate(zip(x, y)) if u != v),
                                      min(len(x), len(y)) if len(x) != len(y) else None))


def tree(a, b):
    left = {p.relative_to(a).as_posix(): p for p in a.rglob('*') if p.is_file()}
    right = {p.relative_to(b).as_posix(): p for p in b.rglob('*') if p.is_file()}
    common = sorted(left.keys() & right.keys())
    differences = [p for p in common if left[p].read_bytes() != right[p].read_bytes()]
    return dict(left_count=len(left), right_count=len(right), common_count=len(common),
                identical_count=len(common)-len(differences), differences=differences,
                only_left=sorted(left.keys()-right.keys()), only_right=sorted(right.keys()-left.keys()))


report = dict(method='Full byte comparison, no file hashes',
              left_release=PACKS[0].relative_to(ROOT).as_posix(),
              right_release=PACKS[1].relative_to(ROOT).as_posix(),
              sources=tree(BUILDS[0]/'user_source', BUILDS[1]/'user_source'))
report['bitstreams'] = byte_result(PACKS[0]/'demo.bit', PACKS[1]/'demo.bit')
report['builds'] = []
for build, pack, commit in zip(BUILDS, PACKS, ('8a1dda5', 'ae76043')):
    entries = []
    untracked = []
    tracked = set(subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', commit, '--', 'user_source'], cwd=ROOT).decode('utf-8').splitlines())
    for p in sorted((build/'user_source').rglob('*')):
        if not p.is_file():
            continue
        rel = p.relative_to(build).as_posix()
        if rel not in tracked:
            # ls-tree quotes non-ASCII paths by default; query an exact path too.
            exists = subprocess.check_output(['git', 'ls-tree', commit, '--', rel], cwd=ROOT)
            if not exists:
                untracked.append(rel)
                continue
        original = subprocess.check_output(['git', 'show', f'{commit}:{rel}'], cwd=ROOT)
        # Git text checkout may expand LF; record exact and newline-only cases separately.
        raw = p.read_bytes()
        entries.append(dict(path=rel, bytes_match_git=raw == original,
                            newline_normalized_match=raw.replace(b'\r\n', b'\n') == original.replace(b'\r\n', b'\n')))
    phy = build/'TD_project/demo_Runs/phy_1'
    timing = read(phy/'final_timing.rpt')
    area = read(phy/'demo_phy.area')
    report['builds'].append(dict(name=build.name, git_commit=commit, source_count=len(entries),
        source_files_not_in_git=untracked,
        source_git_mismatches=[e for e in entries if not e['newline_normalized_match']],
        source_git_newline_only=[e['path'] for e in entries if not e['bytes_match_git'] and e['newline_normalized_match']],
        release_bit=byte_result(phy/'demo.bit', pack/'demo.bit'),
        release_project=byte_result(build/'TD_project/demo.al', pack/'reproduce/demo.al'),
        metrics_ns={k:float(re.search(k+r':\s*([-\d.]+)ns', timing)[1]) for k in ('SWNS','HWNS','STNS','HTNS')},
        resources={k:int(re.search(r'^#'+k+r'\s+(\d+)', area, re.M)[1]) for k in ('lut','reg','bram','bram32k','dsp')}))
    interface = {}
    for filename in ('miso_setup.timing', 'spi_outputs.timing'):
        path = OUT/build.name/filename
        if path.exists():
            paths = []
            for block in re.split(r'(?m)(?=^Slack\s+:)', read(path))[1:]:
                item = {}
                for key in ('Slack', 'Begin Point', 'End Point', 'Check Type', 'Process',
                            'Data Path Delay', 'Clock Skew', 'Logic Level'):
                    match = re.search(r'^'+key+r'\s+:\s*(.+)$', block, re.M)
                    if match:
                        item[key] = match[1].strip()
                paths.append(item)
            interface[filename] = paths
    report['builds'][-1]['interface_paths'] = interface

report['warning_reviews_identical'] = byte_result(
    BUILDS[0]/'timing_audit/warning_review.json',
    BUILDS[1]/'timing_audit/warning_review.json')

configs = ('TD_project/demo.al', 'TD_project/demo_Runs/syn_1/settings.cfg',
           'TD_project/demo_Runs/phy_1/settings.cfg', 'TD_project/demo_Runs/syn_1/demo.prj',
           'TD_project/demo_Runs/phy_1/demo.prj', 'TD_project/demo_Runs/phy_1/.bitgen_param.f')
report['configs'] = []
for rel in configs:
    a, b = (build/rel for build in BUILDS)
    x, y = normalized(read(a)), normalized(read(b))
    if a.suffix == '.prj':
        x, y = project_xml(x), project_xml(y)
    report['configs'].append(dict(path=rel, **byte_result(a,b), normalized_identical=x == y))
    # Also overwrite an earlier diagnostic diff when the final comparison is equal.
    diff = ''.join(difflib.unified_diff(x.splitlines(True), y.splitlines(True), fromfile=NAMES[0], tofile=NAMES[1]))
    (OUT/(rel.replace('/', '_')+'.diff')).write_text(diff, encoding='utf-8')

rel='user_source/hdl_source/SD/sd_card_bmp.v'
(OUT/'production.diff').write_text(''.join(difflib.unified_diff(read(BUILDS[0]/rel).splitlines(True),
    read(BUILDS[1]/rel).splitlines(True), fromfile=NAMES[0]+'/'+rel, tofile=NAMES[1]+'/'+rel)), encoding='utf-8')
(OUT/'comparison.json').write_text(json.dumps(report, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k != 'builds'}, indent=2, ensure_ascii=False))
for build in report['builds']:
    print(build['name'], 'Git content mismatches:', build['source_git_mismatches'],
          'untracked inputs:', build['source_files_not_in_git'], 'release bit:', build['release_bit'])
